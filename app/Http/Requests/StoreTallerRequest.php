<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreTallerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => 'required|string|max:200',
            'descripcion' => 'nullable|string|max:2000',
            'fecha' => 'required|date|after_or_equal:today',
            'hora_inicio' => 'required|date_format:H:i',
            'hora_fin' => 'required|date_format:H:i|after:hora_inicio',
            'instructor_id' => 'required|uuid|exists:personas,id',
            'modalidad' => 'required|in:presencial,virtual',
            'capacidad_maxima' => 'required|integer|min:1|max:500',
            'precio' => 'required|numeric|min:0',
            'estado' => 'sometimes|in:pendiente,confirmado,completado,cancelado',
        ];
    }

    public function messages(): array
    {
        return [
            'nombre.required' => 'El nombre del taller es obligatorio',
            'fecha.required' => 'La fecha del taller es obligatoria',
            'fecha.after_or_equal' => 'La fecha debe ser hoy o posterior',
            'hora_inicio.required' => 'La hora de inicio es obligatoria',
            'hora_fin.required' => 'La hora de fin es obligatoria',
            'hora_fin.after' => 'La hora de fin debe ser posterior a la hora de inicio',
            'instructor_id.required' => 'Debe seleccionar un instructor',
            'instructor_id.exists' => 'El instructor seleccionado no existe',
            'modalidad.required' => 'Debe seleccionar una modalidad',
            'modalidad.in' => 'La modalidad debe ser presencial o virtual',
            'capacidad_maxima.required' => 'La capacidad máxima es obligatoria',
            'capacidad_maxima.integer' => 'La capacidad debe ser un número entero',
            'capacidad_maxima.min' => 'La capacidad mínima es 1',
            'precio.required' => 'El precio es obligatorio',
            'precio.numeric' => 'El precio debe ser un número válido',
            'precio.min' => 'El precio no puede ser negativo',
        ];
    }
}
