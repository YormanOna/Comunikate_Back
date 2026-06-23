<?php

namespace Database\Seeders;

use App\Models\CuentaSistema;
use App\Models\Persona;
use Illuminate\Database\Seeder;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $persona = Persona::firstOrCreate(
            ['cedula' => env('ADMIN_CEDULA')],
            [
                'tipo' => 'admin',
                'nombres' => env('ADMIN_NOMBRES'),
                'apellidos' => env('ADMIN_APELLIDOS'),
                'correo' => env('ADMIN_EMAIL'),
                'celular' => env('ADMIN_CELULAR'),
                'ciudad' => env('ADMIN_CIUDAD'),
                'es_activo' => true,
            ]
        );

        $cuenta = CuentaSistema::firstOrCreate(
            ['username' => env('ADMIN_USERNAME', 'admin')],
            [
                'persona_id' => $persona->id,
                'password_hash' => env('ADMIN_PASSWORD', 'admin123'),
            ]
        );

        if (!$cuenta->hasRole('Administrador')) {
            $cuenta->assignRole('Administrador');
        }
    }
}
