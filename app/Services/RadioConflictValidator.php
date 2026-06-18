<?php

namespace App\Services;

use App\Models\Services\ReservaRadio;

class RadioConflictValidator
{
    public function validarDisponibilidadEspacio(
        string $fecha,
        string $horaInicio,
        string $horaFin,
        ?string $excludeReservaId = null
    ): array {
        $query = ReservaRadio::where('fecha_reserva', $fecha)
            ->where('estado', '!=', 'cancelado')
            ->where(function ($q) use ($horaInicio, $horaFin) {
                $q->where('hora_inicio', '<', $horaFin)
                  ->where('hora_fin', '>', $horaInicio);
            });

        if ($excludeReservaId) {
            $query->where('id', '!=', $excludeReservaId);
        }

        $conflicto = $query->first();

        if ($conflicto) {
            return [
                'valido' => false,
                'conflicto' => [
                    'id' => $conflicto->id,
                    'fecha' => $conflicto->fecha_reserva->format('Y-m-d'),
                    'hora_inicio' => $conflicto->hora_inicio,
                    'hora_fin' => $conflicto->hora_fin,
                    'estado' => $conflicto->estado,
                ],
            ];
        }

        return ['valido' => true];
    }

    public function validarDisponibilidadOperador(
        string $operadorId,
        string $fecha,
        string $horaInicio,
        string $horaFin,
        ?string $excludeReservaId = null
    ): array {
        $query = ReservaRadio::where('operador_id', $operadorId)
            ->where('fecha_reserva', $fecha)
            ->where('estado', '!=', 'cancelado')
            ->where(function ($q) use ($horaInicio, $horaFin) {
                $q->where('hora_inicio', '<', $horaFin)
                  ->where('hora_fin', '>', $horaInicio);
            });

        if ($excludeReservaId) {
            $query->where('id', '!=', $excludeReservaId);
        }

        $conflicto = $query->first();

        if ($conflicto) {
            return [
                'valido' => false,
                'conflicto' => [
                    'id' => $conflicto->id,
                    'fecha' => $conflicto->fecha_reserva->format('Y-m-d'),
                    'hora_inicio' => $conflicto->hora_inicio,
                    'hora_fin' => $conflicto->hora_fin,
                ],
            ];
        }

        return ['valido' => true];
    }

    public function calcularPrecioTotal(int $tarifaId, string $horaInicio, string $horaFin): float
    {
        $tarifa = \App\Models\Services\TarifaRadio::findOrFail($tarifaId);

        $inicio = explode(':', $horaInicio);
        $fin = explode(':', $horaFin);

        $minutos = ((int) $fin[0] * 60 + (int) ($fin[1] ?? 0))
                 - ((int) $inicio[0] * 60 + (int) ($inicio[1] ?? 0));

        $horas = max(0, $minutos / 60);

        return round($horas * (float) $tarifa->precio_por_hora, 2);
    }
}
