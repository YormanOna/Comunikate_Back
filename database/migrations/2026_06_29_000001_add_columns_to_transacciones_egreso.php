<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::connection('pgsql')->table('finance.transacciones_egreso', function ($table) {
            if (!Schema::connection('pgsql')->hasColumn('finance.transacciones_egreso', 'subcategoria')) {
                $table->string('subcategoria', 100)->nullable();
            }
            if (!Schema::connection('pgsql')->hasColumn('finance.transacciones_egreso', 'proveedor_beneficiario')) {
                $table->string('proveedor_beneficiario', 200)->nullable();
            }
            if (!Schema::connection('pgsql')->hasColumn('finance.transacciones_egreso', 'metodo_pago')) {
                $table->string('metodo_pago', 50)->default('transferencia');
            }
            if (!Schema::connection('pgsql')->hasColumn('finance.transacciones_egreso', 'notas')) {
                $table->text('notas')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::connection('pgsql')->table('finance.transacciones_egreso', function ($table) {
            $table->dropColumn(['subcategoria', 'proveedor_beneficiario', 'metodo_pago', 'notas']);
        });
    }
};
