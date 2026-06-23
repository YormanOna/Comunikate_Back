<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('people.personas', function (Blueprint $table) {
            $table->string('ciudad', 100)->nullable()->after('celular');
        });

        DB::statement('
            UPDATE people.personas p
            SET ciudad = c.nombre
            FROM core.ciudades c
            WHERE p.ciudad_id = c.id
        ');
    }

    public function down(): void
    {
        Schema::table('people.personas', function (Blueprint $table) {
            $table->dropColumn('ciudad');
        });
    }
};
