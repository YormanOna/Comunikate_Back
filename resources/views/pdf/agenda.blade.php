<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Agenda General - ComuniKate Academy</title>
    <style>
        @page {
            size: A4 landscape;
            margin: 0.8cm 0.6cm 1cm 0.6cm;
            @bottom-center {
                content: "ComuniKate Academy | Agenda General";
                font-size: 5.5pt;
                color: #9ca3af;
                font-family: 'Helvetica', 'Arial', sans-serif;
            }
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Helvetica', 'Arial', sans-serif;
            font-size: 7pt;
            color: #1f2937;
            line-height: 1.2;
        }
        .cover-header {
            text-align: center;
            padding: 8px 0 6px;
            margin-bottom: 6px;
            border-bottom: 2px solid #6366f1;
        }
        .cover-header h1 {
            font-size: 13pt;
            color: #1e1b4b;
            font-weight: 800;
            margin-bottom: 1px;
        }
        .cover-header .subtitle {
            font-size: 7pt;
            color: #6366f1;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .cover-header .meta-bar {
            display: inline-block;
            background: #f3f4f6;
            border-radius: 12px;
            padding: 2px 12px;
            margin-top: 4px;
            font-size: 6pt;
            color: #6b7280;
        }
        .week-banner {
            background: #6366f1;
            color: #fff;
            padding: 4px 10px;
            margin: 8px 0 4px;
            font-size: 7pt;
            font-weight: 700;
            text-align: center;
        }
        .calendar-grid {
            width: 100%;
            border-collapse: collapse;
            border: 1px solid #d1d5db;
            margin-bottom: 4px;
        }
        .calendar-grid thead th {
            background: #f8fafc;
            border-bottom: 1.5px solid #cbd5e1;
            font-size: 5.5pt;
            font-weight: 700;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: 0.3px;
            padding: 4px 2px;
            text-align: center;
        }
        .calendar-grid thead th.today-col {
            background: #fef3c7;
            color: #92400e;
            border-bottom-color: #f59e0b;
        }
        .calendar-grid thead th .day-num {
            display: block;
            font-size: 8pt;
            color: #374151;
            margin-top: 1px;
        }
        .calendar-grid thead th.today-col .day-num { color: #b45309; }
        .calendar-grid .time-col {
            width: 40px;
            text-align: right;
            font-size: 5.5pt;
            font-family: 'Courier New', monospace;
            font-weight: 600;
            color: #94a3b8;
            padding: 2px 4px 2px 3px;
            background: #fafafa;
            vertical-align: top;
        }
        .calendar-grid tbody td {
            border: 0.5px solid #e5e7eb;
            vertical-align: top;
            padding: 1px;
        }
        .calendar-grid tbody tr { page-break-inside: avoid; }
        .calendar-grid tbody tr:nth-child(even) td { background: #fcfcfd; }
        .event-block {
            margin: 0;
            padding: 1px 3px;
            color: #fff;
            font-weight: 600;
            font-size: 5.5pt;
            line-height: 1.2;
            overflow: hidden;
        }
        .event-block .ev-title { font-size: 5.5pt; font-weight: 700; }
        .event-block .ev-time { font-size: 5pt; opacity: 0.9; }
        .event-block .ev-instructor { font-size: 4.5pt; opacity: 0.8; }
        .legend-card {
            margin-top: 6px;
            padding: 5px 10px;
            background: #f8fafc;
            border: 1px solid #e5e7eb;
            font-size: 6pt;
        }
        .legend-card h4 {
            font-size: 5.5pt;
            color: #6b7280;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 3px;
            display: inline;
            margin-right: 6px;
        }
        .legend-item {
            display: inline-block;
            margin-right: 10px;
            font-size: 5.5pt;
            font-weight: 600;
            color: #374151;
        }
        .legend-dot {
            display: inline-block;
            width: 7px;
            height: 7px;
            border-radius: 2px;
            margin-right: 3px;
            vertical-align: middle;
        }
        .no-events {
            text-align: center;
            padding: 30px;
            color: #9ca3af;
            font-size: 10pt;
            font-style: italic;
        }
    </style>
</head>
<body>

    <div class="cover-header">
        <h1>Agenda General</h1>
        <div class="subtitle">ComuniKate Academy</div>
        <div class="meta-bar">
            {{ $fecha_inicio }} &mdash; {{ $fecha_fin }} &nbsp;|&nbsp; {{ $total_eventos }} eventos &nbsp;|&nbsp; {{ $fecha_generacion }}
        </div>
    </div>

    @if (empty($weeks) || $total_eventos == 0)
        <div class="no-events">No se encontraron eventos en el periodo seleccionado.</div>
    @else
        @foreach ($weeks as $week)
            @if (!$week['has_events'])
                @continue
            @endif

            @php
                $days = $week['days'];
                $activeHours = [];
                foreach ($days as $d) {
                    foreach ($d['events'] as $ev) {
                        $eh = (int) explode(':', $ev['hora_inicio'])[0];
                        if (!in_array($eh, $activeHours)) $activeHours[] = $eh;
                    }
                }
                sort($activeHours);
                if (empty($activeHours)) $activeHours = [$min_hour];
            @endphp

            <div class="week-banner">
                Semana del {{ $week['start']->format('d/m/Y') }} al {{ $week['end']->format('d/m/Y') }}
            </div>

            <table class="calendar-grid">
                <thead>
                    <tr>
                        <th class="time-col">Hora</th>
                        @foreach ($days as $d)
                            <th class="{{ $d['is_today'] ? 'today-col' : '' }}">
                                {{ explode(' ', $d['label'])[0] }}
                                <span class="day-num">{{ $d['date']->format('d') }}</span>
                            </th>
                        @endforeach
                    </tr>
                </thead>
                <tbody>
                    @foreach ($activeHours as $h)
                        <tr>
                            <td class="time-col">{{ sprintf('%02d:00', $h) }}</td>
                            @foreach ($days as $d)
                                @php
                                    $evts = [];
                                    foreach ($d['events'] as $ev) {
                                        if ((int) explode(':', $ev['hora_inicio'])[0] === $h) {
                                            $evts[] = $ev;
                                        }
                                    }
                                @endphp
                                <td>
                                    @foreach ($evts as $ev)
                                        <div class="event-block" style="background-color: {{ $ev['color'] }};">
                                            <div class="ev-title">{{ $ev['titulo'] }}</div>
                                            <div class="ev-time">{{ substr($ev['hora_inicio'], 0, 5) }} - {{ substr($ev['hora_fin'], 0, 5) }}</div>
                                            @if (!empty($ev['instructor_nombre']))
                                                <div class="ev-instructor">{{ $ev['instructor_nombre'] }}</div>
                                            @endif
                                            @if (!empty($ev['aula_nombre']))
                                                <div class="ev-instructor">{{ $ev['aula_nombre'] }}</div>
                                            @endif
                                        </div>
                                    @endforeach
                                </td>
                            @endforeach
                        </tr>
                    @endforeach
                </tbody>
            </table>
        @endforeach
    @endif

    <div class="legend-card">
        <h4>Leyenda:</h4>
        @foreach ($leyenda as $tipo => $info)
            @if (in_array($tipo, $tipos_activos))
                <span class="legend-item">
                    <span class="legend-dot" style="background-color: {{ $info['color'] }};"></span>
                    {{ $info['label'] }}
                </span>
            @endif
        @endforeach
    </div>

</body>
</html>
