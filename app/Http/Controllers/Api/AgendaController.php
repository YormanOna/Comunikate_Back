<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AgendaRequest;
use App\Services\AgendaService;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Carbon\Carbon;

class AgendaController extends Controller
{
    protected AgendaService $agendaService;

    public function __construct(AgendaService $agendaService)
    {
        $this->agendaService = $agendaService;
    }

    /**
     * GET /api/academic/agenda
     *
     * Lista paginada de eventos unificados de la agenda.
     */
    public function index(AgendaRequest $request): JsonResponse
    {
        $fechaInicio = $request->validated('fecha_inicio');
        $fechaFin = $request->validated('fecha_fin');
        $tipos = $request->validated('tipos');

        $events = $this->agendaService->getEvents($fechaInicio, $fechaFin, $tipos);

        $perPage = $request->validated('per_page', 100);
        $page = $request->input('page', 1);
        $total = $events->count();
        $paginated = $events->forPage($page, $perPage)->values();

        return response()->json([
            'data' => $paginated,
            'meta' => [
                'total' => $total,
                'per_page' => $perPage,
                'current_page' => (int) $page,
                'last_page' => (int) ceil($total / $perPage),
            ],
            'tipos_disponibles' => [
                ['tipo' => 'CLASE_CURSO', 'label' => 'Cursos', 'color' => '#6366f1'],
                ['tipo' => 'TALLER', 'label' => 'Talleres', 'color' => '#f59e0b'],
                ['tipo' => 'ALQUILER_AULA', 'label' => 'Alquiler de Aulas', 'color' => '#10b981'],
                ['tipo' => 'PODCAST', 'label' => 'Podcast', 'color' => '#ec4899'],
                ['tipo' => 'STREAMING', 'label' => 'Streaming', 'color' => '#06b6d4'],
                ['tipo' => 'ASESORIA', 'label' => 'Asesorías', 'color' => '#8b5cf6'],
            ],
        ]);
    }

    /**
     * GET /api/academic/agenda/{tipo_evento}/{referencia_id}
     *
     * Detalle completo de un evento.
     */
    public function show(string $tipoEvento, string $referenciaId): JsonResponse
    {
        $tipoEvento = strtoupper($tipoEvento);
        $event = $this->agendaService->getEventDetail($tipoEvento, $referenciaId);

        if (!$event) {
            return response()->json([
                'mensaje' => 'Evento no encontrado',
            ], 404);
        }

        return response()->json([
            'data' => $event,
        ]);
    }

    /**
     * GET /api/academic/agenda/exportar/pdf
     *
     * Exportar agenda a PDF con diseño de grid horario semanal.
     */
    public function exportarPDF(Request $request)
    {
        $request->validate([
            'fecha_inicio' => 'nullable|date|date_format:Y-m-d',
            'fecha_fin' => 'nullable|date|date_format:Y-m-d',
            'tipos' => 'nullable|array',
            'tipos.*' => 'string|in:CLASE_CURSO,TALLER,ALQUILER_AULA,PODCAST,STREAMING,ASESORIA',
        ]);

        $fechaInicio = $request->input('fecha_inicio', Carbon::now()->startOfMonth()->toDateString());
        $fechaFin = $request->input('fecha_fin', Carbon::now()->endOfMonth()->toDateString());
        $tipos = $request->input('tipos');

        $data = $this->agendaService->getEventsForPdf($fechaInicio, $fechaFin, $tipos);

        $html = view('pdf.agenda', [
            'weeks' => $data['weeks'],
            'hours' => $data['hours'],
            'min_hour' => $data['min_hour'],
            'max_hour' => $data['max_hour'],
            'fecha_inicio' => $data['fecha_inicio'],
            'fecha_fin' => $data['fecha_fin'],
            'total_eventos' => $data['total_eventos'],
            'tipos_activos' => $data['tipos_activos'],
            'leyenda' => $data['leyenda'],
            'fecha_generacion' => Carbon::now()->format('d/m/Y H:i'),
        ])->render();

        $pdf = Pdf::loadHTML($html);
        $pdf->setPaper('a4', 'landscape');
        $filename = 'agenda_' . Carbon::parse($fechaInicio)->format('Y-m-d') . '_' . Carbon::parse($fechaFin)->format('Y-m-d') . '.pdf';

        return $pdf->download($filename);
    }
}
