<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE core.ciudades DROP CONSTRAINT IF EXISTS ciudades_nombre_key');

        DB::statement('CREATE UNIQUE INDEX IF NOT EXISTS ciudades_nombre_unique
            ON core.ciudades (nombre) WHERE (deleted_at IS NULL)');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS core.ciudades_nombre_unique');

        DB::statement('ALTER TABLE core.ciudades ADD CONSTRAINT ciudades_nombre_key UNIQUE (nombre)');
    }
};
