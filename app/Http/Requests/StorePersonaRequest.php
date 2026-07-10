<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePersonaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'tipo' => 'required|in:instructor,staff,secretaria,admin',
            'cedula' => ['nullable', 'string', 'max:20', Rule::unique('pgsql.people.personas', 'cedula')->withoutTrashed()],
            'nombres' => 'required|string|max:100',
            'apellidos' => 'required|string|max:100',
            'correo' => 'nullable|email|max:150',
            'celular' => 'nullable|string|max:20',
            'ciudad' => 'nullable|string|max:100',
            'ciudad_id' => 'nullable|integer|exists:pgsql.core.ciudades,id',
            'es_activo' => 'boolean',
        ];
    }

    public function messages(): array
    {
        return [
            'tipo.required' => 'El tipo de persona es obligatorio',
            'tipo.in' => 'El tipo de persona no es válido',
            'cedula.max' => 'La cédula no debe tener más de 20 caracteres',
            'cedula.unique' => 'La cédula ya está registrada',
            'nombres.required' => 'Los nombres son obligatorios',
            'nombres.max' => 'Los nombres no deben tener más de 100 caracteres',
            'apellidos.required' => 'Los apellidos son obligatorios',
            'apellidos.max' => 'Los apellidos no deben tener más de 100 caracteres',
            'correo.email' => 'El correo debe ser una dirección válida',
            'correo.max' => 'El correo no debe tener más de 150 caracteres',
            'celular.max' => 'El celular no debe tener más de 20 caracteres',
            'ciudad_id.integer' => 'La ciudad seleccionada no es válida',
            'ciudad_id.exists' => 'La ciudad seleccionada no existe',
        ];
    }
}
