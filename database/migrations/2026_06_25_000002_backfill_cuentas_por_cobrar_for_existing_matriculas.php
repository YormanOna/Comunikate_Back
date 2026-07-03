<?php

use Illuminate\Database\Migrations\Migration;
use App\Models\CuentaPorCobrar;
use App\Models\Matricula;

return new class extends Migration
{
    public function up(): void
    {
        $matriculas = Matricula::doesntHave('cuentaPorCobrar')
            ->whereHas('lineasPago')
            ->with('lineasPago')
            ->get();

        $creadas = 0;
        foreach ($matriculas as $matricula) {
            $lineas = $matricula->lineasPago;
            if ($lineas->isEmpty()) continue;

            $montoTotal = (float) $lineas->sum('monto_ajustado');
            $montoAbonado = (float) $lineas->sum('monto_abonado');

            $estado = $montoAbonado >= $montoTotal
                ? CuentaPorCobrar::ESTADO_PAGADO
                : ($montoAbonado > 0 ? CuentaPorCobrar::ESTADO_ABONADO : CuentaPorCobrar::ESTADO_PENDIENTE);

            CuentaPorCobrar::create([
                'matricula_id' => $matricula->id,
                'monto_total' => $montoTotal,
                'monto_abonado' => $montoAbonado,
                'estado' => $estado,
            ]);

            $creadas++;
        }

        echo "Backfill: creadas {$creadas} cuentas por cobrar para matriculas existentes sin cuenta.\n";
    }

    public function down(): void
    {
        // No-op: no hay forma segura de revertir solo las cuentas creadas por esta migracion
        // sin afectar cuentas creadas por nuevos flujos de aprobacion.
    }
};
