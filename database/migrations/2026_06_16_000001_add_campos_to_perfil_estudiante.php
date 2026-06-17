<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::connection('pgsql')->table('people.perfil_estudiante', function (Blueprint $table) {
            $table->string('ocupacion', 100)->nullable();
            $table->text('direccion')->nullable();
            $table->string('estado_civil', 20)->nullable();
            $table->integer('edad')->nullable();
        });
    }

    public function down(): void
    {
        Schema::connection('pgsql')->table('people.perfil_estudiante', function (Blueprint $table) {
            $table->dropColumn('ocupacion');
            $table->dropColumn('direccion');
            $table->dropColumn('estado_civil');
            $table->dropColumn('edad');
        });
    }
};
