<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::connection('pgsql')
            ->table('services.reservas_podcast', function ($table) {
                $table->string('titulo', 255)->nullable();
            });
    }

    public function down(): void
    {
        Schema::connection('pgsql')
            ->table('services.reservas_podcast', function ($table) {
                $table->dropColumn('titulo');
            });
    }
};
