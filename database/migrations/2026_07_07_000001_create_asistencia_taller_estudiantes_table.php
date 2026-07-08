<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('academic.asistencia_taller_estudiantes')) {
            return;
        }
        Schema::connection(config('database.default'))->create('academic.asistencia_taller_estudiantes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('asistencia_taller_id');
            $table->uuid('inscripcion_taller_id')->nullable();
            $table->uuid('participante_externo_id')->nullable();
            $table->boolean('asistio')->default(true);
            $table->string('estado', 20)->nullable();
            $table->text('observaciones')->nullable();
            $table->timestamps();

            $table->foreign('asistencia_taller_id')->references('id')->on('academic.asistencias_talleres')->onDelete('cascade');
            $table->foreign('inscripcion_taller_id')->references('id')->on('academic.inscripciones_taller')->onDelete('cascade');
            $table->foreign('participante_externo_id')->references('id')->on('academic.participantes_externos')->onDelete('cascade');

            $table->index('asistencia_taller_id');
            $table->unique(['asistencia_taller_id', 'inscripcion_taller_id'], 'at_est_inscripcion_unique');
            $table->unique(['asistencia_taller_id', 'participante_externo_id'], 'at_est_externo_unique');
        });
    }

    public function down(): void
    {
        Schema::connection(config('database.default'))->dropIfExists('academic.asistencia_taller_estudiantes');
    }
};
