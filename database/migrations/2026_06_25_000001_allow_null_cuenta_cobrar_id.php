<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::connection('pgsql')->statement(
            'ALTER TABLE finance.transacciones_ingreso ALTER COLUMN cuenta_cobrar_id DROP NOT NULL'
        );
    }

    public function down(): void
    {
        DB::connection('pgsql')->statement(
            'ALTER TABLE finance.transacciones_ingreso ALTER COLUMN cuenta_cobrar_id SET NOT NULL'
        );
    }
};
