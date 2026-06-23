<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CursoAbierto;
use App\Models\Matricula;
use App\Models\TransaccionIngreso;
use App\Models\Services\ReservaPodcast;
use App\Models\Services\TrabajoEdicion;
use App\Models\Services\AlquilerEquipo;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class SecretariaDashboardController extends Controller
{
    public function index(): JsonResponse
    {
        $pagosPendientesHoy = TransaccionIngreso::whereDate('created_at', today())
            ->where('estado_verificacion', 'pendiente')
            ->count();

        $matriculasRecientes = Matricula::with([
            'estudiante:id,nombres,apellidos,cedula',
            'cursoAbierto:id,nombre_instancia,catalogo_curso_id',
            'cursoAbierto.catalogo:id,nombre',
        ])
            ->where('created_at', '>=', now()->subDays(7))
            ->orderBy('created_at', 'desc')
            ->take(10)
            ->get()
            ->map(fn($m) => [
                'id' => $m->id,
                'estudiante_nombre' => $m->estudiante?->nombres . ' ' . $m->estudiante?->apellidos,
                'curso' => $m->cursoAbierto?->catalogo?->nombre ?? $m->cursoAbierto?->nombre,
                'fecha' => $m->created_at->format('Y-m-d'),
                'estado' => $m->estado,
            ]);

        $cursosConCupo = CursoAbierto::with([
            'catalogo:id,nombre',
            'horarios:id,curso_abierto_id,dia_semana,hora_inicio,hora_fin',
        ])
            ->withCount('matriculas as inscritos')
            ->where('es_activo', true)
            ->havingRaw('inscritos < capacidad_maxima')
            ->orderBy('fecha_inicio', 'asc')
            ->take(10)
            ->get()
            ->map(fn($c) => [
                'id' => $c->id,
                'nombre' => $c->catalogo?->nombre ?? $c->nombre_instancia,
                'inscritos' => (int) $c->inscritos,
                'capacidad' => (int) $c->capacidad_maxima,
                'disponibles' => $c->capacidad_maxima - (int) $c->inscritos,
                'fecha_inicio' => $c->fecha_inicio?->format('Y-m-d'),
            ]);

        $servicios = [
            'podcast_activas' => ReservaPodcast::whereIn('estado', ['pendiente', 'confirmada'])->count(),
            'edicion_pendientes' => TrabajoEdicion::whereIn('estado', ['pendiente', 'en_progreso'])->count(),
            'alquileres_activos' => AlquilerEquipo::whereNull('fecha_devolucion')->count(),
        ];

        return response()->json([
            'datos' => [
                'pagos_pendientes_hoy' => $pagosPendientesHoy,
                'matriculas_recientes' => $matriculasRecientes,
                'cursos_con_cupo' => $cursosConCupo,
                'estado_servicios' => $servicios,
            ],
        ]);
    }
}
