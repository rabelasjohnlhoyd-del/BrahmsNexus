-- ============================================================
-- BRAHMS SISIG & BAGNET — DUAL RFID & PRODUCTION GATE SETUP
-- I-copy at i-paste ang buong script na ito sa:
-- Supabase Dashboard -> SQL Editor -> Bagong Query -> RUN
-- ============================================================

-- 1. Table para sa Production Shift Control (Commissary Base Gate)
CREATE TABLE IF NOT EXISTS public.production_shift_control (
  date       date        PRIMARY KEY DEFAULT CURRENT_DATE,
  is_open    boolean     NOT NULL DEFAULT false,
  opened_at  timestamptz,
  closed_at  timestamptz,
  opened_by  text        DEFAULT 'admin'
);

ALTER TABLE public.production_shift_control ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Production Gate Access" ON public.production_shift_control;
CREATE POLICY "Public Production Gate Access"
  ON public.production_shift_control FOR ALL
  USING (true) WITH CHECK (true);

-- 2. Table para sa Driver Dispatch Status (Driver Route Gate)
CREATE TABLE IF NOT EXISTS public.driver_dispatch_status (
  branch_id         text PRIMARY KEY,
  branch_name       text NOT NULL DEFAULT '',
  driver_name       text NOT NULL DEFAULT 'Driver',
  cook_name         text NOT NULL DEFAULT '',
  driver_on_the_way boolean NOT NULL DEFAULT false,
  mode              text NOT NULL DEFAULT 'deployment',
  updated_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.driver_dispatch_status ADD COLUMN IF NOT EXISTS cook_name text NOT NULL DEFAULT '';
ALTER TABLE public.driver_dispatch_status ADD COLUMN IF NOT EXISTS mode text NOT NULL DEFAULT 'deployment';

ALTER TABLE public.driver_dispatch_status ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Dispatch Access" ON public.driver_dispatch_status;
CREATE POLICY "Public Dispatch Access"
  ON public.driver_dispatch_status FOR ALL
  USING (true) WITH CHECK (true);

-- 3. Table para sa RFID Scan Queue (Enrollment via Base)
CREATE TABLE IF NOT EXISTS public.rfid_scan_queue (
  id         bigserial PRIMARY KEY,
  rfid_uid   text NOT NULL,
  device_id  text NOT NULL,
  scanned_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.rfid_scan_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Scan Queue Access" ON public.rfid_scan_queue;
CREATE POLICY "Public Scan Queue Access"
  ON public.rfid_scan_queue FOR ALL
  USING (true) WITH CHECK (true);

-- 4. Central Stored Procedure: process_rfid_tap
CREATE OR REPLACE FUNCTION public.process_rfid_tap(
  p_rfid_uid  text,
  p_device_id text,
  p_branch_id text DEFAULT ''
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff          record;
  v_log            record;
  v_dispatch       public.driver_dispatch_status%ROWTYPE;
  v_dispatch_found boolean := false;
  v_full_name      text;
  v_branch_id      text;
  v_branch_name    text;
  v_clean_uid      text;
  v_hours          numeric(5,2);
  v_status         text;
  v_today          date    := (now() AT TIME ZONE 'Asia/Manila')::date;
  v_gate_open      boolean;
BEGIN
  -- Normalize UID
  v_clean_uid := upper(trim(p_rfid_uid));

  -- Auto-close nakaraang araw na walang time-out
  UPDATE public.attendance_logs
  SET status = 'incomplete', total_hours = 0.00
  WHERE date < v_today AND time_out IS NULL;

  -- Queue scan kung sa Commissary Base (Enrollment)
  IF p_device_id = 'esp32_commissary_base' THEN
    INSERT INTO public.rfid_scan_queue (rfid_uid, device_id)
    VALUES (v_clean_uid, p_device_id);

    DELETE FROM public.rfid_scan_queue
    WHERE scanned_at < (now() - interval '5 minutes');
  END IF;

  -- Hanapin ang staff sa pamamagitan ng RFID tag
  SELECT * INTO v_staff
  FROM public.staff_profiles
  WHERE upper(trim(rfid_tag)) = v_clean_uid
    AND is_archived = false
  LIMIT 1;

  -- UNREGISTERED CARD
  IF v_staff IS NULL THEN
    IF p_device_id = 'esp32_commissary_base' THEN
      RETURN json_build_object(
        'success',   true,
        'type',      'enrollment_scan',
        'code',      'ENROLLMENT_READY',
        'message',   'RFID card captured for enrollment.',
        'rfid_uid',  v_clean_uid,
        'device_id', p_device_id
      );
    ELSE
      RETURN json_build_object(
        'success',   false,
        'code',      'UNREGISTERED',
        'message',   'RFID card is not registered to any active employee.',
        'rfid_uid',  v_clean_uid,
        'device_id', p_device_id
      );
    END IF;
  END IF;

  -- Kunin ang buong pangalan ng empleyado
  v_full_name := trim(concat(v_staff.first_name, ' ', COALESCE(v_staff.middle_name, ''), ' ', v_staff.last_name));
  v_full_name := regexp_replace(v_full_name, '\s+', ' ', 'g');

  -- RULE 1: Branch Cook ay bawal mag-time in sa Commissary Base
  IF p_device_id = 'esp32_commissary_base' AND v_staff.position = 'Branch Cook' THEN
    RETURN json_build_object(
      'success',    false,
      'code',       'WRONG_LOCATION',
      'message',    'Branch cooks must scan using their assigned branch reader.',
      'staff_name', v_full_name,
      'device_id',  p_device_id
    );
  END IF;

  -- RULE 2: Production / Cutter staff ay bawal mag-time in sa Driver Unit
  IF p_device_id = 'esp32_driver_portable'
     AND (v_staff.position ILIKE '%cutter%' OR v_staff.position ILIKE '%production%')
  THEN
    RETURN json_build_object(
      'success',    false,
      'code',       'WRONG_LOCATION',
      'message',    'Production staff must scan using the commissary base reader.',
      'staff_name', v_full_name,
      'device_id',  p_device_id
    );
  END IF;

  -- Tukuyin ang branch context
  IF p_device_id = 'esp32_commissary_base' THEN
    v_branch_id   := 'commissary';
    v_branch_name := 'Central Commissary (Base)';
  ELSE
    v_branch_id   := COALESCE(NULLIF(p_branch_id, ''), v_staff.branch_name, 'br1');
    v_branch_name := COALESCE(v_staff.branch_name, 'Assigned Branch');
  END IF;

  -- RULE 3: Driver Portable Unit - Kailangang ON THE WAY na si Driver para kay Branch Cook
  IF p_device_id = 'esp32_driver_portable' AND v_staff.position = 'Branch Cook' THEN
    SELECT * INTO v_dispatch
    FROM public.driver_dispatch_status
    WHERE driver_on_the_way = true
      AND updated_at >= (now() - interval '18 hours')
    ORDER BY updated_at DESC
    LIMIT 1;

    IF FOUND THEN
      v_dispatch_found := true;
    ELSE
      RETURN json_build_object(
        'success',    false,
        'code',       'DRIVER_NOT_ON_THE_WAY',
        'message',    'Driver route is not yet active for this branch.',
        'staff_name', v_full_name,
        'device_id',  p_device_id
      );
    END IF;
  END IF;

  -- RULE 4: Commissary Base Unit - Kailangang BUKAS ang Production Shift ni Admin
  IF p_device_id = 'esp32_commissary_base' THEN
    SELECT COALESCE(is_open, false) INTO v_gate_open
    FROM public.production_shift_control
    WHERE date = v_today;

    IF v_gate_open IS NOT TRUE THEN
      RETURN json_build_object(
        'success',    false,
        'code',       'PRODUCTION_NOT_OPEN',
        'message',    'Production shift has not been opened by administrator.',
        'staff_name', v_full_name,
        'device_id',  p_device_id
      );
    END IF;
  END IF;

  -- Tingnan ang attendance log ngayong araw
  SELECT * INTO v_log
  FROM public.attendance_logs
  WHERE staff_id = v_staff.id
    AND date = v_today
  ORDER BY time_in DESC
  LIMIT 1;

  -- =========================================================
  -- KASO A: Wala pang log ngayong araw -> TIME-IN
  -- =========================================================
  IF v_log IS NULL THEN

    -- Bawal mag-time-in kapag retrieval mode na ang biyahe ni driver
    IF p_device_id = 'esp32_driver_portable'
       AND v_staff.position = 'Branch Cook'
       AND v_dispatch_found
       AND v_dispatch.mode = 'retrieval'
    THEN
      RETURN json_build_object(
        'success',    false,
        'code',       'NO_TIME_IN',
        'message',    'No morning Time-In found. Shift cannot be recorded.',
        'staff_name', v_full_name,
        'device_id',  p_device_id
      );
    END IF;

    v_status := 'present';

    INSERT INTO public.attendance_logs
      (staff_id, staff_name, position, branch_id, branch_name, date, time_in, status, rfid_uid, device_id)
    VALUES
      (v_staff.id, v_full_name, COALESCE(v_staff.position, 'Staff'),
       v_branch_id, v_branch_name, v_today, now(), v_status, v_clean_uid, p_device_id);

    -- I-clear ang on_the_way flag pagkatapos mag-time-in si branch cook
    IF p_device_id = 'esp32_driver_portable'
       AND v_staff.position = 'Branch Cook'
       AND v_dispatch_found
    THEN
      UPDATE public.driver_dispatch_status
      SET driver_on_the_way = false, updated_at = now()
      WHERE branch_id = v_dispatch.branch_id;
    END IF;

    RETURN json_build_object(
      'success',     true,
      'type',        'time_in',
      'staff_id',    v_staff.id,
      'staff_name',  v_full_name,
      'position',    v_staff.position,
      'branch_id',   v_branch_id,
      'branch_name', v_branch_name,
      'status',      v_status,
      'time',        to_char((now() AT TIME ZONE 'Asia/Manila'), 'HH12:MI AM'),
      'message',     'Time-In recorded successfully.'
    );

  -- =========================================================
  -- KASO B: May time-in na pero wala pang time-out -> TIME-OUT
  -- =========================================================
  ELSIF v_log.time_out IS NULL THEN

    -- Bawal mag-time-out kapag deployment mode pa lang
    IF p_device_id = 'esp32_driver_portable'
       AND v_staff.position = 'Branch Cook'
       AND v_dispatch_found
       AND v_dispatch.mode = 'deployment'
    THEN
      RETURN json_build_object(
        'success',    false,
        'code',       'ALREADY_TIMED_IN',
        'message',    'Morning Time-In already recorded for this branch.',
        'staff_name', v_full_name,
        'device_id',  p_device_id
      );
    END IF;

    -- Debounce: huwag pansinin ang tap sa loob ng 5 segundo
    IF now() < (v_log.time_in + interval '5 seconds') THEN
      RETURN json_build_object(
        'success',    false,
        'code',       'DEBOUNCED',
        'type',       'debounced',
        'staff_name', v_full_name,
        'message',    'Card was scanned recently.'
      );
    END IF;

    -- Production/Cutter staff: kailangang authorized ni admin ang time-out
    IF p_device_id = 'esp32_commissary_base'
       AND (v_staff.position ILIKE '%cutter%' OR v_staff.position ILIKE '%production%')
    THEN
      IF v_log.timeout_allowed IS NOT TRUE THEN
        RETURN json_build_object(
          'success',    false,
          'code',       'TIMEOUT_NOT_ALLOWED',
          'message',    'Shift time-out is not yet authorized by administrator.',
          'staff_name', v_full_name,
          'device_id',  p_device_id
        );
      END IF;
    END IF;

    -- Kalkulahin ang kabuuang oras (hours worked)
    v_hours := abs(round(extract(epoch from (now() - v_log.time_in))::numeric / 3600.0, 2));

    UPDATE public.attendance_logs
    SET time_out = now(), total_hours = v_hours
    WHERE id = v_log.id;

    -- I-clear ang on_the_way flag pagkatapos mag-time-out si branch cook
    IF p_device_id = 'esp32_driver_portable'
       AND v_staff.position = 'Branch Cook'
       AND v_dispatch_found
    THEN
      UPDATE public.driver_dispatch_status
      SET driver_on_the_way = false, updated_at = now()
      WHERE branch_id = v_dispatch.branch_id;
    END IF;

    RETURN json_build_object(
      'success',     true,
      'type',        'time_out',
      'staff_id',    v_staff.id,
      'staff_name',  v_full_name,
      'position',    v_staff.position,
      'branch_id',   v_branch_id,
      'branch_name', v_branch_name,
      'time_in',     to_char((v_log.time_in AT TIME ZONE 'Asia/Manila'), 'HH12:MI AM'),
      'time_out',    to_char((now()         AT TIME ZONE 'Asia/Manila'), 'HH12:MI AM'),
      'total_hours', v_hours,
      'message',     'Time-Out recorded successfully.'
    );

  -- =========================================================
  -- KASO C: Tapos na ang shift (may Time-in at Time-out na)
  -- =========================================================
  ELSE
    RETURN json_build_object(
      'success',    false,
      'code',       'ALREADY_COMPLETED',
      'type',       'already_completed',
      'staff_name', v_full_name,
      'message',    'Shift attendance for today has already been completed.'
    );
  END IF;

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'code',    'SERVER_ERROR',
    'message', SQLERRM
  );
END;
$$;

-- I-grant ang permissions para sa anonymous at authenticated users
GRANT EXECUTE ON FUNCTION public.process_rfid_tap(text, text, text) TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.production_shift_control TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.driver_dispatch_status TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.rfid_scan_queue TO anon, authenticated, service_role;
