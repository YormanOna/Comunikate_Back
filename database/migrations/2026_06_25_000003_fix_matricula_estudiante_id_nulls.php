<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $afectadas = DB::statement("
            UPDATE academic.matriculas m
            SET estudiante_id = s.persona_id
            FROM academic.solicitudes_inscripcion s
            WHERE m.solicitud_inscripcion_id = s.id
              AND m.estudiante_id IS NULL
              AND s.persona_id IS NOT NULL
              AND m.deleted_at IS NULL
        ");

        echo "Reparadas {$afectadas} matriculas con estudiante_id nulo.\n";
    }

    public function down(): void
    {
        // No-op: no se puede revertir porque no sabemos cuales matriculas
        // tenian estudiante_id nulo antes de la migracion
    }
};
