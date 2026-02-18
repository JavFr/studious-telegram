-- ============================================
-- Fontanella — Generador de volumen
-- ============================================
--
-- DO block parametrizable que genera datos masivos para benchmarking.
-- Crea organizaciones, abogados, clientes y citas NUEVAS (no toca
-- los datos del seed base).
--
-- Uso:
--   make seed-volume   (ejecuta este archivo)
--
-- Para ajustar el volumen, editar los parámetros al inicio del bloque.
-- Con los valores por defecto genera ~600 citas.
-- Con v_appt_per_lawyer=500 → ~6.000 citas.
-- Con v_orgs=10, v_lawyers=10, v_appts=1000 → ~100.000 citas.
--
-- El algoritmo empaqueta citas secuencialmente dentro de cada día
-- laborable, garantizando que NUNCA se viole el EXCLUDE USING GIST.
--

DO $$
DECLARE
    -- ══════════════════════════════════════════
    -- Parámetros (editar antes de ejecutar)
    -- ══════════════════════════════════════════
    v_orgs_count      INT  := 3;
    v_lawyers_per_org INT  := 4;
    v_clients_per_org INT  := 10;
    v_appt_per_lawyer INT  := 50;
    v_date_start      DATE := CURRENT_DATE - INTERVAL '12 months';
    v_date_end        DATE := CURRENT_DATE + INTERVAL '3 months';
    v_work_start      TIME := '09:00';
    v_work_end        TIME := '17:00';
    -- ══════════════════════════════════════════

    -- Variables internas
    v_org_id          BIGINT;
    v_user_id         BIGINT;
    v_lawyer_id       BIGINT;
    v_client_ids      BIGINT[];
    v_client_prof_ids BIGINT[];
    v_appt_type_ids   BIGINT[];
    v_appt_durations  INT[];
    v_day             DATE;
    v_cur_time        TIME;
    v_duration        INT;
    v_starts_at       TIMESTAMPTZ;
    v_ends_at         TIMESTAMPTZ;
    v_status          TEXT;
    v_type_idx        INT;
    v_client_idx      INT;
    v_appt_counter    INT;
    v_total_appts     INT := 0;
    v_temp_id         BIGINT;
    i                 INT;
    j                 INT;
    k                 INT;
BEGIN

    RAISE NOTICE '══ Fontanella: generando volumen ══';
    RAISE NOTICE 'Orgs: %, Lawyers/org: %, Clients/org: %, Appts/lawyer: %',
        v_orgs_count, v_lawyers_per_org, v_clients_per_org, v_appt_per_lawyer;

    FOR i IN 1..v_orgs_count LOOP

        -- ── Crear organización ──────────────────────────────
        INSERT INTO organizations (name, country, timezone)
        VALUES (
            'Estudio Generado ' || i,
            'Argentina',
            'UTC'
        )
        RETURNING id INTO v_org_id;

        -- ── Crear clientes para esta org ────────────────────
        v_client_ids      := ARRAY[]::BIGINT[];
        v_client_prof_ids := ARRAY[]::BIGINT[];

        FOR j IN 1..v_clients_per_org LOOP
            INSERT INTO users (email, auth_provider)
            VALUES (
                'gen.client.' || v_org_id || '.' || j || '@example.com',
                'local'
            )
            RETURNING id INTO v_user_id;

            v_client_ids := v_client_ids || v_user_id;

            INSERT INTO client_profiles
                (user_id, organization_id, first_name, last_name)
            VALUES (
                v_user_id, v_org_id,
                'Cliente', 'Gen-' || v_org_id || '-' || j
            )
            RETURNING id INTO v_temp_id;
            v_client_prof_ids[j] := v_temp_id;
        END LOOP;

        -- ── Crear tipos de cita (30, 60, 90 min) ───────────
        v_appt_type_ids := ARRAY[]::BIGINT[];
        v_appt_durations := ARRAY[30, 60, 90];

        INSERT INTO appointment_types (organization_id, name, duration_minutes, modality)
        VALUES (v_org_id, 'Consulta corta',    30, 'telefonica')
        RETURNING id INTO v_temp_id;
        v_appt_type_ids[1] := v_temp_id;

        INSERT INTO appointment_types (organization_id, name, duration_minutes, modality)
        VALUES (v_org_id, 'Consulta estándar', 60, 'presencial')
        RETURNING id INTO v_temp_id;
        v_appt_type_ids[2] := v_temp_id;

        INSERT INTO appointment_types (organization_id, name, duration_minutes, modality)
        VALUES (v_org_id, 'Consulta larga',    90, 'video')
        RETURNING id INTO v_temp_id;
        v_appt_type_ids[3] := v_temp_id;

        -- ── Crear abogados ──────────────────────────────────
        FOR j IN 1..v_lawyers_per_org LOOP

            -- Usuario
            INSERT INTO users (email, auth_provider)
            VALUES (
                'gen.lawyer.' || v_org_id || '.' || j || '@example.com',
                'local'
            )
            RETURNING id INTO v_user_id;

            -- Membresía
            INSERT INTO organization_members (user_id, organization_id, role)
            VALUES (v_user_id, v_org_id, 'lawyer');

            -- Perfil de abogado
            INSERT INTO lawyers (user_id, first_name, last_name, specialty)
            VALUES (v_user_id, 'Abogado', 'Gen-' || v_org_id || '-' || j, 'General')
            RETURNING id INTO v_lawyer_id;

            -- Vincular a todos los tipos de cita de esta org
            FOR k IN 1..3 LOOP
                INSERT INTO lawyer_appointment_types (lawyer_id, appointment_type_id)
                VALUES (v_lawyer_id, v_appt_type_ids[k]);
            END LOOP;

            -- Disponibilidad: Lun-Vie (day_of_week 1-5)
            FOR k IN 1..5 LOOP
                INSERT INTO availability_rules
                    (lawyer_id, organization_id, day_of_week,
                     start_time, end_time, timezone)
                VALUES (v_lawyer_id, v_org_id, k,
                        v_work_start, v_work_end, 'UTC');
            END LOOP;

            -- ── Generar citas ───────────────────────────────
            -- Algoritmo: recorrer días laborales, empaquetar slots
            -- secuencialmente. Cada slot empieza donde termina el
            -- anterior. tstzrange [) half-open = adyacentes no solapan.

            v_appt_counter := 0;
            v_day := v_date_start;

            <<day_loop>>
            WHILE v_day <= v_date_end AND v_appt_counter < v_appt_per_lawyer LOOP

                -- Saltar fines de semana (0=Domingo, 6=Sábado)
                IF EXTRACT(DOW FROM v_day) IN (0, 6) THEN
                    v_day := v_day + 1;
                    CONTINUE day_loop;
                END IF;

                v_cur_time := v_work_start;

                <<slot_loop>>
                WHILE v_cur_time < v_work_end AND v_appt_counter < v_appt_per_lawyer LOOP

                    -- Ciclar tipo de cita (1→2→3→1→...)
                    v_type_idx := 1 + (v_appt_counter % 3);
                    v_duration := v_appt_durations[v_type_idx];

                    -- Verificar que el slot cabe en la jornada
                    EXIT slot_loop
                        WHEN v_cur_time + (v_duration * INTERVAL '1 minute') > v_work_end;

                    -- Calcular timestamps (org usa UTC, conversión trivial)
                    v_starts_at := (v_day + v_cur_time) AT TIME ZONE 'UTC';
                    v_ends_at   := v_starts_at + (v_duration * INTERVAL '1 minute');

                    -- Asignar status con distribución realista
                    -- ~75% completed/confirmed, ~15% cancelled, ~10% no_show
                    v_status := CASE
                        WHEN v_appt_counter % 20 IN (0, 7, 14)
                            THEN 'cancelled'
                        WHEN v_appt_counter % 20 IN (3, 13)
                            THEN 'no_show'
                        WHEN v_appt_counter % 20 = 19
                            THEN 'pending'
                        WHEN v_day < CURRENT_DATE
                            THEN 'completed'
                        ELSE 'confirmed'
                    END;

                    -- Ciclar cliente (round-robin)
                    v_client_idx := 1 + (v_appt_counter % v_clients_per_org);

                    INSERT INTO appointments
                        (organization_id, lawyer_id, client_profile_id,
                         appointment_type_id, starts_at, ends_at, status)
                    VALUES (
                        v_org_id, v_lawyer_id, v_client_prof_ids[v_client_idx],
                        v_appt_type_ids[v_type_idx], v_starts_at, v_ends_at, v_status
                    );

                    v_cur_time     := v_cur_time + (v_duration * INTERVAL '1 minute');
                    v_appt_counter := v_appt_counter + 1;

                END LOOP; -- slot_loop

                v_day := v_day + 1;

            END LOOP; -- day_loop

            v_total_appts := v_total_appts + v_appt_counter;

        END LOOP; -- lawyers loop

        RAISE NOTICE 'Org % (id=%) completada', i, v_org_id;

    END LOOP; -- orgs loop

    RAISE NOTICE '══ Volumen generado: % citas totales ══', v_total_appts;

END;
$$;
