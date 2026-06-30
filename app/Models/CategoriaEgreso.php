<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CategoriaEgreso extends Model
{
    protected $table = 'finance.categorias_egreso';
    protected $connection = 'pgsql';
    public $timestamps = false;
    public $incrementing = false;

    protected $fillable = ['nombre', 'tipo_general'];
}
