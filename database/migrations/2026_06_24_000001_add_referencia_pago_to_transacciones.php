<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('finance.transacciones_ingreso', function (Blueprint $table) {
            $table->string('referencia_pago', 100)->nullable()->after('linea_pago_modulo_id');
            $table->index('referencia_pago');
        });
    }

    public function down(): void
    {
        Schema::table('finance.transacciones_ingreso', function (Blueprint $table) {
            $table->dropIndex(['referencia_pago']);
            $table->dropColumn('referencia_pago');
        });
    }
};
