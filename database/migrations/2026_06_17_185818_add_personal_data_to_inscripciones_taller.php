<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::connection(config('database.default'))->table('academic.inscripciones_taller', function (Blueprint $table) {
            $table->string('ocupacion', 100)->nullable()->after('telefono');
            $table->string('direccion', 500)->nullable()->after('ocupacion');
            $table->string('estado_civil', 20)->nullable()->after('direccion');
            $table->date('fecha_nacimiento')->nullable()->after('estado_civil');
            $table->integer('edad')->nullable()->after('fecha_nacimiento');
            $table->string('cedula_url', 500)->nullable()->after('comprobante_url');
        });
    }

    public function down(): void
    {
        Schema::connection(config('database.default'))->table('academic.inscripciones_taller', function (Blueprint $table) {
            $table->dropColumn(['ocupacion', 'direccion', 'estado_civil', 'fecha_nacimiento', 'edad', 'cedula_url']);
        });
    }
};
