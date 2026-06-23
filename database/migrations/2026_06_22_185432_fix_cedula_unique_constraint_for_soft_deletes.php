<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE people.personas DROP CONSTRAINT IF EXISTS personas_cedula_key');

        DB::statement('CREATE UNIQUE INDEX IF NOT EXISTS personas_cedula_unique
            ON people.personas (cedula) WHERE (deleted_at IS NULL)');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS people.personas_cedula_unique');

        DB::statement('ALTER TABLE people.personas ADD CONSTRAINT personas_cedula_key UNIQUE (cedula)');
    }
};
