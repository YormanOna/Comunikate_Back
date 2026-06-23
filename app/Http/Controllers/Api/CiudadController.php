<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ciudad;
use App\Http\Requests\StoreCiudadRequest;
use App\Http\Requests\UpdateCiudadRequest;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;

class CiudadController extends Controller
{
    /**
     * GET /api/ciudades
     * Listar todas las ciudades con paginación y búsqueda
     */
    public function index(Request $request)
    {
        $query = Ciudad::query();

        // Búsqueda por nombre
        if ($request->has('search')) {
            $query->where('nombre', 'ilike', '%' . $request->search . '%');
        }

        // Ordenar por nombre
        $query->orderBy('nombre', 'asc');

        $perPage = $request->get('per_page', 15);
        $ciudades = $query->paginate($perPage);

        return response()->json([
            'data' => $ciudades->items(),
            'meta' => [
                'total' => $ciudades->total(),
                'per_page' => $ciudades->perPage(),
                'current_page' => $ciudades->currentPage(),
                'last_page' => $ciudades->lastPage(),
            ]
        ]);
    }

    /**
     * POST /api/ciudades
     * Crear nueva ciudad
     */
    public function store(StoreCiudadRequest $request)
    {
        $ciudad = Ciudad::create($request->validated());

        return response()->json([
            'data' => $ciudad,
            'message' => 'Ciudad creada exitosamente'
        ], Response::HTTP_CREATED);
    }

    /**
     * GET /api/ciudades/{id}
     * Obtener detalles de una ciudad
     */
    public function show($id)
    {
        $ciudad = Ciudad::findOrFail($id);

        return response()->json([
            'data' => $ciudad
        ]);
    }

    /**
     * PUT /api/ciudades/{id}
     * Actualizar una ciudad
     */
    public function update(UpdateCiudadRequest $request, $id)
    {
        $ciudad = Ciudad::findOrFail($id);
        $ciudad->update($request->validated());

        return response()->json([
            'data' => $ciudad,
            'message' => 'Ciudad actualizada exitosamente'
        ]);
    }

    /**
     * DELETE /api/ciudades/{id}
     * Eliminar una ciudad
     */
    public function destroy($id)
    {
        try {
            $ciudad = Ciudad::findOrFail($id);
            $ciudad->delete();

            return response()->json([
                'message' => 'Ciudad eliminada exitosamente'
            ]);
        } catch (\Illuminate\Database\QueryException $e) {
            return response()->json([
                'message' => 'No se puede eliminar la ciudad porque está siendo utilizada por otros registros'
            ], Response::HTTP_CONFLICT);
        }
    }

    /**
     * GET /api/ciudades/todas/sin-paginacion
     * Obtener todas las ciudades sin paginación (para selects)
     */
    public function todas()
    {
        $ciudades = Ciudad::orderBy('nombre', 'asc')->get();

        return response()->json([
            'data' => $ciudades
        ]);
    }
}
