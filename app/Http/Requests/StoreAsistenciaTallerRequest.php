<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreAsistenciaTallerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'taller_id' => ['required', 'uuid', 'exists:academic.talleres,id'],
            'fecha_sesion' => ['required', 'date'],
            'asistentes' => ['sometimes', 'integer', 'min:0'],
            'capacidad_registrada' => ['sometimes', 'integer', 'min:1'],
            'observaciones' => ['nullable', 'string', 'max:1000'],
            'estudiantes' => ['sometimes', 'array'],
            'estudiantes.*.inscripcion_taller_id' => ['required_without:estudiantes.*.participante_externo_id', 'uuid', 'exists:academic.inscripciones_taller,id'],
            'estudiantes.*.participante_externo_id' => ['required_without:estudiantes.*.inscripcion_taller_id', 'uuid', 'exists:academic.participantes_externos,id'],
            'estudiantes.*.asistio' => ['required', 'boolean'],
            'estudiantes.*.estado' => ['nullable', 'string', 'in:presente,ausente,tardanza,justificado'],
            'estudiantes.*.observaciones' => ['nullable', 'string'],
        ];
    }

    public function messages(): array
    {
        return [
            'taller_id.required' => 'El taller es obligatorio',
            'taller_id.exists' => 'El taller no existe',
            'fecha_sesion.required' => 'La fecha de la sesión es obligatoria',
            'asistentes.min' => 'El número de asistentes no puede ser negativo',
            'capacidad_registrada.min' => 'La capacidad debe ser mínimo 1',
        ];
    }
}
