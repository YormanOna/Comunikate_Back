<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTallerRequest;
use App\Http\Requests\UpdateTallerRequest;
use App\Models\Taller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TallerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Taller::query()->with(['instructor', 'inscripciones']);

        if ($request->filled('estado')) {
            $query->where('estado', $request->estado);
        }

        if ($request->filled('modalidad')) {
            $query->where('modalidad', $request->modalidad);
        }

        if ($request->filled('instructor_id')) {
            $query->where('instructor_id', $request->instructor_id);
        }

        if ($request->filled('fecha_desde')) {
            $query->whereDate('fecha', '>=', $request->fecha_desde);
        }

        if ($request->filled('fecha_hasta')) {
            $query->whereDate('fecha', '<=', $request->fecha_hasta);
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('nombre', 'ilike', "%{$search}%")
                  ->orWhere('descripcion', 'ilike', "%{$search}%");
            });
        }

        if ($request->filled('tab')) {
            if ($request->tab === 'proximos') {
                $query->where('fecha', '>=', now()->toDateString())
                      ->whereIn('estado', ['pendiente', 'confirmado']);
            } elseif ($request->tab === 'pasados') {
                $query->where('fecha', '<', now()->toDateString());
            }
        }

        $talleres = $query
            ->orderBy('fecha', $request->tab === 'pasados' ? 'desc' : 'asc')
            ->paginate($request->per_page ?? 50);

        return response()->json($talleres);
    }

    public function store(StoreTallerRequest $request): JsonResponse
    {
        $taller = Taller::create($request->validated());
        return response()->json(
            $taller->load(['instructor']),
            201
        );
    }

    public function show(string $id): JsonResponse
    {
        $taller = Taller::with([
            'instructor',
            'inscripciones',
            'asistencias',
        ])->findOrFail($id);

        return response()->json($taller);
    }

    public function update(UpdateTallerRequest $request, string $id): JsonResponse
    {
        $taller = Taller::findOrFail($id);
        $taller->update($request->validated());
        return response()->json($taller->load(['instructor']));
    }

    public function destroy(string $id): JsonResponse
    {
        $taller = Taller::findOrFail($id);
        $taller->delete();
        return response()->json(['mensaje' => 'Taller eliminado correctamente']);
    }

    public function estadisticas(string $id): JsonResponse
    {
        $taller = Taller::withCount('inscripciones')->findOrFail($id);

        return response()->json([
            'id' => $taller->id,
            'nombre' => $taller->nombre,
            'total_inscritos' => $taller->inscripciones_count,
            'capacidad_disponible' => $taller->capacidadDisponible(),
            'tasa_ocupacion' => round($taller->tasaOcupacion(), 1),
            'ingreso_total' => $taller->inscripciones()->sum('monto_pagado'),
            'pagos_verificados' => $taller->inscripciones()->where('pago_verificado', true)->count(),
            'pagos_pendientes' => $taller->inscripciones()->where('pago_verificado', false)->count(),
            'estado' => $taller->estado,
            'permite_inscripcion' => $taller->permitirInscripcion(),
        ]);
    }

    public function cambiarEstadoMasivo(Request $request): JsonResponse
    {
        $request->validate([
            'ids' => 'required|array|min:1|max:1000',
            'ids.*' => 'uuid|exists:academic.talleres,id',
            'estado' => 'required|in:pendiente,confirmado,completado,cancelado',
        ]);

        $count = Taller::whereIn('id', $request->ids)->update(['estado' => $request->estado]);

        return response()->json([
            'mensaje' => "{$count} taller(es) actualizado(s)",
            'cantidad' => $count,
        ]);
    }
}
