<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TransaccionEgreso extends Model
{
    use HasUuids;

    protected $table = 'finance.transacciones_egreso';
    protected $connection = 'pgsql';
    public $timestamps = false;

    protected $fillable = [
        'categoria_id',
        'subcategoria',
        'descripcion',
        'monto',
        'proveedor_beneficiario',
        'metodo_pago',
        'comprobante_url',
        'fecha_pago',
        'registrado_por',
        'notas',
    ];

    protected function casts(): array
    {
        return [
            'monto' => 'decimal:2',
            'fecha_pago' => 'datetime',
        ];
    }

    public function categoria(): BelongsTo
    {
        return $this->belongsTo(CategoriaEgreso::class, 'categoria_id');
    }

    public function registrador(): BelongsTo
    {
        return $this->belongsTo(Persona::class, 'registrado_por');
    }
}
