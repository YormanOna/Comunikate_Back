<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::connection('pgsql')->table('academic.certificados', function ($table) {
            if (!Schema::connection('pgsql')->hasColumn('academic.certificados', 'fecha_emitido')) {
                $table->timestamp('fecha_emitido')->nullable();
            }
            if (!Schema::connection('pgsql')->hasColumn('academic.certificados', 'fecha_borrado')) {
                $table->timestamp('fecha_borrado')->nullable();
            }
            if (!Schema::connection('pgsql')->hasColumn('academic.certificados', 'emitido_por')) {
                $table->uuid('emitido_por')->nullable();
            }
            if (!Schema::connection('pgsql')->hasColumn('academic.certificados', 'borrado_por')) {
                $table->uuid('borrado_por')->nullable();
            }
            if (!Schema::connection('pgsql')->hasColumn('academic.certificados', 'metodo_entrega')) {
                $table->string('metodo_entrega', 50)->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::connection('pgsql')->table('academic.certificados', function ($table) {
            $table->dropColumn(['fecha_emitido', 'fecha_borrado', 'emitido_por', 'borrado_por', 'metodo_entrega']);
        });
    }
};
