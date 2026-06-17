--
-- PostgreSQL database dump
--

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: academic; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA academic;


ALTER SCHEMA academic OWNER TO postgres;

--
-- Name: audit; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA audit;


ALTER SCHEMA audit OWNER TO postgres;

--
-- Name: core; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA core;


ALTER SCHEMA core OWNER TO postgres;

--
-- Name: finance; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA finance;


ALTER SCHEMA finance OWNER TO postgres;

--
-- Name: ops; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ops;


ALTER SCHEMA ops OWNER TO postgres;

--
-- Name: people; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA people;


ALTER SCHEMA people OWNER TO postgres;

--
-- Name: services; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA services;


ALTER SCHEMA services OWNER TO postgres;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: t_estado_matricula; Type: TYPE; Schema: academic; Owner: postgres
--

CREATE TYPE academic.t_estado_matricula AS ENUM (
    'activo',
    'completado',
    'retirado',
    'reprobado'
);


ALTER TYPE academic.t_estado_matricula OWNER TO postgres;

--
-- Name: t_estado_oferta; Type: TYPE; Schema: academic; Owner: postgres
--

CREATE TYPE academic.t_estado_oferta AS ENUM (
    'pendiente',
    'confirmado',
    'en_progreso',
    'completado',
    'cancelado'
);


ALTER TYPE academic.t_estado_oferta OWNER TO postgres;

--
-- Name: t_estado_pago; Type: TYPE; Schema: finance; Owner: postgres
--

CREATE TYPE finance.t_estado_pago AS ENUM (
    'pendiente',
    'abonado',
    'pagado',
    'anulado'
);


ALTER TYPE finance.t_estado_pago OWNER TO postgres;

--
-- Name: t_estado_verificacion; Type: TYPE; Schema: finance; Owner: postgres
--

CREATE TYPE finance.t_estado_verificacion AS ENUM (
    'pendiente',
    'aprobado',
    'rechazado'
);


ALTER TYPE finance.t_estado_verificacion OWNER TO postgres;

--
-- Name: t_metodo_pago; Type: TYPE; Schema: finance; Owner: postgres
--

CREATE TYPE finance.t_metodo_pago AS ENUM (
    'efectivo',
    'transferencia',
    'deposito',
    'tarjeta',
    'otro'
);


ALTER TYPE finance.t_metodo_pago OWNER TO postgres;

--
-- Name: t_estado_reserva; Type: TYPE; Schema: services; Owner: postgres
--

CREATE TYPE services.t_estado_reserva AS ENUM (
    'reservado',
    'confirmado',
    'en_progreso',
    'completado',
    'cancelado'
);


ALTER TYPE services.t_estado_reserva OWNER TO postgres;

--
-- Name: fn_actualizar_perfil_estudiante(); Type: FUNCTION; Schema: academic; Owner: postgres
--

CREATE FUNCTION academic.fn_actualizar_perfil_estudiante() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO people.perfil_estudiante (persona_id, primera_matricula, ultima_matricula, total_cursos)
    VALUES (NEW.estudiante_id, NEW.fecha_inscripcion::DATE, NEW.fecha_inscripcion::DATE, 1)
    ON CONFLICT (persona_id) DO UPDATE
        SET ultima_matricula = GREATEST(people.perfil_estudiante.ultima_matricula, NEW.fecha_inscripcion::DATE),
            primera_matricula = LEAST(people.perfil_estudiante.primera_matricula, NEW.fecha_inscripcion::DATE),
            total_cursos = (
                SELECT COUNT(*)
                FROM academic.matriculas
                WHERE estudiante_id = NEW.estudiante_id
                  AND deleted_at IS NULL
            );
    RETURN NEW;
END;
$$;


ALTER FUNCTION academic.fn_actualizar_perfil_estudiante() OWNER TO postgres;

--
-- Name: fn_actualizar_resumen_curso(); Type: FUNCTION; Schema: academic; Owner: postgres
--

CREATE FUNCTION academic.fn_actualizar_resumen_curso() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_curso_id UUID;
BEGIN
    v_curso_id := COALESCE(NEW.curso_abierto_id, OLD.curso_abierto_id);

    UPDATE academic.cursos_abiertos ca
    SET estudiantes_inscritos = (
            SELECT COUNT(*)
            FROM academic.matriculas m
            WHERE m.curso_abierto_id = v_curso_id
              AND m.deleted_at IS NULL
        ),
        ingreso_proyectado = (
            ca.precio_base * (
                SELECT COUNT(*)
                FROM academic.matriculas m
                WHERE m.curso_abierto_id = v_curso_id
                  AND m.deleted_at IS NULL
            )
        )
    WHERE ca.id = v_curso_id;

    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION academic.fn_actualizar_resumen_curso() OWNER TO postgres;

--
-- Name: fn_set_updated_at(); Type: FUNCTION; Schema: core; Owner: postgres
--

CREATE FUNCTION core.fn_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION core.fn_set_updated_at() OWNER TO postgres;

--
-- Name: fn_actualizar_cuenta_cobrar(); Type: FUNCTION; Schema: finance; Owner: postgres
--

CREATE FUNCTION finance.fn_actualizar_cuenta_cobrar() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_cuenta_id     UUID;
    v_total_abonado NUMERIC(10,2);
    v_total_deuda   NUMERIC(10,2);
BEGIN
    v_cuenta_id := COALESCE(NEW.cuenta_cobrar_id, OLD.cuenta_cobrar_id);

    SELECT COALESCE(SUM(monto), 0) INTO v_total_abonado
    FROM finance.transacciones_ingreso
    WHERE cuenta_cobrar_id = v_cuenta_id;

    SELECT monto_total INTO v_total_deuda
    FROM finance.cuentas_por_cobrar
    WHERE id = v_cuenta_id;

    UPDATE finance.cuentas_por_cobrar
    SET
        monto_abonado = v_total_abonado,
        estado = CASE
            WHEN v_total_abonado >= v_total_deuda THEN 'pagado'::finance.t_estado_pago
            WHEN v_total_abonado > 0 THEN 'abonado'::finance.t_estado_pago
            ELSE 'pendiente'::finance.t_estado_pago
        END,
        updated_at = NOW()
    WHERE id = v_cuenta_id;

    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION finance.fn_actualizar_cuenta_cobrar() OWNER TO postgres;

--
-- Name: fn_registrar_movimiento_caja(); Type: FUNCTION; Schema: finance; Owner: postgres
--

CREATE FUNCTION finance.fn_registrar_movimiento_caja() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total_ingresos NUMERIC(14,2);
    v_total_egresos  NUMERIC(14,2);
    v_saldo          NUMERIC(14,2);
    v_tipo           VARCHAR(20);
    v_descripcion    TEXT;
BEGIN
    IF TG_TABLE_NAME = 'transacciones_ingreso' THEN
        v_tipo := 'INGRESO';
        v_descripcion := 'Ingreso registrado en cuenta por cobrar';
    ELSE
        v_tipo := 'EGRESO';
        v_descripcion := COALESCE(NEW.descripcion, OLD.descripcion);
    END IF;

    SELECT COALESCE(SUM(monto), 0) INTO v_total_ingresos FROM finance.transacciones_ingreso;
    SELECT COALESCE(SUM(monto), 0) INTO v_total_egresos  FROM finance.transacciones_egreso;
    v_saldo := v_total_ingresos - v_total_egresos;

    UPDATE finance.resumen_caja
    SET total_ingresos = v_total_ingresos,
        total_egresos  = v_total_egresos,
        saldo_actual   = v_saldo,
        updated_at     = NOW()
    WHERE id = 1;

    IF TG_OP <> 'DELETE' THEN
        INSERT INTO audit.eventos_financieros (
            tipo_evento,
            transaccion_ingreso_id,
            transaccion_egreso_id,
            monto,
            descripcion,
            fecha_evento,
            registrado_por,
            saldo_resultante
        ) VALUES (
            v_tipo,
            CASE WHEN TG_TABLE_NAME = 'transacciones_ingreso' THEN NEW.id ELSE NULL END,
            CASE WHEN TG_TABLE_NAME = 'transacciones_egreso' THEN NEW.id ELSE NULL END,
            NEW.monto,
            v_descripcion,
            COALESCE(NEW.fecha_pago, NOW()),
            NEW.registrado_por,
            v_saldo
        );
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION finance.fn_registrar_movimiento_caja() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: asesorias; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.asesorias (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid,
    cliente_externo_id uuid,
    instructor_id uuid NOT NULL,
    titulo character varying(200) NOT NULL,
    descripcion text,
    modalidad character varying(50) NOT NULL,
    fecha date NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    notas_sesion text,
    precio numeric(10,2) DEFAULT 0 NOT NULL,
    estado services.t_estado_reserva DEFAULT 'reservado'::services.t_estado_reserva,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT asesorias_modalidad_check CHECK (((modalidad)::text = ANY ((ARRAY['presencial'::character varying, 'virtual'::character varying])::text[]))),
    CONSTRAINT chk_asesoria_cliente CHECK ((num_nonnulls(persona_id, cliente_externo_id) = 1))
);


ALTER TABLE academic.asesorias OWNER TO postgres;

--
-- Name: asistencias; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.asistencias (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    matricula_id uuid NOT NULL,
    clase_id uuid NOT NULL,
    asistio boolean DEFAULT false,
    estado character varying(20),
    observaciones text
);


ALTER TABLE academic.asistencias OWNER TO postgres;

--
-- Name: cambios_horario; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.cambios_horario (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    matricula_origen_id uuid NOT NULL,
    curso_abierto_nuevo_id uuid NOT NULL,
    motivo text,
    autorizado_por uuid,
    fecha_cambio timestamp with time zone DEFAULT now()
);


ALTER TABLE academic.cambios_horario OWNER TO postgres;

--
-- Name: catalogo_cursos; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.catalogo_cursos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    categoria character varying(50) NOT NULL,
    nombre character varying(200) NOT NULL,
    descripcion text,
    modulos_default smallint DEFAULT 2,
    duracion_horas_total integer,
    programa_id uuid,
    creditos integer DEFAULT 3 NOT NULL,
    horas_totales integer DEFAULT 40 NOT NULL,
    es_activo boolean DEFAULT true NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone,
    imagen character varying(500),
    color character varying(7),
    CONSTRAINT catalogo_cursos_categoria_check CHECK (((categoria)::text = ANY ((ARRAY['regular'::character varying, 'personalizado'::character varying, 'taller'::character varying])::text[])))
);


ALTER TABLE academic.catalogo_cursos OWNER TO postgres;

--
-- Name: certificados; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.certificados (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    estudiante_id uuid NOT NULL,
    catalogo_id uuid NOT NULL,
    curso_abierto_id uuid,
    modulo_id uuid,
    cedula_impresa character varying(20) NOT NULL,
    fecha_emision date DEFAULT CURRENT_DATE,
    codigo_certificado character varying(100) NOT NULL,
    archivo_pdf_url character varying(500),
    estado character varying(20) DEFAULT 'generado'::character varying NOT NULL,
    fecha_entrega date,
    entregado_fisicamente boolean DEFAULT false NOT NULL,
    verificaciones_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


ALTER TABLE academic.certificados OWNER TO postgres;

--
-- Name: clases; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.clases (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    modulo_id uuid NOT NULL,
    instructor_id uuid,
    fecha_clase date NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    observaciones text
);


ALTER TABLE academic.clases OWNER TO postgres;

--
-- Name: clases_extras; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.clases_extras (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    estudiante_id uuid NOT NULL,
    instructor_id uuid,
    curso_abierto_id uuid,
    fecha_clase date NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    motivo text,
    precio numeric(10,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE academic.clases_extras OWNER TO postgres;

--
-- Name: comentarios_curso; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.comentarios_curso (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    curso_abierto_id uuid NOT NULL,
    autor_id uuid NOT NULL,
    comentario text NOT NULL,
    calificacion smallint,
    es_publico boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT comentarios_curso_calificacion_check CHECK (((calificacion >= 1) AND (calificacion <= 5)))
);


ALTER TABLE academic.comentarios_curso OWNER TO postgres;

--
-- Name: cursos_abiertos; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.cursos_abiertos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    catalogo_curso_id uuid NOT NULL,
    instructor_titular_id uuid,
    ciudad_id bigint,
    horario_id uuid,
    modalidad character varying(50) NOT NULL,
    capacidad_maxima smallint DEFAULT 12 NOT NULL,
    precio_base numeric(10,2) NOT NULL,
    estudiantes_inscritos integer DEFAULT 0 NOT NULL,
    ingreso_proyectado numeric(12,2) DEFAULT 0 NOT NULL,
    fecha_inicio date,
    fecha_fin date,
    estado academic.t_estado_oferta DEFAULT 'pendiente'::academic.t_estado_oferta,
    created_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    nombre_instancia character varying(255),
    semestre character varying(50),
    docente_id uuid,
    es_activo boolean DEFAULT true,
    observaciones text,
    updated_at timestamp without time zone,
    CONSTRAINT cursos_abiertos_modalidad_check CHECK (((modalidad)::text = ANY ((ARRAY['presencial'::character varying, 'virtual'::character varying])::text[])))
);


ALTER TABLE academic.cursos_abiertos OWNER TO postgres;

--
-- Name: horarios; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.horarios (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombre_referencial character varying(100) NOT NULL,
    dia_semana smallint[],
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    es_activo boolean DEFAULT true
);


ALTER TABLE academic.horarios OWNER TO postgres;

--
-- Name: horarios_dias; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.horarios_dias (
    id bigint NOT NULL,
    horario_id uuid NOT NULL,
    dia_semana smallint NOT NULL
);


ALTER TABLE academic.horarios_dias OWNER TO postgres;

--
-- Name: COLUMN horarios_dias.dia_semana; Type: COMMENT; Schema: academic; Owner: postgres
--

COMMENT ON COLUMN academic.horarios_dias.dia_semana IS '1=Lunes, 2=Martes, ..., 7=Domingo';


--
-- Name: horarios_dias_id_seq; Type: SEQUENCE; Schema: academic; Owner: postgres
--

CREATE SEQUENCE academic.horarios_dias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE academic.horarios_dias_id_seq OWNER TO postgres;

--
-- Name: horarios_dias_id_seq; Type: SEQUENCE OWNED BY; Schema: academic; Owner: postgres
--

ALTER SEQUENCE academic.horarios_dias_id_seq OWNED BY academic.horarios_dias.id;


--
-- Name: inscripciones_taller; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.inscripciones_taller (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    taller_id uuid NOT NULL,
    persona_id uuid NOT NULL,
    precio_pagado numeric(10,2) NOT NULL,
    estado academic.t_estado_matricula DEFAULT 'activo'::academic.t_estado_matricula,
    fecha_inscripcion timestamp with time zone DEFAULT now()
);


ALTER TABLE academic.inscripciones_taller OWNER TO postgres;

--
-- Name: matriculas; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.matriculas (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    estudiante_id uuid,
    curso_abierto_id uuid NOT NULL,
    precio_total numeric(10,2) NOT NULL,
    tipo_pago character varying(20) DEFAULT 'completo'::character varying NOT NULL,
    voucher_url character varying(500),
    estado academic.t_estado_matricula DEFAULT 'activo'::academic.t_estado_matricula,
    fecha_inscripcion timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    solicitud_inscripcion_id uuid,
    CONSTRAINT matriculas_tipo_pago_check CHECK (((tipo_pago)::text = ANY ((ARRAY['completo'::character varying, 'bono'::character varying, 'abono'::character varying])::text[])))
);


ALTER TABLE academic.matriculas OWNER TO postgres;

--
-- Name: modulos; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.modulos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    curso_abierto_id uuid NOT NULL,
    nombre_modulo character varying(100) NOT NULL,
    numero_orden smallint NOT NULL,
    fecha_inicio date,
    fecha_fin date
);


ALTER TABLE academic.modulos OWNER TO postgres;

--
-- Name: notas; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.notas (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    matricula_id uuid NOT NULL,
    modulo_id uuid NOT NULL,
    calificacion numeric(4,2),
    aprobado boolean,
    observaciones text,
    CONSTRAINT notas_nota_check CHECK (((calificacion >= (0)::numeric) AND (calificacion <= (10)::numeric)))
);


ALTER TABLE academic.notas OWNER TO postgres;

--
-- Name: solicitudes_inscripcion; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.solicitudes_inscripcion (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid,
    participante_externo_id uuid,
    es_participante_externo boolean DEFAULT false NOT NULL,
    curso_abierto_id uuid NOT NULL,
    monto_solicitado numeric(10,2) NOT NULL,
    tipo_pago character varying(20) DEFAULT 'completo'::character varying NOT NULL,
    archivo_comprobante_url character varying(500),
    tipo_comprobante character varying(50),
    fecha_pago_declarada date,
    estado character varying(30) DEFAULT 'registrado'::character varying NOT NULL,
    validado_por uuid,
    motivo_rechazo text,
    observaciones_validacion text,
    fecha_validacion timestamp(0) with time zone,
    created_at timestamp(0) with time zone,
    updated_at timestamp(0) with time zone,
    deleted_at timestamp(0) with time zone,
    archivo_cedula_url character varying(500),
    CONSTRAINT check_estado CHECK (((estado)::text = ANY ((ARRAY['registrado'::character varying, 'pendiente_validacion'::character varying, 'aprobado'::character varying, 'rechazado'::character varying, 'matricula_creada'::character varying, 'cancelado'::character varying])::text[]))),
    CONSTRAINT check_excluyente_persona CHECK (((
CASE
    WHEN (persona_id IS NOT NULL) THEN 1
    ELSE 0
END +
CASE
    WHEN (participante_externo_id IS NOT NULL) THEN 1
    ELSE 0
END) = 1)),
    CONSTRAINT check_tipo_pago CHECK (((tipo_pago)::text = ANY ((ARRAY['completo'::character varying, 'abono'::character varying])::text[])))
);


ALTER TABLE academic.solicitudes_inscripcion OWNER TO postgres;

--
-- Name: talleres; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.talleres (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombre character varying(200) NOT NULL,
    descripcion text,
    instructor_id uuid,
    ciudad_id bigint,
    modalidad character varying(50) NOT NULL,
    capacidad_maxima smallint DEFAULT 30 NOT NULL,
    precio numeric(10,2) NOT NULL,
    fecha date NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    abierto_externos boolean DEFAULT true,
    estado academic.t_estado_oferta DEFAULT 'pendiente'::academic.t_estado_oferta,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT talleres_modalidad_check CHECK (((modalidad)::text = ANY ((ARRAY['presencial'::character varying, 'virtual'::character varying])::text[])))
);


ALTER TABLE academic.talleres OWNER TO postgres;

--
-- Name: traslados_modulo; Type: TABLE; Schema: academic; Owner: postgres
--

CREATE TABLE academic.traslados_modulo (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    matricula_origen_id uuid NOT NULL,
    modulo_origen_id uuid NOT NULL,
    curso_abierto_destino_id uuid NOT NULL,
    modulo_destino_id uuid NOT NULL,
    motivo text,
    autorizado_por uuid,
    fecha_traslado timestamp with time zone DEFAULT now()
);


ALTER TABLE academic.traslados_modulo OWNER TO postgres;

--
-- Name: v_horarios_con_dias; Type: VIEW; Schema: academic; Owner: postgres
--

CREATE VIEW academic.v_horarios_con_dias AS
 SELECT h.id,
    h.nombre_referencial,
    h.hora_inicio,
    h.hora_fin,
    h.es_activo,
    COALESCE(array_agg(hd.dia_semana ORDER BY hd.dia_semana), ARRAY[]::smallint[]) AS dia_semana
   FROM (academic.horarios h
     LEFT JOIN academic.horarios_dias hd ON ((h.id = hd.horario_id)))
  GROUP BY h.id, h.nombre_referencial, h.hora_inicio, h.hora_fin, h.es_activo;


ALTER VIEW academic.v_horarios_con_dias OWNER TO postgres;

--
-- Name: vista_cursos_finanzas; Type: VIEW; Schema: academic; Owner: postgres
--

CREATE VIEW academic.vista_cursos_finanzas AS
 SELECT ca.id,
    cc.nombre AS curso,
    ca.modalidad,
    ca.precio_base,
    ca.capacidad_maxima,
    ca.estudiantes_inscritos,
    ca.ingreso_proyectado,
    COALESCE(sum(m.precio_total) FILTER (WHERE (m.deleted_at IS NULL)), (0)::numeric) AS ingreso_matriculado_real
   FROM ((academic.cursos_abiertos ca
     JOIN academic.catalogo_cursos cc ON ((cc.id = ca.catalogo_curso_id)))
     LEFT JOIN academic.matriculas m ON ((m.curso_abierto_id = ca.id)))
  GROUP BY ca.id, cc.nombre, ca.modalidad, ca.precio_base, ca.capacidad_maxima, ca.estudiantes_inscritos, ca.ingreso_proyectado;


ALTER VIEW academic.vista_cursos_finanzas OWNER TO postgres;

--
-- Name: eventos_financieros; Type: TABLE; Schema: audit; Owner: postgres
--

CREATE TABLE audit.eventos_financieros (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tipo_evento character varying(20) NOT NULL,
    transaccion_ingreso_id uuid,
    transaccion_egreso_id uuid,
    monto numeric(10,2) NOT NULL,
    descripcion text,
    fecha_evento timestamp with time zone DEFAULT now() NOT NULL,
    registrado_por uuid,
    saldo_resultante numeric(14,2) DEFAULT 0 NOT NULL,
    CONSTRAINT chk_evento_financiero_origen CHECK ((num_nonnulls(transaccion_ingreso_id, transaccion_egreso_id) = 1)),
    CONSTRAINT eventos_financieros_tipo_evento_check CHECK (((tipo_evento)::text = ANY ((ARRAY['INGRESO'::character varying, 'EGRESO'::character varying])::text[])))
);


ALTER TABLE audit.eventos_financieros OWNER TO postgres;

--
-- Name: inicios_sesion; Type: TABLE; Schema: audit; Owner: postgres
--

CREATE TABLE audit.inicios_sesion (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    cuenta_id uuid,
    persona_id uuid,
    username character varying(100),
    ip_address inet,
    user_agent text,
    fecha_inicio timestamp with time zone DEFAULT now() NOT NULL,
    exito boolean DEFAULT true NOT NULL,
    observaciones text
);


ALTER TABLE audit.inicios_sesion OWNER TO postgres;

--
-- Name: cache; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.cache (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    expiration bigint NOT NULL
);


ALTER TABLE core.cache OWNER TO postgres;

--
-- Name: cache_locks; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.cache_locks (
    key character varying(255) NOT NULL,
    owner character varying(255) NOT NULL,
    expiration bigint NOT NULL
);


ALTER TABLE core.cache_locks OWNER TO postgres;

--
-- Name: ciudades; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.ciudades (
    id bigint NOT NULL,
    nombre character varying(100) NOT NULL
);


ALTER TABLE core.ciudades OWNER TO postgres;

--
-- Name: ciudades_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.ciudades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.ciudades_id_seq OWNER TO postgres;

--
-- Name: ciudades_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.ciudades_id_seq OWNED BY core.ciudades.id;


--
-- Name: estudiante_segmentos; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.estudiante_segmentos (
    id uuid NOT NULL,
    nombre character varying(255) NOT NULL,
    descripcion text,
    criterios json NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE core.estudiante_segmentos OWNER TO postgres;

--
-- Name: failed_jobs; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.failed_jobs (
    id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    connection character varying(255) NOT NULL,
    queue character varying(255) NOT NULL,
    payload text NOT NULL,
    exception text NOT NULL,
    failed_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE core.failed_jobs OWNER TO postgres;

--
-- Name: failed_jobs_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.failed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.failed_jobs_id_seq OWNER TO postgres;

--
-- Name: failed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.failed_jobs_id_seq OWNED BY core.failed_jobs.id;


--
-- Name: job_batches; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.job_batches (
    id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    total_jobs integer NOT NULL,
    pending_jobs integer NOT NULL,
    failed_jobs integer NOT NULL,
    failed_job_ids text NOT NULL,
    options text,
    cancelled_at integer,
    created_at integer NOT NULL,
    finished_at integer
);


ALTER TABLE core.job_batches OWNER TO postgres;

--
-- Name: jobs; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.jobs (
    id bigint NOT NULL,
    queue character varying(255) NOT NULL,
    payload text NOT NULL,
    attempts smallint NOT NULL,
    reserved_at integer,
    available_at integer NOT NULL,
    created_at integer NOT NULL
);


ALTER TABLE core.jobs OWNER TO postgres;

--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.jobs_id_seq OWNER TO postgres;

--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.jobs_id_seq OWNED BY core.jobs.id;


--
-- Name: migrations; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.migrations (
    id integer NOT NULL,
    migration character varying(255) NOT NULL,
    batch integer NOT NULL
);


ALTER TABLE core.migrations OWNER TO postgres;

--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.migrations_id_seq OWNER TO postgres;

--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.migrations_id_seq OWNED BY core.migrations.id;


--
-- Name: model_has_permissions; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.model_has_permissions (
    permission_id bigint NOT NULL,
    model_type character varying(255) NOT NULL,
    model_id bigint NOT NULL
);


ALTER TABLE core.model_has_permissions OWNER TO postgres;

--
-- Name: model_has_roles; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.model_has_roles (
    role_id bigint NOT NULL,
    model_type character varying(255) NOT NULL,
    model_id uuid NOT NULL
);


ALTER TABLE core.model_has_roles OWNER TO postgres;

--
-- Name: password_reset_tokens; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.password_reset_tokens (
    email character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    created_at timestamp(0) without time zone
);


ALTER TABLE core.password_reset_tokens OWNER TO postgres;

--
-- Name: permissions; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.permissions (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    guard_name character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE core.permissions OWNER TO postgres;

--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.permissions_id_seq OWNER TO postgres;

--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.permissions_id_seq OWNED BY core.permissions.id;


--
-- Name: role_has_permissions; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.role_has_permissions (
    permission_id bigint NOT NULL,
    role_id bigint NOT NULL
);


ALTER TABLE core.role_has_permissions OWNER TO postgres;

--
-- Name: roles; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.roles (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    guard_name character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE core.roles OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.roles_id_seq OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.roles_id_seq OWNED BY core.roles.id;


--
-- Name: sessions; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.sessions (
    id character varying(255) NOT NULL,
    user_id bigint,
    ip_address character varying(45),
    user_agent text,
    payload text NOT NULL,
    last_activity integer NOT NULL
);


ALTER TABLE core.sessions OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.users (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    email_verified_at timestamp(0) without time zone,
    password character varying(255) NOT NULL,
    remember_token character varying(100),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE core.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.users_id_seq OWNED BY core.users.id;


--
-- Name: categorias_egreso; Type: TABLE; Schema: finance; Owner: postgres
--

CREATE TABLE finance.categorias_egreso (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    tipo_general character varying(50)
);


ALTER TABLE finance.categorias_egreso OWNER TO postgres;

--
-- Name: categorias_egreso_id_seq; Type: SEQUENCE; Schema: finance; Owner: postgres
--

CREATE SEQUENCE finance.categorias_egreso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE finance.categorias_egreso_id_seq OWNER TO postgres;

--
-- Name: categorias_egreso_id_seq; Type: SEQUENCE OWNED BY; Schema: finance; Owner: postgres
--

ALTER SEQUENCE finance.categorias_egreso_id_seq OWNED BY finance.categorias_egreso.id;


--
-- Name: cuentas_por_cobrar; Type: TABLE; Schema: finance; Owner: postgres
--

CREATE TABLE finance.cuentas_por_cobrar (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    matricula_id uuid,
    inscripcion_taller_id uuid,
    reserva_aula_id uuid,
    reserva_podcast_id uuid,
    servicio_streaming_id uuid,
    servicio_produccion_id uuid,
    edicion_video_id uuid,
    alquiler_equipo_id uuid,
    clase_extra_id uuid,
    asesoria_id uuid,
    monto_total numeric(10,2) NOT NULL,
    monto_abonado numeric(10,2) DEFAULT 0,
    saldo_pendiente numeric(10,2) GENERATED ALWAYS AS ((monto_total - monto_abonado)) STORED,
    estado finance.t_estado_pago DEFAULT 'pendiente'::finance.t_estado_pago,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    solicitud_inscripcion_id uuid,
    CONSTRAINT chk_un_origen CHECK ((num_nonnulls(matricula_id, inscripcion_taller_id, reserva_aula_id, reserva_podcast_id, servicio_streaming_id, servicio_produccion_id, edicion_video_id, alquiler_equipo_id, clase_extra_id, asesoria_id) = 1))
);


ALTER TABLE finance.cuentas_por_cobrar OWNER TO postgres;

--
-- Name: horas_instructor; Type: TABLE; Schema: finance; Owner: postgres
--

CREATE TABLE finance.horas_instructor (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    instructor_id uuid NOT NULL,
    clase_id uuid,
    curso_abierto_id uuid,
    fecha date NOT NULL,
    horas_trabajadas numeric(4,2) NOT NULL,
    tarifa_aplicada numeric(10,2) NOT NULL,
    monto_a_pagar numeric(10,2) GENERATED ALWAYS AS ((horas_trabajadas * tarifa_aplicada)) STORED,
    pagado boolean DEFAULT false,
    egreso_id uuid,
    CONSTRAINT horas_instructor_horas_trabajadas_check CHECK ((horas_trabajadas > (0)::numeric))
);


ALTER TABLE finance.horas_instructor OWNER TO postgres;

--
-- Name: resumen_caja; Type: TABLE; Schema: finance; Owner: postgres
--

CREATE TABLE finance.resumen_caja (
    id smallint DEFAULT 1 NOT NULL,
    total_ingresos numeric(14,2) DEFAULT 0 NOT NULL,
    total_egresos numeric(14,2) DEFAULT 0 NOT NULL,
    saldo_actual numeric(14,2) DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_resumen_caja_singleton CHECK ((id = 1))
);


ALTER TABLE finance.resumen_caja OWNER TO postgres;

--
-- Name: transacciones_egreso; Type: TABLE; Schema: finance; Owner: postgres
--

CREATE TABLE finance.transacciones_egreso (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    categoria_id integer NOT NULL,
    descripcion text NOT NULL,
    monto numeric(10,2) NOT NULL,
    comprobante_url text,
    fecha_pago timestamp with time zone DEFAULT now(),
    registrado_por uuid,
    CONSTRAINT transacciones_egreso_monto_check CHECK ((monto > (0)::numeric))
);


ALTER TABLE finance.transacciones_egreso OWNER TO postgres;

--
-- Name: transacciones_ingreso; Type: TABLE; Schema: finance; Owner: postgres
--

CREATE TABLE finance.transacciones_ingreso (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    cuenta_cobrar_id uuid NOT NULL,
    monto numeric(10,2) NOT NULL,
    metodo_pago finance.t_metodo_pago NOT NULL,
    comprobante_url text,
    fecha_pago timestamp with time zone DEFAULT now(),
    registrado_por uuid,
    observaciones text,
    estado_verificacion character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    verificado_por uuid,
    fecha_verificacion timestamp(0) without time zone,
    motivo_rechazo text,
    CONSTRAINT transacciones_ingreso_monto_check CHECK ((monto > (0)::numeric))
);


ALTER TABLE finance.transacciones_ingreso OWNER TO postgres;

--
-- Name: vista_balance_mensual; Type: VIEW; Schema: finance; Owner: postgres
--

CREATE VIEW finance.vista_balance_mensual AS
 SELECT EXTRACT(year FROM transacciones_ingreso.fecha_pago) AS anio,
    EXTRACT(month FROM transacciones_ingreso.fecha_pago) AS mes,
    'INGRESO'::text AS tipo_flujo,
    sum(transacciones_ingreso.monto) AS total_movimiento
   FROM finance.transacciones_ingreso
  GROUP BY (EXTRACT(year FROM transacciones_ingreso.fecha_pago)), (EXTRACT(month FROM transacciones_ingreso.fecha_pago))
UNION ALL
 SELECT EXTRACT(year FROM transacciones_egreso.fecha_pago) AS anio,
    EXTRACT(month FROM transacciones_egreso.fecha_pago) AS mes,
    'EGRESO'::text AS tipo_flujo,
    sum(transacciones_egreso.monto) AS total_movimiento
   FROM finance.transacciones_egreso
  GROUP BY (EXTRACT(year FROM transacciones_egreso.fecha_pago)), (EXTRACT(month FROM transacciones_egreso.fecha_pago));


ALTER VIEW finance.vista_balance_mensual OWNER TO postgres;

--
-- Name: personas; Type: TABLE; Schema: people; Owner: postgres
--

CREATE TABLE people.personas (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tipo character varying(50),
    cedula character varying(20),
    nombres character varying(100) NOT NULL,
    apellidos character varying(100) NOT NULL,
    correo character varying(150),
    celular character varying(20),
    ciudad_id bigint,
    cedula_photo_url character varying(500),
    es_activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone
);


ALTER TABLE people.personas OWNER TO postgres;

--
-- Name: vista_horas_instructor; Type: VIEW; Schema: finance; Owner: postgres
--

CREATE VIEW finance.vista_horas_instructor AS
 SELECT p.id AS instructor_id,
    (((p.nombres)::text || ' '::text) || (p.apellidos)::text) AS instructor,
    count(*) AS total_registros,
    sum(hi.horas_trabajadas) AS total_horas,
    sum(hi.monto_a_pagar) AS total_a_pagar,
    sum(hi.monto_a_pagar) FILTER (WHERE (hi.pagado = false)) AS pendiente_pago
   FROM (finance.horas_instructor hi
     JOIN people.personas p ON ((hi.instructor_id = p.id)))
  GROUP BY p.id, p.nombres, p.apellidos;


ALTER VIEW finance.vista_horas_instructor OWNER TO postgres;

--
-- Name: vista_movimientos_caja; Type: VIEW; Schema: finance; Owner: postgres
--

CREATE VIEW finance.vista_movimientos_caja AS
 SELECT ef.id,
    ef.tipo_evento,
    ef.monto,
    ef.descripcion,
    ef.fecha_evento,
    ef.saldo_resultante,
    (((p.nombres)::text || ' '::text) || (p.apellidos)::text) AS registrado_por_nombre
   FROM (audit.eventos_financieros ef
     LEFT JOIN people.personas p ON ((ef.registrado_por = p.id)))
  ORDER BY ef.fecha_evento, ef.id;


ALTER VIEW finance.vista_movimientos_caja OWNER TO postgres;

--
-- Name: registro_asistencia_staff; Type: TABLE; Schema: ops; Owner: postgres
--

CREATE TABLE ops.registro_asistencia_staff (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid NOT NULL,
    fecha date NOT NULL,
    hora_entrada time without time zone,
    hora_salida time without time zone,
    actividades text,
    observaciones text,
    registrado_por uuid,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE ops.registro_asistencia_staff OWNER TO postgres;

--
-- Name: clientes_externos; Type: TABLE; Schema: people; Owner: postgres
--

CREATE TABLE people.clientes_externos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombres character varying(100) NOT NULL,
    apellidos character varying(100),
    cedula character varying(20),
    correo character varying(150),
    celular character varying(20),
    ciudad_id bigint,
    observaciones text,
    ocupacion varchar(100),
    direccion text,
    estado_civil varchar(20),
    edad integer,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE people.clientes_externos OWNER TO postgres;

--
-- Name: aulas; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.aulas (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombre character varying(100) NOT NULL,
    capacidad smallint NOT NULL,
    precio_hora numeric(10,2) NOT NULL,
    caracteristicas text
);


ALTER TABLE services.aulas OWNER TO postgres;

--
-- Name: paquetes_podcast; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.paquetes_podcast (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    precio_base numeric(10,2) NOT NULL,
    es_activo boolean DEFAULT true
);


ALTER TABLE services.paquetes_podcast OWNER TO postgres;

--
-- Name: reservas_aulas; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.reservas_aulas (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    aula_id uuid NOT NULL,
    persona_id uuid,
    cliente_externo_id uuid,
    fecha_reserva date NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    precio_total numeric(10,2) NOT NULL,
    estado services.t_estado_reserva DEFAULT 'reservado'::services.t_estado_reserva,
    CONSTRAINT chk_cliente_aula CHECK ((num_nonnulls(persona_id, cliente_externo_id) = 1))
);


ALTER TABLE services.reservas_aulas OWNER TO postgres;

--
-- Name: reservas_podcast; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.reservas_podcast (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid,
    cliente_externo_id uuid,
    paquete_id integer NOT NULL,
    fecha_reserva date NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    precio_total numeric(10,2) NOT NULL,
    observaciones text,
    estado services.t_estado_reserva DEFAULT 'reservado'::services.t_estado_reserva,
    CONSTRAINT chk_cliente_podcast CHECK ((num_nonnulls(persona_id, cliente_externo_id) = 1))
);


ALTER TABLE services.reservas_podcast OWNER TO postgres;

--
-- Name: servicios_streaming; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.servicios_streaming (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid,
    cliente_externo_id uuid,
    fecha_evento date NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    lugar character varying(300) NOT NULL,
    descripcion text,
    precio_total numeric(10,2) NOT NULL,
    estado services.t_estado_reserva DEFAULT 'reservado'::services.t_estado_reserva,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT chk_cliente_streaming CHECK ((num_nonnulls(persona_id, cliente_externo_id) = 1))
);


ALTER TABLE services.servicios_streaming OWNER TO postgres;

--
-- Name: vista_agenda_unificada; Type: VIEW; Schema: ops; Owner: postgres
--

CREATE VIEW ops.vista_agenda_unificada AS
 SELECT 'CLASE_CURSO'::text AS tipo_evento,
    c.id AS referencia_id,
    ('Clase: '::text || (cc.nombre)::text) AS titulo,
    c.fecha_clase AS fecha,
    c.hora_inicio,
    c.hora_fin,
    (((p.nombres)::text || ' '::text) || (p.apellidos)::text) AS responsable
   FROM ((((academic.clases c
     JOIN academic.modulos m ON ((c.modulo_id = m.id)))
     JOIN academic.cursos_abiertos ca ON ((m.curso_abierto_id = ca.id)))
     JOIN academic.catalogo_cursos cc ON ((ca.catalogo_curso_id = cc.id)))
     LEFT JOIN people.personas p ON ((c.instructor_id = p.id)))
UNION ALL
 SELECT 'TALLER'::text AS tipo_evento,
    t.id AS referencia_id,
    ('Taller: '::text || (t.nombre)::text) AS titulo,
    t.fecha,
    t.hora_inicio,
    t.hora_fin,
    (((p.nombres)::text || ' '::text) || (p.apellidos)::text) AS responsable
   FROM (academic.talleres t
     LEFT JOIN people.personas p ON ((t.instructor_id = p.id)))
UNION ALL
 SELECT 'ALQUILER_AULA'::text AS tipo_evento,
    ra.id AS referencia_id,
    ('Aula: '::text || (a.nombre)::text) AS titulo,
    ra.fecha_reserva AS fecha,
    ra.hora_inicio,
    ra.hora_fin,
    COALESCE((((pp.nombres)::text || ' '::text) || (pp.apellidos)::text), (((ce.nombres)::text || ' '::text) || (COALESCE(ce.apellidos, ''::character varying))::text)) AS responsable
   FROM (((services.reservas_aulas ra
     JOIN services.aulas a ON ((ra.aula_id = a.id)))
     LEFT JOIN people.personas pp ON ((ra.persona_id = pp.id)))
     LEFT JOIN people.clientes_externos ce ON ((ra.cliente_externo_id = ce.id)))
UNION ALL
 SELECT 'PODCAST'::text AS tipo_evento,
    rp.id AS referencia_id,
    ('Podcast: '::text || (ppq.nombre)::text) AS titulo,
    rp.fecha_reserva AS fecha,
    rp.hora_inicio,
    rp.hora_fin,
    COALESCE((((pp.nombres)::text || ' '::text) || (pp.apellidos)::text), (((ce.nombres)::text || ' '::text) || (COALESCE(ce.apellidos, ''::character varying))::text)) AS responsable
   FROM (((services.reservas_podcast rp
     JOIN services.paquetes_podcast ppq ON ((rp.paquete_id = ppq.id)))
     LEFT JOIN people.personas pp ON ((rp.persona_id = pp.id)))
     LEFT JOIN people.clientes_externos ce ON ((rp.cliente_externo_id = ce.id)))
UNION ALL
 SELECT 'STREAMING'::text AS tipo_evento,
    ss.id AS referencia_id,
    ('Streaming: '::text || COALESCE(ss.descripcion, 'Servicio de streaming'::text)) AS titulo,
    ss.fecha_evento AS fecha,
    ss.hora_inicio,
    ss.hora_fin,
    COALESCE((((pp.nombres)::text || ' '::text) || (pp.apellidos)::text), (((ce.nombres)::text || ' '::text) || (COALESCE(ce.apellidos, ''::character varying))::text)) AS responsable
   FROM ((services.servicios_streaming ss
     LEFT JOIN people.personas pp ON ((ss.persona_id = pp.id)))
     LEFT JOIN people.clientes_externos ce ON ((ss.cliente_externo_id = ce.id)))
UNION ALL
 SELECT 'ASESORIA'::text AS tipo_evento,
    as2.id AS referencia_id,
    ('Asesoría: '::text || (as2.titulo)::text) AS titulo,
    as2.fecha,
    as2.hora_inicio,
    as2.hora_fin,
    (((pi.nombres)::text || ' '::text) || (pi.apellidos)::text) AS responsable
   FROM (academic.asesorias as2
     JOIN people.personas pi ON ((as2.instructor_id = pi.id)));


ALTER VIEW ops.vista_agenda_unificada OWNER TO postgres;

--
-- Name: cuentas_sistema; Type: TABLE; Schema: people; Owner: postgres
--

CREATE TABLE people.cuentas_sistema (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid NOT NULL,
    username character varying(100) NOT NULL,
    password_hash character varying(500) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    last_login timestamp with time zone
);


ALTER TABLE people.cuentas_sistema OWNER TO postgres;

--
-- Name: perfil_estudiante; Type: TABLE; Schema: people; Owner: postgres
--

CREATE TABLE people.perfil_estudiante (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid NOT NULL,
    fecha_nacimiento date,
    notas_internas text,
    primera_matricula date,
    ultima_matricula date,
    total_cursos integer DEFAULT 0,
    ocupacion varchar(100),
    direccion text,
    estado_civil varchar(20),
    edad integer
);


ALTER TABLE people.perfil_estudiante OWNER TO postgres;

--
-- Name: perfil_instructor; Type: TABLE; Schema: people; Owner: postgres
--

CREATE TABLE people.perfil_instructor (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid NOT NULL,
    especialidad character varying(200),
    bio text
);


ALTER TABLE people.perfil_instructor OWNER TO postgres;

--
-- Name: perfil_staff; Type: TABLE; Schema: people; Owner: postgres
--

CREATE TABLE people.perfil_staff (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid NOT NULL,
    cargo character varying(100) NOT NULL,
    salario_base numeric(10,2),
    fecha_ingreso date,
    es_pasante boolean DEFAULT false
);


ALTER TABLE people.perfil_staff OWNER TO postgres;

--
-- Name: cache; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cache (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    expiration integer
);


ALTER TABLE public.cache OWNER TO postgres;

--
-- Name: cache_locks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cache_locks (
    key character varying(255) NOT NULL,
    owner character varying(255) NOT NULL,
    expiration integer
);


ALTER TABLE public.cache_locks OWNER TO postgres;

--
-- Name: failed_jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.failed_jobs (
    id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    connection text NOT NULL,
    queue text NOT NULL,
    payload text NOT NULL,
    exception text NOT NULL,
    failed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.failed_jobs OWNER TO postgres;

--
-- Name: failed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.failed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.failed_jobs_id_seq OWNER TO postgres;

--
-- Name: failed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.failed_jobs_id_seq OWNED BY public.failed_jobs.id;


--
-- Name: job_batches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.job_batches (
    id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    total integer NOT NULL,
    pending integer NOT NULL,
    failed integer NOT NULL,
    failed_job_ids text NOT NULL,
    options text,
    cancelled_at integer,
    created_at integer NOT NULL,
    finished_at integer
);


ALTER TABLE public.job_batches OWNER TO postgres;

--
-- Name: jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jobs (
    id bigint NOT NULL,
    queue character varying(255) NOT NULL,
    payload text NOT NULL,
    attempts smallint NOT NULL,
    reserved_at integer,
    available_at integer NOT NULL,
    created_at integer NOT NULL
);


ALTER TABLE public.jobs OWNER TO postgres;

--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.jobs_id_seq OWNER TO postgres;

--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.jobs_id_seq OWNED BY public.jobs.id;


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    migration character varying(255) NOT NULL,
    batch integer NOT NULL
);


ALTER TABLE public.migrations OWNER TO postgres;

--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.migrations_id_seq OWNER TO postgres;

--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: personal_access_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_access_tokens (
    id bigint NOT NULL,
    tokenable_type character varying(255) NOT NULL,
    tokenable_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    token character varying(64) NOT NULL,
    abilities text,
    last_used_at timestamp without time zone,
    expires_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.personal_access_tokens OWNER TO postgres;

--
-- Name: personal_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.personal_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.personal_access_tokens_id_seq OWNER TO postgres;

--
-- Name: personal_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.personal_access_tokens_id_seq OWNED BY public.personal_access_tokens.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sessions (
    id character varying(255) NOT NULL,
    user_id bigint,
    ip_address character varying(45),
    user_agent text,
    payload text NOT NULL,
    last_activity integer NOT NULL
);


ALTER TABLE public.sessions OWNER TO postgres;

--
-- Name: alquiler_equipos; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.alquiler_equipos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    equipo_id uuid NOT NULL,
    persona_id uuid,
    cliente_externo_id uuid,
    fecha_entrega timestamp(0) with time zone NOT NULL,
    fecha_devolucion_esperada timestamp(0) with time zone NOT NULL,
    fecha_recepcion timestamp(0) with time zone,
    foto_salida_url character varying(500),
    foto_retorno_url character varying(500),
    observaciones text,
    precio_total numeric(10,2) NOT NULL,
    estado character varying(20) DEFAULT 'activo'::character varying NOT NULL,
    created_at timestamp(0) with time zone,
    updated_at timestamp(0) with time zone,
    CONSTRAINT alquiler_equipos_cliente_check CHECK ((num_nonnulls(persona_id, cliente_externo_id) = 1)),
    CONSTRAINT alquiler_equipos_estado_check CHECK (((estado)::text = ANY ((ARRAY['activo'::character varying, 'devuelto'::character varying, 'vencido'::character varying, 'pendiente'::character varying, 'entregado'::character varying])::text[])))
);


ALTER TABLE services.alquiler_equipos OWNER TO postgres;

--
-- Name: asignaciones_personal; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.asignaciones_personal (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid NOT NULL,
    reserva_podcast_id uuid,
    servicio_streaming_id uuid,
    servicio_produccion_id uuid,
    edicion_video_id uuid,
    rol_en_servicio character varying(100),
    CONSTRAINT chk_una_sola_asignacion CHECK ((num_nonnulls(reserva_podcast_id, servicio_streaming_id, servicio_produccion_id, edicion_video_id) = 1))
);


ALTER TABLE services.asignaciones_personal OWNER TO postgres;

--
-- Name: edicion_videos; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.edicion_videos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid,
    cliente_externo_id uuid,
    fecha_recepcion date NOT NULL,
    fecha_entrega date NOT NULL,
    descripcion text,
    precio_total numeric(10,2) NOT NULL,
    estado services.t_estado_reserva DEFAULT 'reservado'::services.t_estado_reserva,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT chk_cliente_edicion CHECK ((num_nonnulls(persona_id, cliente_externo_id) = 1))
);


ALTER TABLE services.edicion_videos OWNER TO postgres;

--
-- Name: equipos; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.equipos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombre character varying(200) NOT NULL,
    descripcion text,
    foto_url character varying(500),
    precio_diario numeric(10,2) DEFAULT '0'::numeric NOT NULL,
    estado character varying(20) DEFAULT 'disponible'::character varying NOT NULL,
    created_at timestamp(0) with time zone,
    updated_at timestamp(0) with time zone,
    CONSTRAINT equipos_estado_check CHECK (((estado)::text = ANY ((ARRAY['disponible'::character varying, 'alquilado'::character varying, 'mantenimiento'::character varying])::text[])))
);


ALTER TABLE services.equipos OWNER TO postgres;

--
-- Name: items_paquete_podcast; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.items_paquete_podcast (
    id integer NOT NULL,
    paquete_id integer NOT NULL,
    descripcion character varying(200) NOT NULL
);


ALTER TABLE services.items_paquete_podcast OWNER TO postgres;

--
-- Name: items_paquete_podcast_id_seq; Type: SEQUENCE; Schema: services; Owner: postgres
--

CREATE SEQUENCE services.items_paquete_podcast_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE services.items_paquete_podcast_id_seq OWNER TO postgres;

--
-- Name: items_paquete_podcast_id_seq; Type: SEQUENCE OWNED BY; Schema: services; Owner: postgres
--

ALTER SEQUENCE services.items_paquete_podcast_id_seq OWNED BY services.items_paquete_podcast.id;


--
-- Name: paquetes_podcast_id_seq; Type: SEQUENCE; Schema: services; Owner: postgres
--

CREATE SEQUENCE services.paquetes_podcast_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE services.paquetes_podcast_id_seq OWNER TO postgres;

--
-- Name: paquetes_podcast_id_seq; Type: SEQUENCE OWNED BY; Schema: services; Owner: postgres
--

ALTER SEQUENCE services.paquetes_podcast_id_seq OWNED BY services.paquetes_podcast.id;


--
-- Name: servicios_produccion; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.servicios_produccion (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    persona_id uuid,
    cliente_externo_id uuid,
    fecha_evento date NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    lugar character varying(300) NOT NULL,
    descripcion text,
    precio_total numeric(10,2) NOT NULL,
    estado services.t_estado_reserva DEFAULT 'reservado'::services.t_estado_reserva,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT chk_cliente_produccion CHECK ((num_nonnulls(persona_id, cliente_externo_id) = 1))
);


ALTER TABLE services.servicios_produccion OWNER TO postgres;

--
-- Name: trabajos_edicion; Type: TABLE; Schema: services; Owner: postgres
--

CREATE TABLE services.trabajos_edicion (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    titulo character varying(300) NOT NULL,
    descripcion text,
    fecha_recibo date NOT NULL,
    fecha_limite date NOT NULL,
    fecha_entrega date,
    nivel character varying(20) DEFAULT 'basica'::character varying NOT NULL,
    estado character varying(20) DEFAULT 'recibido'::character varying NOT NULL,
    editor_ids jsonb DEFAULT '[]'::jsonb NOT NULL,
    reserva_podcast_id uuid,
    precio_cobrado numeric(10,2),
    cobro_registrado boolean DEFAULT false NOT NULL,
    notas text,
    created_at timestamp(0) with time zone,
    updated_at timestamp(0) with time zone,
    CONSTRAINT trabajos_edicion_estado_check CHECK (((estado)::text = ANY ((ARRAY['recibido'::character varying, 'en_proceso'::character varying, 'revision'::character varying, 'entregado'::character varying])::text[]))),
    CONSTRAINT trabajos_edicion_nivel_check CHECK (((nivel)::text = ANY ((ARRAY['basica'::character varying, 'estandar'::character varying, 'premium'::character varying])::text[])))
);


ALTER TABLE services.trabajos_edicion OWNER TO postgres;

--
-- Name: horarios_dias id; Type: DEFAULT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.horarios_dias ALTER COLUMN id SET DEFAULT nextval('academic.horarios_dias_id_seq'::regclass);


--
-- Name: ciudades id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.ciudades ALTER COLUMN id SET DEFAULT nextval('core.ciudades_id_seq'::regclass);


--
-- Name: failed_jobs id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.failed_jobs ALTER COLUMN id SET DEFAULT nextval('core.failed_jobs_id_seq'::regclass);


--
-- Name: jobs id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.jobs ALTER COLUMN id SET DEFAULT nextval('core.jobs_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.migrations ALTER COLUMN id SET DEFAULT nextval('core.migrations_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.permissions ALTER COLUMN id SET DEFAULT nextval('core.permissions_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.roles ALTER COLUMN id SET DEFAULT nextval('core.roles_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.users ALTER COLUMN id SET DEFAULT nextval('core.users_id_seq'::regclass);


--
-- Name: categorias_egreso id; Type: DEFAULT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.categorias_egreso ALTER COLUMN id SET DEFAULT nextval('finance.categorias_egreso_id_seq'::regclass);


--
-- Name: failed_jobs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.failed_jobs ALTER COLUMN id SET DEFAULT nextval('public.failed_jobs_id_seq'::regclass);


--
-- Name: jobs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs ALTER COLUMN id SET DEFAULT nextval('public.jobs_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: personal_access_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.personal_access_tokens_id_seq'::regclass);


--
-- Name: items_paquete_podcast id; Type: DEFAULT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.items_paquete_podcast ALTER COLUMN id SET DEFAULT nextval('services.items_paquete_podcast_id_seq'::regclass);


--
-- Name: paquetes_podcast id; Type: DEFAULT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.paquetes_podcast ALTER COLUMN id SET DEFAULT nextval('services.paquetes_podcast_id_seq'::regclass);


--
-- Name: horarios_dias academic_horarios_dias_horario_id_dia_semana_unique; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.horarios_dias
    ADD CONSTRAINT academic_horarios_dias_horario_id_dia_semana_unique UNIQUE (horario_id, dia_semana);


--
-- Name: asesorias asesorias_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.asesorias
    ADD CONSTRAINT asesorias_pkey PRIMARY KEY (id);


--
-- Name: asistencias asistencias_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.asistencias
    ADD CONSTRAINT asistencias_pkey PRIMARY KEY (id);


--
-- Name: cambios_horario cambios_horario_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cambios_horario
    ADD CONSTRAINT cambios_horario_pkey PRIMARY KEY (id);


--
-- Name: catalogo_cursos catalogo_cursos_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.catalogo_cursos
    ADD CONSTRAINT catalogo_cursos_pkey PRIMARY KEY (id);


--
-- Name: certificados certificados_codigo_certificado_key; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.certificados
    ADD CONSTRAINT certificados_codigo_certificado_key UNIQUE (codigo_certificado);


--
-- Name: certificados certificados_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.certificados
    ADD CONSTRAINT certificados_pkey PRIMARY KEY (id);


--
-- Name: clases_extras clases_extras_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.clases_extras
    ADD CONSTRAINT clases_extras_pkey PRIMARY KEY (id);


--
-- Name: clases clases_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.clases
    ADD CONSTRAINT clases_pkey PRIMARY KEY (id);


--
-- Name: comentarios_curso comentarios_curso_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.comentarios_curso
    ADD CONSTRAINT comentarios_curso_pkey PRIMARY KEY (id);


--
-- Name: cursos_abiertos cursos_abiertos_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cursos_abiertos
    ADD CONSTRAINT cursos_abiertos_pkey PRIMARY KEY (id);


--
-- Name: horarios_dias horarios_dias_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.horarios_dias
    ADD CONSTRAINT horarios_dias_pkey PRIMARY KEY (id);


--
-- Name: horarios horarios_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.horarios
    ADD CONSTRAINT horarios_pkey PRIMARY KEY (id);


--
-- Name: inscripciones_taller inscripciones_taller_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.inscripciones_taller
    ADD CONSTRAINT inscripciones_taller_pkey PRIMARY KEY (id);


--
-- Name: matriculas matriculas_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.matriculas
    ADD CONSTRAINT matriculas_pkey PRIMARY KEY (id);


--
-- Name: modulos modulos_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.modulos
    ADD CONSTRAINT modulos_pkey PRIMARY KEY (id);


--
-- Name: notas notas_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.notas
    ADD CONSTRAINT notas_pkey PRIMARY KEY (id);


--
-- Name: solicitudes_inscripcion solicitudes_inscripcion_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.solicitudes_inscripcion
    ADD CONSTRAINT solicitudes_inscripcion_pkey PRIMARY KEY (id);


--
-- Name: talleres talleres_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.talleres
    ADD CONSTRAINT talleres_pkey PRIMARY KEY (id);


--
-- Name: traslados_modulo traslados_modulo_pkey; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.traslados_modulo
    ADD CONSTRAINT traslados_modulo_pkey PRIMARY KEY (id);


--
-- Name: asistencias uq_asistencia; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.asistencias
    ADD CONSTRAINT uq_asistencia UNIQUE (matricula_id, clase_id);


--
-- Name: matriculas uq_estudiante_curso; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.matriculas
    ADD CONSTRAINT uq_estudiante_curso UNIQUE (estudiante_id, curso_abierto_id);


--
-- Name: notas uq_nota_modulo; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.notas
    ADD CONSTRAINT uq_nota_modulo UNIQUE (matricula_id, modulo_id);


--
-- Name: inscripciones_taller uq_persona_taller; Type: CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.inscripciones_taller
    ADD CONSTRAINT uq_persona_taller UNIQUE (taller_id, persona_id);


--
-- Name: eventos_financieros eventos_financieros_pkey; Type: CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.eventos_financieros
    ADD CONSTRAINT eventos_financieros_pkey PRIMARY KEY (id);


--
-- Name: inicios_sesion inicios_sesion_pkey; Type: CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.inicios_sesion
    ADD CONSTRAINT inicios_sesion_pkey PRIMARY KEY (id);


--
-- Name: cache_locks cache_locks_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.cache_locks
    ADD CONSTRAINT cache_locks_pkey PRIMARY KEY (key);


--
-- Name: cache cache_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.cache
    ADD CONSTRAINT cache_pkey PRIMARY KEY (key);


--
-- Name: ciudades ciudades_nombre_key; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.ciudades
    ADD CONSTRAINT ciudades_nombre_key UNIQUE (nombre);


--
-- Name: ciudades ciudades_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.ciudades
    ADD CONSTRAINT ciudades_pkey PRIMARY KEY (id);


--
-- Name: permissions core_permissions_name_guard_name_unique; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.permissions
    ADD CONSTRAINT core_permissions_name_guard_name_unique UNIQUE (name, guard_name);


--
-- Name: roles core_roles_name_guard_name_unique; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.roles
    ADD CONSTRAINT core_roles_name_guard_name_unique UNIQUE (name, guard_name);


--
-- Name: estudiante_segmentos estudiante_segmentos_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.estudiante_segmentos
    ADD CONSTRAINT estudiante_segmentos_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.failed_jobs
    ADD CONSTRAINT failed_jobs_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_uuid_unique; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.failed_jobs
    ADD CONSTRAINT failed_jobs_uuid_unique UNIQUE (uuid);


--
-- Name: job_batches job_batches_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.job_batches
    ADD CONSTRAINT job_batches_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: model_has_permissions model_has_permissions_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.model_has_permissions
    ADD CONSTRAINT model_has_permissions_pkey PRIMARY KEY (permission_id, model_id, model_type);


--
-- Name: model_has_roles model_has_roles_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.model_has_roles
    ADD CONSTRAINT model_has_roles_pkey PRIMARY KEY (role_id, model_id, model_type);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (email);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: role_has_permissions role_has_permissions_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.role_has_permissions
    ADD CONSTRAINT role_has_permissions_pkey PRIMARY KEY (permission_id, role_id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_email_unique; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT users_email_unique UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: categorias_egreso categorias_egreso_nombre_key; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.categorias_egreso
    ADD CONSTRAINT categorias_egreso_nombre_key UNIQUE (nombre);


--
-- Name: categorias_egreso categorias_egreso_pkey; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.categorias_egreso
    ADD CONSTRAINT categorias_egreso_pkey PRIMARY KEY (id);


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_pkey; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_pkey PRIMARY KEY (id);


--
-- Name: horas_instructor horas_instructor_pkey; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.horas_instructor
    ADD CONSTRAINT horas_instructor_pkey PRIMARY KEY (id);


--
-- Name: resumen_caja resumen_caja_pkey; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.resumen_caja
    ADD CONSTRAINT resumen_caja_pkey PRIMARY KEY (id);


--
-- Name: transacciones_egreso transacciones_egreso_pkey; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.transacciones_egreso
    ADD CONSTRAINT transacciones_egreso_pkey PRIMARY KEY (id);


--
-- Name: transacciones_ingreso transacciones_ingreso_pkey; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.transacciones_ingreso
    ADD CONSTRAINT transacciones_ingreso_pkey PRIMARY KEY (id);


--
-- Name: registro_asistencia_staff registro_asistencia_staff_pkey; Type: CONSTRAINT; Schema: ops; Owner: postgres
--

ALTER TABLE ONLY ops.registro_asistencia_staff
    ADD CONSTRAINT registro_asistencia_staff_pkey PRIMARY KEY (id);


--
-- Name: registro_asistencia_staff uq_staff_dia; Type: CONSTRAINT; Schema: ops; Owner: postgres
--

ALTER TABLE ONLY ops.registro_asistencia_staff
    ADD CONSTRAINT uq_staff_dia UNIQUE (persona_id, fecha);


--
-- Name: clientes_externos clientes_externos_pkey; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.clientes_externos
    ADD CONSTRAINT clientes_externos_pkey PRIMARY KEY (id);


--
-- Name: cuentas_sistema cuentas_sistema_persona_id_key; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.cuentas_sistema
    ADD CONSTRAINT cuentas_sistema_persona_id_key UNIQUE (persona_id);


--
-- Name: cuentas_sistema cuentas_sistema_pkey; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.cuentas_sistema
    ADD CONSTRAINT cuentas_sistema_pkey PRIMARY KEY (id);


--
-- Name: cuentas_sistema cuentas_sistema_username_key; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.cuentas_sistema
    ADD CONSTRAINT cuentas_sistema_username_key UNIQUE (username);


--
-- Name: perfil_estudiante perfil_estudiante_persona_id_key; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.perfil_estudiante
    ADD CONSTRAINT perfil_estudiante_persona_id_key UNIQUE (persona_id);


--
-- Name: perfil_estudiante perfil_estudiante_pkey; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.perfil_estudiante
    ADD CONSTRAINT perfil_estudiante_pkey PRIMARY KEY (id);


--
-- Name: perfil_instructor perfil_instructor_persona_id_key; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.perfil_instructor
    ADD CONSTRAINT perfil_instructor_persona_id_key UNIQUE (persona_id);


--
-- Name: perfil_instructor perfil_instructor_pkey; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.perfil_instructor
    ADD CONSTRAINT perfil_instructor_pkey PRIMARY KEY (id);


--
-- Name: perfil_staff perfil_staff_persona_id_key; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.perfil_staff
    ADD CONSTRAINT perfil_staff_persona_id_key UNIQUE (persona_id);


--
-- Name: perfil_staff perfil_staff_pkey; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.perfil_staff
    ADD CONSTRAINT perfil_staff_pkey PRIMARY KEY (id);


--
-- Name: personas personas_cedula_key; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.personas
    ADD CONSTRAINT personas_cedula_key UNIQUE (cedula);


--
-- Name: personas personas_pkey; Type: CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.personas
    ADD CONSTRAINT personas_pkey PRIMARY KEY (id);


--
-- Name: cache_locks cache_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cache_locks
    ADD CONSTRAINT cache_locks_pkey PRIMARY KEY (key);


--
-- Name: cache cache_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cache
    ADD CONSTRAINT cache_pkey PRIMARY KEY (key);


--
-- Name: failed_jobs failed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_uuid_key UNIQUE (uuid);


--
-- Name: job_batches job_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_batches
    ADD CONSTRAINT job_batches_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: personal_access_tokens personal_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: personal_access_tokens personal_access_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_token_key UNIQUE (token);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: alquiler_equipos alquiler_equipos_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.alquiler_equipos
    ADD CONSTRAINT alquiler_equipos_pkey PRIMARY KEY (id);


--
-- Name: asignaciones_personal asignaciones_personal_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.asignaciones_personal
    ADD CONSTRAINT asignaciones_personal_pkey PRIMARY KEY (id);


--
-- Name: aulas aulas_nombre_key; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.aulas
    ADD CONSTRAINT aulas_nombre_key UNIQUE (nombre);


--
-- Name: aulas aulas_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.aulas
    ADD CONSTRAINT aulas_pkey PRIMARY KEY (id);


--
-- Name: edicion_videos edicion_videos_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.edicion_videos
    ADD CONSTRAINT edicion_videos_pkey PRIMARY KEY (id);


--
-- Name: equipos equipos_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.equipos
    ADD CONSTRAINT equipos_pkey PRIMARY KEY (id);


--
-- Name: items_paquete_podcast items_paquete_podcast_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.items_paquete_podcast
    ADD CONSTRAINT items_paquete_podcast_pkey PRIMARY KEY (id);


--
-- Name: paquetes_podcast paquetes_podcast_nombre_key; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.paquetes_podcast
    ADD CONSTRAINT paquetes_podcast_nombre_key UNIQUE (nombre);


--
-- Name: paquetes_podcast paquetes_podcast_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.paquetes_podcast
    ADD CONSTRAINT paquetes_podcast_pkey PRIMARY KEY (id);


--
-- Name: reservas_aulas reservas_aulas_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.reservas_aulas
    ADD CONSTRAINT reservas_aulas_pkey PRIMARY KEY (id);


--
-- Name: reservas_podcast reservas_podcast_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.reservas_podcast
    ADD CONSTRAINT reservas_podcast_pkey PRIMARY KEY (id);


--
-- Name: servicios_produccion servicios_produccion_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.servicios_produccion
    ADD CONSTRAINT servicios_produccion_pkey PRIMARY KEY (id);


--
-- Name: servicios_streaming servicios_streaming_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.servicios_streaming
    ADD CONSTRAINT servicios_streaming_pkey PRIMARY KEY (id);


--
-- Name: trabajos_edicion trabajos_edicion_pkey; Type: CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.trabajos_edicion
    ADD CONSTRAINT trabajos_edicion_pkey PRIMARY KEY (id);


--
-- Name: academic_certificados_cedula_impresa_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_certificados_cedula_impresa_index ON academic.certificados USING btree (cedula_impresa);


--
-- Name: academic_certificados_estado_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_certificados_estado_index ON academic.certificados USING btree (estado);


--
-- Name: academic_horarios_dias_dia_semana_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_horarios_dias_dia_semana_index ON academic.horarios_dias USING btree (dia_semana);


--
-- Name: academic_horarios_dias_horario_id_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_horarios_dias_horario_id_index ON academic.horarios_dias USING btree (horario_id);


--
-- Name: academic_solicitudes_inscripcion_created_at_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_solicitudes_inscripcion_created_at_index ON academic.solicitudes_inscripcion USING btree (created_at);


--
-- Name: academic_solicitudes_inscripcion_curso_abierto_id_estado_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_solicitudes_inscripcion_curso_abierto_id_estado_index ON academic.solicitudes_inscripcion USING btree (curso_abierto_id, estado);


--
-- Name: academic_solicitudes_inscripcion_curso_abierto_id_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_solicitudes_inscripcion_curso_abierto_id_index ON academic.solicitudes_inscripcion USING btree (curso_abierto_id);


--
-- Name: academic_solicitudes_inscripcion_estado_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_solicitudes_inscripcion_estado_index ON academic.solicitudes_inscripcion USING btree (estado);


--
-- Name: academic_solicitudes_inscripcion_persona_id_estado_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_solicitudes_inscripcion_persona_id_estado_index ON academic.solicitudes_inscripcion USING btree (persona_id, estado);


--
-- Name: academic_solicitudes_inscripcion_persona_id_index; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX academic_solicitudes_inscripcion_persona_id_index ON academic.solicitudes_inscripcion USING btree (persona_id);


--
-- Name: idx_asistencias_clase; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX idx_asistencias_clase ON academic.asistencias USING btree (clase_id);


--
-- Name: idx_clases_fecha; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX idx_clases_fecha ON academic.clases USING btree (fecha_clase);


--
-- Name: idx_cursos_abiertos_resumen; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX idx_cursos_abiertos_resumen ON academic.cursos_abiertos USING btree (estudiantes_inscritos, ingreso_proyectado);


--
-- Name: idx_cursos_estado; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX idx_cursos_estado ON academic.cursos_abiertos USING btree (estado) WHERE (deleted_at IS NULL);


--
-- Name: idx_matriculas_curso; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX idx_matriculas_curso ON academic.matriculas USING btree (curso_abierto_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_matriculas_estudiante; Type: INDEX; Schema: academic; Owner: postgres
--

CREATE INDEX idx_matriculas_estudiante ON academic.matriculas USING btree (estudiante_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_audit_eventos_financieros_fecha; Type: INDEX; Schema: audit; Owner: postgres
--

CREATE INDEX idx_audit_eventos_financieros_fecha ON audit.eventos_financieros USING btree (fecha_evento DESC);


--
-- Name: idx_audit_inicios_sesion_fecha; Type: INDEX; Schema: audit; Owner: postgres
--

CREATE INDEX idx_audit_inicios_sesion_fecha ON audit.inicios_sesion USING btree (fecha_inicio DESC);


--
-- Name: cache_expiration_index; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX cache_expiration_index ON core.cache USING btree (expiration);


--
-- Name: cache_locks_expiration_index; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX cache_locks_expiration_index ON core.cache_locks USING btree (expiration);


--
-- Name: failed_jobs_connection_queue_failed_at_index; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX failed_jobs_connection_queue_failed_at_index ON core.failed_jobs USING btree (connection, queue, failed_at);


--
-- Name: jobs_queue_index; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX jobs_queue_index ON core.jobs USING btree (queue);


--
-- Name: model_has_permissions_model_id_model_type_index; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX model_has_permissions_model_id_model_type_index ON core.model_has_permissions USING btree (model_id, model_type);


--
-- Name: model_has_roles_model_id_model_type_index; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX model_has_roles_model_id_model_type_index ON core.model_has_roles USING btree (model_id, model_type);


--
-- Name: sessions_last_activity_index; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX sessions_last_activity_index ON core.sessions USING btree (last_activity);


--
-- Name: sessions_user_id_index; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX sessions_user_id_index ON core.sessions USING btree (user_id);


--
-- Name: idx_cpc_matricula; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_cpc_matricula ON finance.cuentas_por_cobrar USING btree (matricula_id) WHERE (matricula_id IS NOT NULL);


--
-- Name: idx_cpc_produccion; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_cpc_produccion ON finance.cuentas_por_cobrar USING btree (servicio_produccion_id) WHERE (servicio_produccion_id IS NOT NULL);


--
-- Name: idx_cpc_reserva_aula; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_cpc_reserva_aula ON finance.cuentas_por_cobrar USING btree (reserva_aula_id) WHERE (reserva_aula_id IS NOT NULL);


--
-- Name: idx_cpc_reserva_podcast; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_cpc_reserva_podcast ON finance.cuentas_por_cobrar USING btree (reserva_podcast_id) WHERE (reserva_podcast_id IS NOT NULL);


--
-- Name: idx_cpc_streaming; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_cpc_streaming ON finance.cuentas_por_cobrar USING btree (servicio_streaming_id) WHERE (servicio_streaming_id IS NOT NULL);


--
-- Name: idx_egresos_fecha; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_egresos_fecha ON finance.transacciones_egreso USING btree (fecha_pago DESC);


--
-- Name: idx_horas_instructor_pago; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_horas_instructor_pago ON finance.horas_instructor USING btree (instructor_id, pagado);


--
-- Name: idx_ingresos_fecha; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_ingresos_fecha ON finance.transacciones_ingreso USING btree (fecha_pago DESC);


--
-- Name: idx_staff_asistencia_fecha; Type: INDEX; Schema: ops; Owner: postgres
--

CREATE INDEX idx_staff_asistencia_fecha ON ops.registro_asistencia_staff USING btree (persona_id, fecha);


--
-- Name: idx_clientes_externos_apellidos; Type: INDEX; Schema: people; Owner: postgres
--

CREATE INDEX idx_clientes_externos_apellidos ON people.clientes_externos USING gin (apellidos public.gin_trgm_ops);


--
-- Name: idx_clientes_externos_cedula; Type: INDEX; Schema: people; Owner: postgres
--

CREATE INDEX idx_clientes_externos_cedula ON people.clientes_externos USING btree (cedula);


--
-- Name: idx_clientes_externos_nombres; Type: INDEX; Schema: people; Owner: postgres
--

CREATE INDEX idx_clientes_externos_nombres ON people.clientes_externos USING gin (nombres public.gin_trgm_ops);


--
-- Name: idx_personas_apellidos_trgm; Type: INDEX; Schema: people; Owner: postgres
--

CREATE INDEX idx_personas_apellidos_trgm ON people.personas USING gin (apellidos public.gin_trgm_ops);


--
-- Name: idx_personas_cedula; Type: INDEX; Schema: people; Owner: postgres
--

CREATE INDEX idx_personas_cedula ON people.personas USING btree (cedula) WHERE (deleted_at IS NULL);


--
-- Name: idx_personas_nombres_trgm; Type: INDEX; Schema: people; Owner: postgres
--

CREATE INDEX idx_personas_nombres_trgm ON people.personas USING gin (nombres public.gin_trgm_ops);


--
-- Name: idx_personas_tipo; Type: INDEX; Schema: people; Owner: postgres
--

CREATE INDEX idx_personas_tipo ON people.personas USING btree (tipo) WHERE (deleted_at IS NULL);


--
-- Name: services_alquiler_equipos_equipo_id_index; Type: INDEX; Schema: services; Owner: postgres
--

CREATE INDEX services_alquiler_equipos_equipo_id_index ON services.alquiler_equipos USING btree (equipo_id);


--
-- Name: services_alquiler_equipos_estado_index; Type: INDEX; Schema: services; Owner: postgres
--

CREATE INDEX services_alquiler_equipos_estado_index ON services.alquiler_equipos USING btree (estado);


--
-- Name: services_trabajos_edicion_estado_index; Type: INDEX; Schema: services; Owner: postgres
--

CREATE INDEX services_trabajos_edicion_estado_index ON services.trabajos_edicion USING btree (estado);


--
-- Name: services_trabajos_edicion_fecha_limite_index; Type: INDEX; Schema: services; Owner: postgres
--

CREATE INDEX services_trabajos_edicion_fecha_limite_index ON services.trabajos_edicion USING btree (fecha_limite);


--
-- Name: services_trabajos_edicion_fecha_recibo_index; Type: INDEX; Schema: services; Owner: postgres
--

CREATE INDEX services_trabajos_edicion_fecha_recibo_index ON services.trabajos_edicion USING btree (fecha_recibo);


--
-- Name: matriculas trg_actualizar_perfil_estudiante; Type: TRIGGER; Schema: academic; Owner: postgres
--

CREATE TRIGGER trg_actualizar_perfil_estudiante AFTER INSERT OR UPDATE ON academic.matriculas FOR EACH ROW EXECUTE FUNCTION academic.fn_actualizar_perfil_estudiante();

ALTER TABLE academic.matriculas DISABLE TRIGGER trg_actualizar_perfil_estudiante;


--
-- Name: matriculas trg_actualizar_resumen_curso; Type: TRIGGER; Schema: academic; Owner: postgres
--

CREATE TRIGGER trg_actualizar_resumen_curso AFTER INSERT OR DELETE OR UPDATE ON academic.matriculas FOR EACH ROW EXECUTE FUNCTION academic.fn_actualizar_resumen_curso();

ALTER TABLE academic.matriculas DISABLE TRIGGER trg_actualizar_resumen_curso;


--
-- Name: transacciones_ingreso trg_actualizar_saldo; Type: TRIGGER; Schema: finance; Owner: postgres
--

CREATE TRIGGER trg_actualizar_saldo AFTER INSERT OR DELETE OR UPDATE ON finance.transacciones_ingreso FOR EACH ROW EXECUTE FUNCTION finance.fn_actualizar_cuenta_cobrar();


--
-- Name: transacciones_egreso trg_resumen_caja_egreso; Type: TRIGGER; Schema: finance; Owner: postgres
--

CREATE TRIGGER trg_resumen_caja_egreso AFTER INSERT OR DELETE OR UPDATE ON finance.transacciones_egreso FOR EACH ROW EXECUTE FUNCTION finance.fn_registrar_movimiento_caja();


--
-- Name: transacciones_ingreso trg_resumen_caja_ingreso; Type: TRIGGER; Schema: finance; Owner: postgres
--

CREATE TRIGGER trg_resumen_caja_ingreso AFTER INSERT OR DELETE OR UPDATE ON finance.transacciones_ingreso FOR EACH ROW EXECUTE FUNCTION finance.fn_registrar_movimiento_caja();


--
-- Name: personas trg_personas_updated_at; Type: TRIGGER; Schema: people; Owner: postgres
--

CREATE TRIGGER trg_personas_updated_at BEFORE UPDATE ON people.personas FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();


--
-- Name: matriculas academic_matriculas_solicitud_inscripcion_id_foreign; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.matriculas
    ADD CONSTRAINT academic_matriculas_solicitud_inscripcion_id_foreign FOREIGN KEY (solicitud_inscripcion_id) REFERENCES academic.solicitudes_inscripcion(id) ON DELETE SET NULL;


--
-- Name: solicitudes_inscripcion academic_solicitudes_inscripcion_curso_abierto_id_foreign; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.solicitudes_inscripcion
    ADD CONSTRAINT academic_solicitudes_inscripcion_curso_abierto_id_foreign FOREIGN KEY (curso_abierto_id) REFERENCES academic.cursos_abiertos(id) ON DELETE CASCADE;


--
-- Name: solicitudes_inscripcion academic_solicitudes_inscripcion_participante_externo_id_foreig; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.solicitudes_inscripcion
    ADD CONSTRAINT academic_solicitudes_inscripcion_participante_externo_id_foreig FOREIGN KEY (participante_externo_id) REFERENCES people.clientes_externos(id) ON DELETE CASCADE;


--
-- Name: solicitudes_inscripcion academic_solicitudes_inscripcion_persona_id_foreign; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.solicitudes_inscripcion
    ADD CONSTRAINT academic_solicitudes_inscripcion_persona_id_foreign FOREIGN KEY (persona_id) REFERENCES people.personas(id) ON DELETE CASCADE;


--
-- Name: solicitudes_inscripcion academic_solicitudes_inscripcion_validado_por_foreign; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.solicitudes_inscripcion
    ADD CONSTRAINT academic_solicitudes_inscripcion_validado_por_foreign FOREIGN KEY (validado_por) REFERENCES people.personas(id) ON DELETE SET NULL;


--
-- Name: asesorias asesorias_cliente_externo_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.asesorias
    ADD CONSTRAINT asesorias_cliente_externo_id_fkey FOREIGN KEY (cliente_externo_id) REFERENCES people.clientes_externos(id);


--
-- Name: asesorias asesorias_instructor_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.asesorias
    ADD CONSTRAINT asesorias_instructor_id_fkey FOREIGN KEY (instructor_id) REFERENCES people.personas(id);


--
-- Name: asesorias asesorias_persona_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.asesorias
    ADD CONSTRAINT asesorias_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: asistencias asistencias_clase_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.asistencias
    ADD CONSTRAINT asistencias_clase_id_fkey FOREIGN KEY (clase_id) REFERENCES academic.clases(id) ON DELETE CASCADE;


--
-- Name: asistencias asistencias_matricula_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.asistencias
    ADD CONSTRAINT asistencias_matricula_id_fkey FOREIGN KEY (matricula_id) REFERENCES academic.matriculas(id) ON DELETE CASCADE;


--
-- Name: cambios_horario cambios_horario_autorizado_por_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cambios_horario
    ADD CONSTRAINT cambios_horario_autorizado_por_fkey FOREIGN KEY (autorizado_por) REFERENCES people.personas(id);


--
-- Name: cambios_horario cambios_horario_curso_abierto_nuevo_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cambios_horario
    ADD CONSTRAINT cambios_horario_curso_abierto_nuevo_id_fkey FOREIGN KEY (curso_abierto_nuevo_id) REFERENCES academic.cursos_abiertos(id);


--
-- Name: cambios_horario cambios_horario_matricula_origen_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cambios_horario
    ADD CONSTRAINT cambios_horario_matricula_origen_id_fkey FOREIGN KEY (matricula_origen_id) REFERENCES academic.matriculas(id);


--
-- Name: certificados certificados_catalogo_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.certificados
    ADD CONSTRAINT certificados_catalogo_id_fkey FOREIGN KEY (catalogo_id) REFERENCES academic.catalogo_cursos(id);


--
-- Name: certificados certificados_curso_abierto_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.certificados
    ADD CONSTRAINT certificados_curso_abierto_id_fkey FOREIGN KEY (curso_abierto_id) REFERENCES academic.cursos_abiertos(id);


--
-- Name: certificados certificados_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.certificados
    ADD CONSTRAINT certificados_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES people.personas(id);


--
-- Name: certificados certificados_modulo_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.certificados
    ADD CONSTRAINT certificados_modulo_id_fkey FOREIGN KEY (modulo_id) REFERENCES academic.modulos(id);


--
-- Name: clases_extras clases_extras_curso_abierto_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.clases_extras
    ADD CONSTRAINT clases_extras_curso_abierto_id_fkey FOREIGN KEY (curso_abierto_id) REFERENCES academic.cursos_abiertos(id);


--
-- Name: clases_extras clases_extras_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.clases_extras
    ADD CONSTRAINT clases_extras_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES people.personas(id);


--
-- Name: clases_extras clases_extras_instructor_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.clases_extras
    ADD CONSTRAINT clases_extras_instructor_id_fkey FOREIGN KEY (instructor_id) REFERENCES people.personas(id);


--
-- Name: clases clases_instructor_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.clases
    ADD CONSTRAINT clases_instructor_id_fkey FOREIGN KEY (instructor_id) REFERENCES people.personas(id);


--
-- Name: clases clases_modulo_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.clases
    ADD CONSTRAINT clases_modulo_id_fkey FOREIGN KEY (modulo_id) REFERENCES academic.modulos(id) ON DELETE CASCADE;


--
-- Name: comentarios_curso comentarios_curso_autor_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.comentarios_curso
    ADD CONSTRAINT comentarios_curso_autor_id_fkey FOREIGN KEY (autor_id) REFERENCES people.personas(id);


--
-- Name: comentarios_curso comentarios_curso_curso_abierto_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.comentarios_curso
    ADD CONSTRAINT comentarios_curso_curso_abierto_id_fkey FOREIGN KEY (curso_abierto_id) REFERENCES academic.cursos_abiertos(id);


--
-- Name: cursos_abiertos cursos_abiertos_catalogo_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cursos_abiertos
    ADD CONSTRAINT cursos_abiertos_catalogo_id_fkey FOREIGN KEY (catalogo_curso_id) REFERENCES academic.catalogo_cursos(id);


--
-- Name: cursos_abiertos cursos_abiertos_ciudad_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cursos_abiertos
    ADD CONSTRAINT cursos_abiertos_ciudad_id_fkey FOREIGN KEY (ciudad_id) REFERENCES core.ciudades(id);


--
-- Name: cursos_abiertos cursos_abiertos_docente_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cursos_abiertos
    ADD CONSTRAINT cursos_abiertos_docente_id_fkey FOREIGN KEY (docente_id) REFERENCES people.personas(id);


--
-- Name: cursos_abiertos cursos_abiertos_horario_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cursos_abiertos
    ADD CONSTRAINT cursos_abiertos_horario_id_fkey FOREIGN KEY (horario_id) REFERENCES academic.horarios(id);


--
-- Name: cursos_abiertos cursos_abiertos_instructor_titular_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.cursos_abiertos
    ADD CONSTRAINT cursos_abiertos_instructor_titular_id_fkey FOREIGN KEY (instructor_titular_id) REFERENCES people.personas(id);


--
-- Name: inscripciones_taller inscripciones_taller_persona_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.inscripciones_taller
    ADD CONSTRAINT inscripciones_taller_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: inscripciones_taller inscripciones_taller_taller_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.inscripciones_taller
    ADD CONSTRAINT inscripciones_taller_taller_id_fkey FOREIGN KEY (taller_id) REFERENCES academic.talleres(id);


--
-- Name: matriculas matriculas_curso_abierto_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.matriculas
    ADD CONSTRAINT matriculas_curso_abierto_id_fkey FOREIGN KEY (curso_abierto_id) REFERENCES academic.cursos_abiertos(id);


--
-- Name: matriculas matriculas_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.matriculas
    ADD CONSTRAINT matriculas_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES people.personas(id);


--
-- Name: modulos modulos_curso_abierto_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.modulos
    ADD CONSTRAINT modulos_curso_abierto_id_fkey FOREIGN KEY (curso_abierto_id) REFERENCES academic.cursos_abiertos(id) ON DELETE CASCADE;


--
-- Name: notas notas_matricula_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.notas
    ADD CONSTRAINT notas_matricula_id_fkey FOREIGN KEY (matricula_id) REFERENCES academic.matriculas(id) ON DELETE CASCADE;


--
-- Name: notas notas_modulo_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.notas
    ADD CONSTRAINT notas_modulo_id_fkey FOREIGN KEY (modulo_id) REFERENCES academic.modulos(id);


--
-- Name: talleres talleres_ciudad_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.talleres
    ADD CONSTRAINT talleres_ciudad_id_fkey FOREIGN KEY (ciudad_id) REFERENCES core.ciudades(id);


--
-- Name: talleres talleres_instructor_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.talleres
    ADD CONSTRAINT talleres_instructor_id_fkey FOREIGN KEY (instructor_id) REFERENCES people.personas(id);


--
-- Name: traslados_modulo traslados_modulo_autorizado_por_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.traslados_modulo
    ADD CONSTRAINT traslados_modulo_autorizado_por_fkey FOREIGN KEY (autorizado_por) REFERENCES people.personas(id);


--
-- Name: traslados_modulo traslados_modulo_curso_abierto_destino_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.traslados_modulo
    ADD CONSTRAINT traslados_modulo_curso_abierto_destino_id_fkey FOREIGN KEY (curso_abierto_destino_id) REFERENCES academic.cursos_abiertos(id);


--
-- Name: traslados_modulo traslados_modulo_matricula_origen_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.traslados_modulo
    ADD CONSTRAINT traslados_modulo_matricula_origen_id_fkey FOREIGN KEY (matricula_origen_id) REFERENCES academic.matriculas(id);


--
-- Name: traslados_modulo traslados_modulo_modulo_destino_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.traslados_modulo
    ADD CONSTRAINT traslados_modulo_modulo_destino_id_fkey FOREIGN KEY (modulo_destino_id) REFERENCES academic.modulos(id);


--
-- Name: traslados_modulo traslados_modulo_modulo_origen_id_fkey; Type: FK CONSTRAINT; Schema: academic; Owner: postgres
--

ALTER TABLE ONLY academic.traslados_modulo
    ADD CONSTRAINT traslados_modulo_modulo_origen_id_fkey FOREIGN KEY (modulo_origen_id) REFERENCES academic.modulos(id);


--
-- Name: eventos_financieros eventos_financieros_registrado_por_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.eventos_financieros
    ADD CONSTRAINT eventos_financieros_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES people.personas(id);


--
-- Name: eventos_financieros eventos_financieros_transaccion_egreso_id_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.eventos_financieros
    ADD CONSTRAINT eventos_financieros_transaccion_egreso_id_fkey FOREIGN KEY (transaccion_egreso_id) REFERENCES finance.transacciones_egreso(id) ON DELETE CASCADE;


--
-- Name: eventos_financieros eventos_financieros_transaccion_ingreso_id_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.eventos_financieros
    ADD CONSTRAINT eventos_financieros_transaccion_ingreso_id_fkey FOREIGN KEY (transaccion_ingreso_id) REFERENCES finance.transacciones_ingreso(id) ON DELETE CASCADE;


--
-- Name: inicios_sesion inicios_sesion_cuenta_id_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.inicios_sesion
    ADD CONSTRAINT inicios_sesion_cuenta_id_fkey FOREIGN KEY (cuenta_id) REFERENCES people.cuentas_sistema(id) ON DELETE SET NULL;


--
-- Name: inicios_sesion inicios_sesion_persona_id_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.inicios_sesion
    ADD CONSTRAINT inicios_sesion_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id) ON DELETE SET NULL;


--
-- Name: model_has_permissions core_model_has_permissions_permission_id_foreign; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.model_has_permissions
    ADD CONSTRAINT core_model_has_permissions_permission_id_foreign FOREIGN KEY (permission_id) REFERENCES core.permissions(id) ON DELETE CASCADE;


--
-- Name: model_has_roles core_model_has_roles_role_id_foreign; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.model_has_roles
    ADD CONSTRAINT core_model_has_roles_role_id_foreign FOREIGN KEY (role_id) REFERENCES core.roles(id) ON DELETE CASCADE;


--
-- Name: role_has_permissions core_role_has_permissions_permission_id_foreign; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.role_has_permissions
    ADD CONSTRAINT core_role_has_permissions_permission_id_foreign FOREIGN KEY (permission_id) REFERENCES core.permissions(id) ON DELETE CASCADE;


--
-- Name: role_has_permissions core_role_has_permissions_role_id_foreign; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.role_has_permissions
    ADD CONSTRAINT core_role_has_permissions_role_id_foreign FOREIGN KEY (role_id) REFERENCES core.roles(id) ON DELETE CASCADE;


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_asesoria_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_asesoria_id_fkey FOREIGN KEY (asesoria_id) REFERENCES academic.asesorias(id);


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_clase_extra_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_clase_extra_id_fkey FOREIGN KEY (clase_extra_id) REFERENCES academic.clases_extras(id);


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_edicion_video_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_edicion_video_id_fkey FOREIGN KEY (edicion_video_id) REFERENCES services.edicion_videos(id);


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_inscripcion_taller_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_inscripcion_taller_id_fkey FOREIGN KEY (inscripcion_taller_id) REFERENCES academic.inscripciones_taller(id);


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_matricula_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_matricula_id_fkey FOREIGN KEY (matricula_id) REFERENCES academic.matriculas(id);


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_reserva_aula_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_reserva_aula_id_fkey FOREIGN KEY (reserva_aula_id) REFERENCES services.reservas_aulas(id);


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_reserva_podcast_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_reserva_podcast_id_fkey FOREIGN KEY (reserva_podcast_id) REFERENCES services.reservas_podcast(id);


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_servicio_produccion_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_servicio_produccion_id_fkey FOREIGN KEY (servicio_produccion_id) REFERENCES services.servicios_produccion(id);


--
-- Name: cuentas_por_cobrar cuentas_por_cobrar_servicio_streaming_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT cuentas_por_cobrar_servicio_streaming_id_fkey FOREIGN KEY (servicio_streaming_id) REFERENCES services.servicios_streaming(id);


--
-- Name: cuentas_por_cobrar finance_cuentas_por_cobrar_alquiler_equipo_id_foreign; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT finance_cuentas_por_cobrar_alquiler_equipo_id_foreign FOREIGN KEY (alquiler_equipo_id) REFERENCES services.alquiler_equipos(id) ON DELETE SET NULL;


--
-- Name: cuentas_por_cobrar finance_cuentas_por_cobrar_solicitud_inscripcion_id_foreign; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.cuentas_por_cobrar
    ADD CONSTRAINT finance_cuentas_por_cobrar_solicitud_inscripcion_id_foreign FOREIGN KEY (solicitud_inscripcion_id) REFERENCES academic.solicitudes_inscripcion(id) ON DELETE SET NULL;


--
-- Name: horas_instructor horas_instructor_clase_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.horas_instructor
    ADD CONSTRAINT horas_instructor_clase_id_fkey FOREIGN KEY (clase_id) REFERENCES academic.clases(id);


--
-- Name: horas_instructor horas_instructor_curso_abierto_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.horas_instructor
    ADD CONSTRAINT horas_instructor_curso_abierto_id_fkey FOREIGN KEY (curso_abierto_id) REFERENCES academic.cursos_abiertos(id);


--
-- Name: horas_instructor horas_instructor_egreso_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.horas_instructor
    ADD CONSTRAINT horas_instructor_egreso_id_fkey FOREIGN KEY (egreso_id) REFERENCES finance.transacciones_egreso(id);


--
-- Name: horas_instructor horas_instructor_instructor_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.horas_instructor
    ADD CONSTRAINT horas_instructor_instructor_id_fkey FOREIGN KEY (instructor_id) REFERENCES people.personas(id);


--
-- Name: transacciones_egreso transacciones_egreso_categoria_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.transacciones_egreso
    ADD CONSTRAINT transacciones_egreso_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES finance.categorias_egreso(id);


--
-- Name: transacciones_egreso transacciones_egreso_registrado_por_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.transacciones_egreso
    ADD CONSTRAINT transacciones_egreso_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES people.personas(id);


--
-- Name: transacciones_ingreso transacciones_ingreso_cuenta_cobrar_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.transacciones_ingreso
    ADD CONSTRAINT transacciones_ingreso_cuenta_cobrar_id_fkey FOREIGN KEY (cuenta_cobrar_id) REFERENCES finance.cuentas_por_cobrar(id) ON DELETE RESTRICT;


--
-- Name: transacciones_ingreso transacciones_ingreso_registrado_por_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.transacciones_ingreso
    ADD CONSTRAINT transacciones_ingreso_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES people.personas(id);


--
-- Name: registro_asistencia_staff registro_asistencia_staff_persona_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: postgres
--

ALTER TABLE ONLY ops.registro_asistencia_staff
    ADD CONSTRAINT registro_asistencia_staff_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: registro_asistencia_staff registro_asistencia_staff_registrado_por_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: postgres
--

ALTER TABLE ONLY ops.registro_asistencia_staff
    ADD CONSTRAINT registro_asistencia_staff_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES people.personas(id);


--
-- Name: clientes_externos clientes_externos_ciudad_id_fkey; Type: FK CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.clientes_externos
    ADD CONSTRAINT clientes_externos_ciudad_id_fkey FOREIGN KEY (ciudad_id) REFERENCES core.ciudades(id);


--
-- Name: cuentas_sistema cuentas_sistema_persona_id_fkey; Type: FK CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.cuentas_sistema
    ADD CONSTRAINT cuentas_sistema_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: perfil_estudiante perfil_estudiante_persona_id_fkey; Type: FK CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.perfil_estudiante
    ADD CONSTRAINT perfil_estudiante_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: perfil_instructor perfil_instructor_persona_id_fkey; Type: FK CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.perfil_instructor
    ADD CONSTRAINT perfil_instructor_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: perfil_staff perfil_staff_persona_id_fkey; Type: FK CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.perfil_staff
    ADD CONSTRAINT perfil_staff_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: personas personas_ciudad_id_fkey; Type: FK CONSTRAINT; Schema: people; Owner: postgres
--

ALTER TABLE ONLY people.personas
    ADD CONSTRAINT personas_ciudad_id_fkey FOREIGN KEY (ciudad_id) REFERENCES core.ciudades(id);


--
-- Name: asignaciones_personal asignaciones_personal_edicion_video_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.asignaciones_personal
    ADD CONSTRAINT asignaciones_personal_edicion_video_id_fkey FOREIGN KEY (edicion_video_id) REFERENCES services.edicion_videos(id);


--
-- Name: asignaciones_personal asignaciones_personal_persona_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.asignaciones_personal
    ADD CONSTRAINT asignaciones_personal_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: asignaciones_personal asignaciones_personal_reserva_podcast_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.asignaciones_personal
    ADD CONSTRAINT asignaciones_personal_reserva_podcast_id_fkey FOREIGN KEY (reserva_podcast_id) REFERENCES services.reservas_podcast(id);


--
-- Name: asignaciones_personal asignaciones_personal_servicio_produccion_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.asignaciones_personal
    ADD CONSTRAINT asignaciones_personal_servicio_produccion_id_fkey FOREIGN KEY (servicio_produccion_id) REFERENCES services.servicios_produccion(id);


--
-- Name: asignaciones_personal asignaciones_personal_servicio_streaming_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.asignaciones_personal
    ADD CONSTRAINT asignaciones_personal_servicio_streaming_id_fkey FOREIGN KEY (servicio_streaming_id) REFERENCES services.servicios_streaming(id);


--
-- Name: edicion_videos edicion_videos_cliente_externo_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.edicion_videos
    ADD CONSTRAINT edicion_videos_cliente_externo_id_fkey FOREIGN KEY (cliente_externo_id) REFERENCES people.clientes_externos(id);


--
-- Name: edicion_videos edicion_videos_persona_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.edicion_videos
    ADD CONSTRAINT edicion_videos_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: items_paquete_podcast items_paquete_podcast_paquete_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.items_paquete_podcast
    ADD CONSTRAINT items_paquete_podcast_paquete_id_fkey FOREIGN KEY (paquete_id) REFERENCES services.paquetes_podcast(id);


--
-- Name: reservas_aulas reservas_aulas_aula_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.reservas_aulas
    ADD CONSTRAINT reservas_aulas_aula_id_fkey FOREIGN KEY (aula_id) REFERENCES services.aulas(id);


--
-- Name: reservas_aulas reservas_aulas_cliente_externo_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.reservas_aulas
    ADD CONSTRAINT reservas_aulas_cliente_externo_id_fkey FOREIGN KEY (cliente_externo_id) REFERENCES people.clientes_externos(id);


--
-- Name: reservas_aulas reservas_aulas_persona_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.reservas_aulas
    ADD CONSTRAINT reservas_aulas_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: reservas_podcast reservas_podcast_cliente_externo_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.reservas_podcast
    ADD CONSTRAINT reservas_podcast_cliente_externo_id_fkey FOREIGN KEY (cliente_externo_id) REFERENCES people.clientes_externos(id);


--
-- Name: reservas_podcast reservas_podcast_paquete_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.reservas_podcast
    ADD CONSTRAINT reservas_podcast_paquete_id_fkey FOREIGN KEY (paquete_id) REFERENCES services.paquetes_podcast(id);


--
-- Name: reservas_podcast reservas_podcast_persona_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.reservas_podcast
    ADD CONSTRAINT reservas_podcast_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: alquiler_equipos services_alquiler_equipos_cliente_externo_id_foreign; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.alquiler_equipos
    ADD CONSTRAINT services_alquiler_equipos_cliente_externo_id_foreign FOREIGN KEY (cliente_externo_id) REFERENCES people.clientes_externos(id) ON DELETE SET NULL;


--
-- Name: alquiler_equipos services_alquiler_equipos_equipo_id_foreign; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.alquiler_equipos
    ADD CONSTRAINT services_alquiler_equipos_equipo_id_foreign FOREIGN KEY (equipo_id) REFERENCES services.equipos(id);


--
-- Name: alquiler_equipos services_alquiler_equipos_persona_id_foreign; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.alquiler_equipos
    ADD CONSTRAINT services_alquiler_equipos_persona_id_foreign FOREIGN KEY (persona_id) REFERENCES people.personas(id) ON DELETE SET NULL;


--
-- Name: trabajos_edicion services_trabajos_edicion_reserva_podcast_id_foreign; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.trabajos_edicion
    ADD CONSTRAINT services_trabajos_edicion_reserva_podcast_id_foreign FOREIGN KEY (reserva_podcast_id) REFERENCES services.reservas_podcast(id) ON DELETE SET NULL;


--
-- Name: servicios_produccion servicios_produccion_cliente_externo_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.servicios_produccion
    ADD CONSTRAINT servicios_produccion_cliente_externo_id_fkey FOREIGN KEY (cliente_externo_id) REFERENCES people.clientes_externos(id);


--
-- Name: servicios_produccion servicios_produccion_persona_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.servicios_produccion
    ADD CONSTRAINT servicios_produccion_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- Name: servicios_streaming servicios_streaming_cliente_externo_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.servicios_streaming
    ADD CONSTRAINT servicios_streaming_cliente_externo_id_fkey FOREIGN KEY (cliente_externo_id) REFERENCES people.clientes_externos(id);


--
-- Name: servicios_streaming servicios_streaming_persona_id_fkey; Type: FK CONSTRAINT; Schema: services; Owner: postgres
--

ALTER TABLE ONLY services.servicios_streaming
    ADD CONSTRAINT servicios_streaming_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES people.personas(id);


--
-- PostgreSQL database dump complete
--


