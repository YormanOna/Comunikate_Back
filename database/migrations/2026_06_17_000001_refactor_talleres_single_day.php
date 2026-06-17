<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $conn = config('database.default');

        // Agregar columnas de participante y pago a inscripciones_taller (singular)
        Schema::connection($conn)->table('academic.inscripciones_taller', function (Blueprint $table) {
            $table->string('nombres', 100)->nullable()->after('taller_id');
            $table->string('apellidos', 100)->nullable()->after('nombres');
            $table->string('cedula', 20)->nullable()->after('apellidos');
            $table->string('correo', 150)->nullable()->after('cedula');
            $table->string('telefono', 20)->nullable()->after('correo');
            $table->string('tipo_pago', 20)->nullable()->after('estado');
            $table->decimal('monto_pagado', 10, 2)->nullable()->after('tipo_pago');
            $table->string('metodo_pago', 50)->nullable()->after('monto_pagado');
            $table->string('comprobante_url', 500)->nullable()->after('metodo_pago');
            $table->boolean('pago_verificado')->default(false)->after('comprobante_url');
            $table->date('fecha_pago')->nullable()->after('pago_verificado');
            $table->uuid('persona_id')->nullable()->change();
            $table->dropUnique('uq_persona_taller');
            $table->decimal('precio_pagado', 10, 2)->nullable()->change();
        });
    }

    public function down(): void
    {
        $conn = config('database.default');

        Schema::connection($conn)->table('academic.inscripciones_taller', function (Blueprint $table) {
            $table->dropColumn([
                'nombres', 'apellidos', 'cedula', 'correo', 'telefono',
                'tipo_pago', 'monto_pagado', 'metodo_pago', 'comprobante_url',
                'pago_verificado', 'fecha_pago',
            ]);
        });
    }
};
