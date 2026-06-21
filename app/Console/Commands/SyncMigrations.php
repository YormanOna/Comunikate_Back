<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;

class SyncMigrations extends Command
{
    protected $signature = 'db:sync-migrations
                            {--dry-run : Solo mostrar qué migraciones se marcarían, sin ejecutar}';

    protected $description = 'Sincroniza la tabla migrations con los archivos existentes, marcando como ejecutadas las migraciones cuyas tablas/columnas ya existen en la BD. Evita el error "Duplicate table" al correr migrate sobre una BD preexistente.';

    public function handle(): int
    {
        $files = File::files(database_path('migrations'));
        $ran = DB::table('migrations')->pluck('migration')->toArray();

        $toMark = [];

        foreach ($files as $file) {
            $name = $file->getFilenameWithoutExtension();

            if (in_array($name, $ran)) {
                continue;
            }

            $objects = $this->extractSchemaObjects($file->getPathname());

            if (empty($objects)) {
                $this->line("  <fg=gray>? {$name}</> — no se pudo determinar qué objetos crea, se omitirá");
                continue;
            }

            $allExist = true;
            $missing = [];

            foreach ($objects as $obj) {
                $schema = $obj['schema'] ?? null;
                if (! $this->objectExists($obj['type'], $obj['name'], $schema)) {
                    $allExist = false;
                    $label = $obj['schema'] ? "{$obj['schema']}.{$obj['name']}" : $obj['name'];
                    $missing[] = "{$obj['type']} {$label}";
                }
            }

            if ($allExist && count($objects) > 0) {
                $toMark[] = $name;
                $this->line("  <fg=green>✓ {$name}</> — todos los objetos ya existen");
            } else {
                $this->line("  <fg=yellow>✗ {$name}</> — faltan: " . implode(', ', $missing) . ' — se dejará Pending');
            }
        }

        if (empty($toMark)) {
            $this->info("\nTodas las migraciones están sincronizadas. Nada que hacer.");
            return Command::SUCCESS;
        }

        if ($this->option('dry-run')) {
            $this->info("\n[DRY RUN] Se marcarían " . count($toMark) . " migraciones como ejecutadas.");
            return Command::SUCCESS;
        }

        $maxBatch = (int) (DB::table('migrations')->max('batch') ?? 0) + 1;
        foreach ($toMark as $name) {
            DB::table('migrations')->insert([
                'migration' => $name,
                'batch' => $maxBatch,
            ]);
        }

        $this->info("\n✓ " . count($toMark) . " migraciones marcadas como ejecutadas (batch {$maxBatch}).");
        $this->info('Ahora puedes correr `php artisan migrate` sin errores.');

        return Command::SUCCESS;
    }

    /**
     * Extrae los objetos de esquema (tablas, columnas, vistas) que crea una migración.
     */
    private function extractSchemaObjects(string $path): array
    {
        $content = File::get($path);
        $objects = [];

        // Resolver variables como $tableNames = config('permission.table_names')
        $configVars = $this->resolveConfigVariables($content);

        // Schema::create('schema.table', ...) o Schema::create('table', ...)
        // También: Schema::connection(...)->create('schema.table', ...)
        if (preg_match_all(
            "/Schema::(?:connection\([^)]*\)->)?create\s*\(\s*['\"](?:([a-z_]+)\.)?([a-z_]+)['\"]/i",
            $content, $m
        )) {
            for ($i = 0; $i < count($m[0]); $i++) {
                $schema = $m[1][$i] ?: null;
                $table = $m[2][$i];
                $objects[] = ['type' => 'table', 'name' => $table, 'schema' => $schema];
            }
        }

        // Schema::create($varName['key'], ...) — nombres de tabla desde variables de configuración
        if (preg_match_all(
            "/Schema::(?:connection\([^)]*\)->)?create\s*\(\s*\\$(\w+)\s*\[\s*['\"](\w+)['\"]\s*\]/i",
            $content, $varMatches, PREG_SET_ORDER
        )) {
            foreach ($varMatches as $vm) {
                $varName = $vm[1];
                $key = $vm[2];
                if (isset($configVars[$varName]) && is_array($configVars[$varName])) {
                    $table = $configVars[$varName][$key] ?? null;
                    if ($table && is_string($table)) {
                        $objects[] = ['type' => 'table', 'name' => $table, 'schema' => null];
                    }
                }
            }
        }

        // Schema::table('schema.table', ...) o Schema::connection(...)->table(...)
        // con operaciones que crean columnas (addColumn, renameColumn, tipos de dato, etc.)
        if (preg_match_all(
            "/Schema::(?:connection\([^)]*\)->)?table\s*\(\s*['\"](?:([a-z_]+)\.)?([a-z_]+)['\"]/i",
            $content, $tableMatches, PREG_SET_ORDER
        )) {
            foreach ($tableMatches as $tm) {
                $schema = $tm[1] ?: null;
                $tableName = $tm[2];

                // Métodos que CREAN columnas (no índices, foreign keys, etc.)
                $columnMethods = 'string|integer|bigInteger|smallInteger|tinyInteger|'
                    . 'unsignedBigInteger|unsignedInteger|unsignedSmallInteger|unsignedTinyInteger|'
                    . 'decimal|float|double|boolean|date|dateTime|dateTimeTz|time|timeTz|'
                    . 'timestamp|timestampTz|timestamps|timestampsTz|softDeletes|softDeletesTz|'
                    . 'text|mediumText|longText|json|jsonb|uuid|binary|enum|set|'
                    . 'char|year|geometry|geography|macAddress|ipAddress|'
                    . 'morphs|nullableMorphs|uuidMorphs|nullableUuidMorphs|'
                    . 'rememberToken|addColumn|renameColumn';

                if (preg_match_all(
                    '/\$table->(' . $columnMethods . ')\(\s*[\'"](\w+)[\'"]/',
                    $content, $colMatches
                )) {
                    foreach ($colMatches[2] as $colIdx => $col) {
                        $method = $colMatches[1][$colIdx];
                        $columnName = $col;
                        if ($method === 'renameColumn') {
                            if (preg_match(
                                '/\$table->renameColumn\(\s*[\'"]\w+[\'"]\s*,\s*[\'"](\w+)[\'"]/i',
                                $content, $renameMatch
                            )) {
                                $columnName = $renameMatch[1];
                            }
                        }
                        $objects[] = [
                            'type' => 'column',
                            'name' => "{$tableName}.{$columnName}",
                            'schema' => $schema,
                        ];
                    }
                }
            }
        }

        // Schema::table($varName['key'], ...) — usando nombres de tabla variables
        if (preg_match_all(
            "/Schema::(?:connection\([^)]*\)->)?table\s*\(\s*\\$(\w+)\s*\[\s*['\"](\w+)['\"]\s*\]/i",
            $content, $varTableMatches, PREG_SET_ORDER
        )) {
            foreach ($varTableMatches as $vtm) {
                $varName = $vtm[1];
                $key = $vtm[2];
                if (isset($configVars[$varName]) && is_array($configVars[$varName])) {
                    $tableName = $configVars[$varName][$key] ?? null;
                    if ($tableName && is_string($tableName)) {
                        $columnMethods = 'string|integer|bigInteger|smallInteger|tinyInteger|'
                            . 'unsignedBigInteger|unsignedInteger|unsignedSmallInteger|unsignedTinyInteger|'
                            . 'decimal|float|double|boolean|date|dateTime|dateTimeTz|time|timeTz|'
                            . 'timestamp|timestampTz|timestamps|timestampsTz|softDeletes|softDeletesTz|'
                            . 'text|mediumText|longText|json|jsonb|uuid|binary|enum|set|'
                            . 'char|year|geometry|geography|macAddress|ipAddress|'
                            . 'morphs|nullableMorphs|uuidMorphs|nullableUuidMorphs|'
                            . 'rememberToken|addColumn|renameColumn';
                        if (preg_match_all(
                            '/\$table->(' . $columnMethods . ')\(\s*[\'"](\w+)[\'"]/',
                            $content, $colMatches
                        )) {
                            foreach ($colMatches[2] as $colIdx => $col) {
                                $method = $colMatches[1][$colIdx];
                                $columnName = $col;
                                if ($method === 'renameColumn') {
                                    if (preg_match(
                                        '/\$table->renameColumn\(\s*[\'"]\w+[\'"]\s*,\s*[\'"](\w+)[\'"]/i',
                                        $content, $renameMatch
                                    )) {
                                        $columnName = $renameMatch[1];
                                    }
                                }
                                $objects[] = [
                                    'type' => 'column',
                                    'name' => "{$tableName}.{$columnName}",
                                    'schema' => null,
                                ];
                            }
                        }
                    }
                }
            }
        }

        // DB::statement('CREATE VIEW ...')
        if (preg_match_all(
            "/CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+(?:([a-z_]+)\.)?([a-z_]+)/i",
            $content, $viewMatches
        )) {
            for ($i = 0; $i < count($viewMatches[0]); $i++) {
                $schema = $viewMatches[1][$i] ?: null;
                $view = $viewMatches[2][$i];
                $objects[] = ['type' => 'view', 'name' => $view, 'schema' => $schema];
            }
        }

        // DB::statement('CREATE TYPE schema.type_name ...')
        if (preg_match_all(
            "/CREATE\s+TYPE\s+(?:([a-z_]+)\.)?([a-z_]+)/i",
            $content, $typeMatches
        )) {
            for ($i = 0; $i < count($typeMatches[0]); $i++) {
                $schema = $typeMatches[1][$i] ?: null;
                $type = $typeMatches[2][$i];
                $objects[] = ['type' => 'type', 'name' => $type, 'schema' => $schema];
            }
        }

        return $objects;
    }

    /**
     * Resuelve variables de configuración definidas en la migración,
     * como $tableNames = config('permission.table_names').
     * Retorna un array [varName => value].
     */
    private function resolveConfigVariables(string $content): array
    {
        $vars = [];
        if (preg_match_all(
            "/\\$(\w+)\s*=\s*config\s*\(\s*['\"]([^'\"]+)['\"]\s*\)/",
            $content, $matches, PREG_SET_ORDER
        )) {
            foreach ($matches as $m) {
                $varName = $m[1];
                $configKey = $m[2];
                $vars[$varName] = config($configKey);
            }
        }
        return $vars;
    }

    /**
     * Verifica si un objeto existe en PostgreSQL.
     * Si $schema es null, busca en todos los esquemas del search_path.
     */
    private function objectExists(string $type, string $name, ?string $schema): bool
    {
        $nonSystemSchemas = $this->getNonSystemSchemas();

        return match ($type) {
            'table' => $this->existsInSchemas(
                fn($s) => DB::table('information_schema.tables')
                    ->where('table_schema', $s)
                    ->where('table_name', $name)
                    ->exists(),
                $schema, $nonSystemSchemas
            ),
            'column' => (function () use ($name, $schema, $nonSystemSchemas) {
                $parts = explode('.', $name, 2);
                if (count($parts) !== 2) return false;
                return $this->existsInSchemas(
                    fn($s) => DB::table('information_schema.columns')
                        ->where('table_schema', $s)
                        ->where('table_name', $parts[0])
                        ->where('column_name', $parts[1])
                        ->exists(),
                    $schema, $nonSystemSchemas
                );
            })(),
            'view' => $this->existsInSchemas(
                fn($s) => DB::table('information_schema.views')
                    ->where('table_schema', $s)
                    ->where('table_name', $name)
                    ->exists(),
                $schema, $nonSystemSchemas
            ),
            'type' => $this->existsInSchemas(
                fn($s) => DB::selectOne(
                    "SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace WHERE n.nspname = ? AND t.typname = ?",
                    [$s, $name]
                ) !== null,
                $schema, $nonSystemSchemas
            ),
            default => false,
        };
    }

    /**
     * Si $schema es específico, busca solo en ese esquema.
     * Si $schema es null, busca en todos los esquemas no-sistema.
     */
    private function existsInSchemas(callable $check, ?string $schema, array $nonSystemSchemas): bool
    {
        if ($schema !== null) {
            return $check($schema);
        }
        foreach ($nonSystemSchemas as $s) {
            if ($check($s)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Obtiene los esquemas no-sistema visibles (search_path + public).
     */
    private function getNonSystemSchemas(): array
    {
        $rows = DB::select(
            "SELECT schema_name FROM information_schema.schemata
             WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
             ORDER BY schema_name"
        );
        return array_map(fn($r) => $r->schema_name, $rows);
    }
}
