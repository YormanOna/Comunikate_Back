<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Services\TarifaRadio;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class TarifaRadioController extends Controller
{
    public function index()
    {
        $tarifas = TarifaRadio::orderBy('nombre')->get();

        return response()->json([
            'data' => $tarifas->map(fn ($t) => $this->formatTarifa($t)),
        ]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'nombre' => 'required|string|max:100|unique:services.tarifas_radio,nombre',
            'descripcion' => 'nullable|string',
            'precio_por_hora' => 'required|numeric|min:0',
            'incluye_operador' => 'boolean',
            'es_activo' => 'boolean',
        ]);

        $tarifa = TarifaRadio::create($validated);

        return response()->json([
            'message' => 'Tarifa creada exitosamente.',
            'data' => $this->formatTarifa($tarifa),
        ], Response::HTTP_CREATED);
    }

    public function show($id)
    {
        $tarifa = TarifaRadio::findOrFail((int) $id);
        return response()->json(['data' => $this->formatTarifa($tarifa)]);
    }

    public function update(Request $request, $id)
    {
        $tarifa = TarifaRadio::findOrFail((int) $id);

        $validated = $request->validate([
            'nombre' => 'sometimes|string|max:100|unique:services.tarifas_radio,nombre,' . $id,
            'descripcion' => 'nullable|string',
            'precio_por_hora' => 'sometimes|numeric|min:0',
            'incluye_operador' => 'boolean',
            'es_activo' => 'boolean',
        ]);

        $tarifa->update($validated);

        return response()->json([
            'message' => 'Tarifa actualizada exitosamente.',
            'data' => $this->formatTarifa($tarifa->fresh()),
        ]);
    }

    public function destroy($id)
    {
        $tarifa = TarifaRadio::findOrFail((int) $id);
        $tarifa->delete();

        return response()->json([
            'message' => 'Tarifa eliminada exitosamente.',
        ]);
    }

    private function formatTarifa(TarifaRadio $t): array
    {
        return [
            'id' => (string) $t->id,
            'nombre' => $t->nombre,
            'descripcion' => $t->descripcion,
            'precio_por_hora' => (float) $t->precio_por_hora,
            'incluye_operador' => $t->incluye_operador,
            'es_activo' => $t->es_activo,
        ];
    }
}
