<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SolicitudInscripcion;
use Carbon\Carbon;

class NotificationController extends Controller
{
    public function index()
    {
        $query = SolicitudInscripcion::where('estado', 'pendiente_validacion')
            ->where('created_at', '>=', Carbon::now()->subDays(14))
            ->with([
                'estudiante:id,nombres,apellidos',
                'participanteExterno:id,nombres,apellidos',
                'cursoAbierto:id,catalogo_curso_id,precio_base',
                'cursoAbierto.catalogo:id,nombre,color',
            ])
            ->orderByDesc('created_at')
            ->limit(20);

        $solicitudes = $query->get();

        $count = SolicitudInscripcion::where('estado', 'pendiente_validacion')->count();

        $grouped = $solicitudes->groupBy(function ($solicitud) {
            return Carbon::parse($solicitud->created_at)->format('Y-m-d');
        })->map(function ($items, $date) {
            return [
                'fecha' => $date,
                'items' => $items->map(function ($s) {
                    $nombre = $s->estudiante
                        ? trim($s->estudiante->nombres . ' ' . $s->estudiante->apellidos)
                        : ($s->participanteExterno
                            ? trim($s->participanteExterno->nombres . ' ' . ($s->participanteExterno->apellidos ?? ''))
                            : 'Desconocido');

                    return [
                        'id' => $s->id,
                        'estudiante' => $nombre,
                        'curso' => $s->cursoAbierto?->catalogo?->nombre ?? 'Sin curso',
                        'color' => $s->cursoAbierto?->catalogo?->color,
                        'monto' => (float) $s->monto_solicitado,
                        'hora' => Carbon::parse($s->created_at)->format('H:i'),
                    ];
                })->values(),
            ];
        })->values();

        return response()->json([
            'pendientes' => $count,
            'recientes' => $grouped,
        ]);
    }
}
