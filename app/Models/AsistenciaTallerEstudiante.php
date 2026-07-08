<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AsistenciaTallerEstudiante extends Model
{
    use HasUuids;

    protected $connection = 'pgsql';
    protected $table = 'academic.asistencia_taller_estudiantes';

    protected $fillable = [
        'asistencia_taller_id',
        'inscripcion_taller_id',
        'participante_externo_id',
        'asistio',
        'estado',
        'observaciones',
    ];

    protected $casts = [
        'asistio' => 'boolean',
    ];

    public function asistenciaTaller(): BelongsTo
    {
        return $this->belongsTo(AsistenciaTaller::class, 'asistencia_taller_id');
    }

    public function inscripcionTaller(): BelongsTo
    {
        return $this->belongsTo(InscripcionTaller::class, 'inscripcion_taller_id');
    }
}
