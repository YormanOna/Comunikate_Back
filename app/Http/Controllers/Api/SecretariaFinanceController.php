<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CuentaPorCobrar;
use App\Models\TransaccionIngreso;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;

class SecretariaFinanceController extends Controller
{
    public function cuentas(Request $request): JsonResponse
    {
        $query = CuentaPorCobrar::with([
            'matricula.estudiante:id,nombres,apellidos,cedula',
            'matricula.cursoAbierto:id,nombre',
            'matricula.cursoAbierto.catalogo:id,nombre',
            'solicitudInscripcion.estudiante:id,nombres,apellidos,cedula',
            'solicitudInscripcion.participanteExterno',
            'solicitudInscripcion.cursoAbierto.catalogo:id,nombre',
            'inscripcionTaller.taller:id,nombre',
        ]);

        if ($request->filled('estado')) {
            $query->where('estado', $request->estado);
        }

        if ($request->filled('search')) {
            $term = $request->search;
            $query->where(function ($q) use ($term) {
                $q->whereHas('matricula.estudiante', fn($sq) => $sq->where('nombres', 'ilike', "%{$term}%")->orWhere('apellidos', 'ilike', "%{$term}%"))
                  ->orWhereHas('solicitudInscripcion.estudiante', fn($sq) => $sq->where('nombres', 'ilike', "%{$term}%")->orWhere('apellidos', 'ilike', "%{$term}%"))
                  ->orWhereHas('solicitudInscripcion.participanteExterno', fn($sq) => $sq->where('nombres', 'ilike', "%{$term}%")->orWhere('apellidos', 'ilike', "%{$term}%"));
            });
        }

        $cuentas = $query->orderBy('created_at', 'desc')->paginate($request->get('per_page', 15));

        return response()->json($cuentas);
    }

    public function cuentaDetalle($id): JsonResponse
    {
        $cuenta = CuentaPorCobrar::with([
            'matricula.estudiante:id,nombres,apellidos,cedula',
            'matricula.cursoAbierto:id,nombre',
            'matricula.cursoAbierto.catalogo:id,nombre',
            'solicitudInscripcion.estudiante:id,nombres,apellidos,cedula',
            'solicitudInscripcion.participanteExterno',
            'solicitudInscripcion.cursoAbierto.catalogo:id,nombre',
            'inscripcionTaller.taller:id,nombre',
        ])->findOrFail($id);

        $transacciones = TransaccionIngreso::where('cuenta_cobrar_id', $id)
            ->orderBy('fecha_pago', 'desc')
            ->get()
            ->map(fn($t) => [
                'id' => $t->id,
                'monto' => (float) $t->monto,
                'metodo_pago' => $t->metodo_pago,
                'comprobante_url' => $t->comprobante_url,
                'fecha_pago' => $t->fecha_pago?->format('Y-m-d'),
                'estado_verificacion' => $t->estado_verificacion,
                'observaciones' => $t->observaciones,
            ])
            ->values();

        return response()->json([
            'datos' => $cuenta,
            'transacciones' => $transacciones,
        ]);
    }

    public function registrarPago(Request $request): JsonResponse
    {
        $request->validate([
            'cuenta_cobrar_id' => [
                'required',
                'uuid',
                Rule::exists('finance.cuentas_por_cobrar', 'id'),
            ],
            'monto' => 'required|numeric|min:0.01',
            'metodo_pago' => 'required|string',
            'comprobante_url' => 'nullable|string',
            'fecha_pago' => 'nullable|date',
            'observaciones' => 'nullable|string',
        ]);

        DB::beginTransaction();
        try {
            $cuenta = CuentaPorCobrar::lockForUpdate()->findOrFail($request->cuenta_cobrar_id);

            $saldo = $cuenta->monto_total - $cuenta->monto_abonado;
            if ($request->monto > ($saldo + 0.01)) {
                return response()->json([
                    'mensaje' => "El monto (\${$request->monto}) supera el saldo pendiente (\${$saldo})",
                ], 422);
            }

            $transaccion = TransaccionIngreso::create([
                'cuenta_cobrar_id' => $cuenta->id,
                'monto' => $request->monto,
                'metodo_pago' => $request->metodo_pago,
                'comprobante_url' => $request->comprobante_url,
                'fecha_pago' => $request->fecha_pago ?? now(),
                'registrado_por' => auth()->user()->persona_id ?? null,
                'observaciones' => $request->observaciones,
                'estado_verificacion' => 'pendiente',
            ]);

            DB::commit();
            return response()->json([
                'mensaje' => 'Pago registrado correctamente',
                'datos' => $transaccion,
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error("Error registrando pago: " . $e->getMessage());
            return response()->json(['mensaje' => 'Error al registrar el pago'], 500);
        }
    }

    public function verificarTransaccion(Request $request, $id): JsonResponse
    {
        $request->validate([
            'estado' => 'required|in:aprobado,rechazado',
            'motivo_rechazo' => 'required_if:estado,rechazado|nullable|string',
            'observaciones' => 'nullable|string',
        ]);

        $transaccion = TransaccionIngreso::findOrFail($id);

        if ($transaccion->estado_verificacion !== 'pendiente') {
            return response()->json(['mensaje' => 'Esta transacción ya ha sido verificada'], 422);
        }

        $transaccion->update([
            'estado_verificacion' => $request->estado,
            'motivo_rechazo' => $request->motivo_rechazo,
            'observaciones' => $request->observaciones ?? $transaccion->observaciones,
            'verificado_por' => auth()->user()->persona_id ?? null,
            'fecha_verificacion' => now(),
        ]);

        return response()->json([
            'mensaje' => 'Transacción ' . ($request->estado === 'aprobado' ? 'aprobada' : 'rechazada') . ' correctamente',
            'datos' => $transaccion,
        ]);
    }
}
