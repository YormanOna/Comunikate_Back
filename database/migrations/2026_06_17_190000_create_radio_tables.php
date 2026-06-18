<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // ====================================================================
        // 1. Tarifas de Radio (catálogo de tipos de sesión)
        // ====================================================================
        if (!Schema::connection('pgsql')->hasTable('services.tarifas_radio')) {
            Schema::connection('pgsql')->create('services.tarifas_radio', function (Blueprint $table) {
                $table->id();
                $table->string('nombre', 100);
                $table->text('descripcion')->nullable();
                $table->decimal('precio_por_hora', 10, 2)->default(0);
                $table->boolean('incluye_operador')->default(true);
                $table->boolean('es_activo')->default(true);
            });

            DB::connection('pgsql')->statement("
                INSERT INTO services.tarifas_radio (nombre, descripcion, precio_por_hora, incluye_operador, es_activo) VALUES
                ('Grabación', 'Grabación de audio en estudio de radio', 25.00, true, true),
                ('Transmisión en vivo', 'Transmisión en vivo con operador', 40.00, true, true),
                ('Producción', 'Producción y edición de contenido', 30.00, false, true),
                ('Ensayo', 'Ensayo sin operador', 15.00, false, true)
            ");
        }

        // ====================================================================
        // 2. Reservas de Radio
        // ====================================================================
        if (!Schema::connection('pgsql')->hasTable('services.reservas_radio')) {
            Schema::connection('pgsql')->create('services.reservas_radio', function (Blueprint $table) {
                $table->uuid('id')->primary()->default(DB::raw('uuid_generate_v4()'));
                $table->unsignedBigInteger('tarifa_id');
                $table->uuid('persona_id')->nullable();
                $table->uuid('cliente_externo_id')->nullable();
                $table->date('fecha_reserva');
                $table->time('hora_inicio');
                $table->time('hora_fin');
                $table->boolean('incluye_operador')->default(false);
                $table->uuid('operador_id')->nullable();
                $table->decimal('precio_total', 10, 2)->default(0);
                $table->text('observaciones')->nullable();
                $table->string('estado', 20)->default('reservado');
                $table->timestampsTz();

                $table->foreign('tarifa_id')->references('id')->on('services.tarifas_radio');
                $table->foreign('persona_id')->references('id')->on('people.personas')->nullOnDelete();
                $table->foreign('cliente_externo_id')->references('id')->on('people.clientes_externos')->nullOnDelete();
                $table->foreign('operador_id')->references('id')->on('people.personas')->nullOnDelete();

                $table->index('fecha_reserva');
                $table->index('estado');
                $table->index('operador_id');
            });

            DB::connection('pgsql')->statement("
                ALTER TABLE services.reservas_radio
                ADD CONSTRAINT reservas_radio_estado_check
                CHECK (estado IN ('reservado','confirmado','en_progreso','completado','cancelado'))
            ");

            DB::connection('pgsql')->statement("
                ALTER TABLE services.reservas_radio
                ADD CONSTRAINT reservas_radio_cliente_check
                CHECK (num_nonnulls(persona_id, cliente_externo_id) = 1)
            ");
        }

        // ====================================================================
        // 3. Agregar reserva_radio_id a asignaciones_personal
        // ====================================================================
        Schema::connection('pgsql')->table('services.asignaciones_personal', function (Blueprint $table) {
            $table->uuid('reserva_radio_id')->nullable()->after('edicion_video_id');

            $table->foreign('reserva_radio_id')
                ->references('id')->on('services.reservas_radio')
                ->onDelete('cascade');
        });

        // Eliminar CHECK anterior y crear uno nuevo que incluya reserva_radio_id
        DB::connection('pgsql')->statement("
            ALTER TABLE services.asignaciones_personal
            DROP CONSTRAINT IF EXISTS chk_una_sola_asignacion
        ");

        DB::connection('pgsql')->statement("
            ALTER TABLE services.asignaciones_personal
            ADD CONSTRAINT chk_una_sola_asignacion
            CHECK (num_nonnulls(reserva_podcast_id, servicio_streaming_id, servicio_produccion_id, edicion_video_id, reserva_radio_id) = 1)
        ");

        // ====================================================================
        // 4. Agregar reserva_radio_id a cuentas_por_cobrar
        // ====================================================================
        Schema::connection('pgsql')->table('finance.cuentas_por_cobrar', function (Blueprint $table) {
            $table->uuid('reserva_radio_id')->nullable()->after('alquiler_equipo_id');

            $table->foreign('reserva_radio_id')
                ->references('id')->on('services.reservas_radio')
                ->onDelete('set null');

            $table->index('reserva_radio_id');
        });
    }

    public function down(): void
    {
        // Revertir cuentas_por_cobrar
        Schema::connection('pgsql')->table('finance.cuentas_por_cobrar', function (Blueprint $table) {
            $table->dropForeign(['reserva_radio_id']);
            $table->dropIndex(['reserva_radio_id']);
            $table->dropColumn('reserva_radio_id');
        });

        // Revertir asignaciones_personal
        Schema::connection('pgsql')->table('services.asignaciones_personal', function (Blueprint $table) {
            $table->dropForeign(['reserva_radio_id']);
            $table->dropColumn('reserva_radio_id');
        });

        // Restaurar CHECK original
        DB::connection('pgsql')->statement("
            ALTER TABLE services.asignaciones_personal
            DROP CONSTRAINT IF EXISTS chk_una_sola_asignacion
        ");
        DB::connection('pgsql')->statement("
            ALTER TABLE services.asignaciones_personal
            ADD CONSTRAINT chk_una_sola_asignacion
            CHECK (num_nonnulls(reserva_podcast_id, servicio_streaming_id, servicio_produccion_id, edicion_video_id) = 1)
        ");

        Schema::connection('pgsql')->dropIfExists('services.reservas_radio');
        Schema::connection('pgsql')->dropIfExists('services.tarifas_radio');
    }
};
