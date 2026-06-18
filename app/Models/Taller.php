<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Taller extends Model
{
    use HasUuids;

    protected $connection = 'pgsql';
    protected $table = 'academic.talleres';

    protected $fillable = [
        'nombre',
        'descripcion',
        'fecha',
        'hora_inicio',
        'hora_fin',
        'instructor_id',
        'modalidad',
        'capacidad_maxima',
        'precio',
        'estado',
    ];

    public $timestamps = false;

    protected $casts = [
        'fecha' => 'date',
        'precio' => 'decimal:2',
        'capacidad_maxima' => 'integer',
    ];

    public function instructor(): BelongsTo
    {
        return $this->belongsTo(Persona::class, 'instructor_id');
    }

    public function inscripciones(): HasMany
    {
        return $this->hasMany(InscripcionTaller::class, 'taller_id');
    }

    public function asistencias(): HasMany
    {
        return $this->hasMany(AsistenciaTaller::class, 'taller_id');
    }

    public function scopeActivos($query)
    {
        return $query->whereIn('estado', ['pendiente', 'confirmado']);
    }

    public function scopePorInstructor($query, $instructorId)
    {
        return $query->where('instructor_id', $instructorId);
    }

    public function scopeProximos($query)
    {
        return $query->where('fecha', '>=', now()->toDateString())
            ->whereIn('estado', ['pendiente', 'confirmado']);
    }

    public function scopePasados($query)
    {
        return $query->where('fecha', '<', now()->toDateString());
    }

    public function totalInscripciones(): int
    {
        return $this->inscripciones()->where('estado', 'activo')->count();
    }

    public function capacidadDisponible(): int
    {
        return $this->capacidad_maxima - $this->totalInscripciones();
    }

    public function permitirInscripcion(): bool
    {
        return $this->fecha && $this->fecha->isFuture()
            && $this->estado !== 'cancelado'
            && $this->capacidadDisponible() > 0;
    }

    public function tasaOcupacion(): float
    {
        if (!$this->capacidad_maxima) return 0;
        return ($this->totalInscripciones() / $this->capacidad_maxima) * 100;
    }
}
