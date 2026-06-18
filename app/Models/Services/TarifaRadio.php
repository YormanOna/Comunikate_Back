<?php

namespace App\Models\Services;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TarifaRadio extends Model
{
    use HasFactory;

    protected $table = 'services.tarifas_radio';

    public $timestamps = false;

    public $incrementing = true;

    protected $keyType = 'int';

    protected $fillable = [
        'nombre',
        'descripcion',
        'precio_por_hora',
        'incluye_operador',
        'es_activo',
    ];

    protected function casts(): array
    {
        return [
            'precio_por_hora' => 'decimal:2',
            'incluye_operador' => 'boolean',
            'es_activo' => 'boolean',
        ];
    }

    public function reservas(): HasMany
    {
        return $this->hasMany(ReservaRadio::class, 'tarifa_id');
    }
}
