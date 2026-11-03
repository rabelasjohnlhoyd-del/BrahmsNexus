-- ==============================================================================
-- BRAHMS SISIG & BAGNET: RFID ATTENDANCE & BRANCH AUTOMATION SCHEMA
-- Run this in your Supabase Project's SQL Editor (Dashboard -> SQL Editor -> New Query)
-- ==============================================================================

-- 1. Ensure rfid_tag column in staff_profiles exists and is unique
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'staff_profiles' AND column_name = 'rfid_tag'
  ) THEN
    ALTER TABLE public.staff_profiles ADD COLUMN rfid_tag text;
  END IF;
END $$;

-- Add partial unique index so null or empty values don't collide
CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_profiles_rfid_tag_unique 
ON public.staff_profiles(rfid_tag) 
WHERE rfid_tag IS NOT NULL AND rfid_tag <> '';

-- 2. Create the attendance_logs table for official DTR & Payroll records
CREATE TABLE IF NOT EXISTS public.attendance_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id text NOT NULL,
  staff_name text NOT NULL,
  position text NOT NULL,
  branch_id text NOT NULL DEFAULT '',
  branch_name text NOT NULL DEFAULT '',
  date date NOT NULL DEFAULT CURRENT_DATE,
  time_in timestamptz NOT NULL DEFAULT now(),
  time_out timestamptz,
  total_hours numeric(5,2),
  status text NOT NULL DEFAULT 'on_time', -- 'on_time', 'late', 'overtime'
  timeout_allowed boolean DEFAULT false, -- Admin clearance for Production staff time-out
  rfid_uid text NOT NULL,
  device_id text NOT NULL DEFAULT 'esp32_reader',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure timeout_allowed column exists if table was previously created
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'attendance_logs' AND column_name = 'timeout_allowed'
  ) THEN
    ALTER TABLE public.attendance_logs ADD COLUMN timeout_allowed boolean DEFAULT false;
  END IF;
END $$;

-- Index for speedy queries on today's attendance
CREATE INDEX IF NOT EXISTS idx_attendance_logs_date_staff 
ON public.attendance_logs(date, staff_id);

CREATE INDEX IF NOT EXISTS idx_attendance_logs_rfid 
ON public.attendance_logs(rfid_uid);

-- 3. Create the rfid_scan_queue table for Admin Web Card Enrollment
-- When Owner clicks "Scan Card" in Admin Web, this table temporarily receives the tapped UID
CREATE TABLE IF NOT EXISTS public.rfid_scan_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rfid_uid text NOT NULL,
  device_id text NOT NULL,
  staff_id text,
  scanned_at timestamptz NOT NULL DEFAULT now()
);

-- Index for real-time enrollment listening
CREATE INDEX IF NOT EXISTS idx_rfid_scan_queue_scanned_at 
ON public.rfid_scan_queue(scanned_at DESC);

-- Enable Supabase Realtime on rfid_scan_queue and attendance_logs
ALTER PUBLICATION supabase_realtime ADD TABLE public.rfid_scan_queue;
ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_logs;

-- Enable Row Level Security (RLS)
ALTER TABLE public.attendance_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfid_scan_queue ENABLE ROW LEVEL SECURITY;

-- Allow anonymous & authenticated reads/writes (or customize per your Supabase policies)
DROP POLICY IF EXISTS "Public Attendance Access" ON public.attendance_logs;
CREATE POLICY "Public Attendance Access" 
ON public.attendance_logs 
FOR ALL 
USING (true) 
WITH CHECK (true);

DROP POLICY IF EXISTS "Public Scan Queue Access" ON public.rfid_scan_queue;
CREATE POLICY "Public Scan Queue Access" 
ON public.rfid_scan_queue 
FOR ALL 
USING (true) 
WITH CHECK (true);

-- 4. Create the driver_dispatch_status table for active route stop verification
CREATE TABLE IF NOT EXISTS public.driver_dispatch_status (
  branch_id text PRIMARY KEY,
  branch_name text NOT NULL DEFAULT '',
  driver_name text NOT NULL DEFAULT 'Driver',
  cook_name text NOT NULL DEFAULT '',
  driver_on_the_way boolean NOT NULL DEFAULT false,
  mode text NOT NULL DEFAULT 'deployment',
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure cook_name column exists if table was previously created
ALTER TABLE public.driver_dispatch_status ADD COLUMN IF NOT EXISTS cook_name text NOT NULL DEFAULT '';

ALTER TABLE public.driver_dispatch_status ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public Dispatch Access" ON public.driver_dispatch_status;
CREATE POLICY "Public Dispatch Access" 
ON public.driver_dispatch_status 
FOR ALL 
USING (true) 
WITH CHECK (true);

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_dispatch_status;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 5. Stored Procedure: process_rfid_tap
-- Called directly by ESP32 via Supabase REST API (POST /rest/v1/rpc/process_rfid_tap)
CREATE OR REPLACE FUNCTION public.process_rfid_tap(
  p_rfid_uid text,
  p_device_id text,
  p_branch_id text DEFAULT ''
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff record;
  v_log record;
  v_dispatch record;
  v_full_name text;
  v_branch_id text;
  v_branch_name text;
  v_clean_uid text;
  v_hours numeric(5,2);
  v_status text;
  v_is_late boolean;
  v_late_cutoff time := '08:00:00'; -- Morning cutoff in Philippine Time
  v_today date := (now() AT TIME ZONE 'Asia/Manila')::date;
  v_current_time time := (now() AT TIME ZONE 'Asia/Manila')::time;
BEGIN
  -- Normalize UID (uppercase, no whitespace)
  v_clean_uid := upper(trim(p_rfid_uid));

  -- Automatically close any unclosed logs from previous days as 'incomplete' (0.00 hrs)
  UPDATE public.attendance_logs
  SET status = 'incomplete',
      total_hours = 0.00
  WHERE date < v_today
    AND time_out IS NULL;

  -- Log to rfid_scan_queue ONLY if scanned on Base Station (Bahay ni Owner)
  -- for Admin Web Enrollment. Driver Portable scans never touch scan queue.
  IF p_device_id = 'esp32_commissary_base' THEN
    INSERT INTO public.rfid_scan_queue (rfid_uid, device_id)
    VALUES (v_clean_uid, p_device_id);

    DELETE FROM public.rfid_scan_queue WHERE scanned_at < (now() - interval '5 minutes');
  END IF;

  -- Look up registered staff by rfid_tag
  SELECT * INTO v_staff
  FROM public.staff_profiles
  WHERE upper(trim(rfid_tag)) = v_clean_uid
    AND is_archived = false
  LIMIT 1;

  -- Card not registered
  IF v_staff IS NULL THEN
    -- If tapped on Base Station (Bahay ni Owner), treat as Enrollment Scan (Success Chime / Green LED)
    IF p_device_id = 'esp32_commissary_base' THEN
      RETURN json_build_object(
        'success', true,
        'type', 'enrollment_scan',
        'code', 'ENROLLMENT_READY',
        'message', 'RFID card captured for enrollment.',
        'rfid_uid', v_clean_uid,
        'device_id', p_device_id
      );
    ELSE
      -- On Driver portable unit, unregistered cards are rejected (Red LED)
      RETURN json_build_object(
        'success', false,
        'code', 'UNREGISTERED',
        'message', 'RFID card is not registered to any active employee.',
        'rfid_uid', v_clean_uid,
        'device_id', p_device_id
      );
    END IF;
  END IF;

  -- Format employee full name
  v_full_name := trim(concat(v_staff.first_name, ' ', COALESCE(v_staff.middle_name, ''), ' ', v_staff.last_name));
  v_full_name := regexp_replace(v_full_name, '\s+', ' ', 'g');

  -- ============================================================================
  -- STRICT HARDWARE ROLE GEOFENCING / DEVICE VALIDATION
  -- ============================================================================
  -- RULE 1: If tapped on Base Station (Bahay ni Owner) but staff is a Branch Cook:
  -- REJECT the tap! (Branch Cooks are NOT allowed to clock in/out at the base station)
  IF p_device_id = 'esp32_commissary_base' AND v_staff.position = 'Branch Cook' THEN
    RETURN json_build_object(
      'success', false,
      'code', 'WRONG_LOCATION',
      'message', 'Branch cooks must scan using their assigned branch reader.',
      'staff_name', v_full_name,
      'device_id', p_device_id
    );
  END IF;

  -- RULE 2: If tapped on Driver Portable Unit but staff is Production Staff (Cutter / Prod Cook):
  -- REJECT the tap! (Production staff work at commissary base, not on driver route)
  IF p_device_id = 'esp32_driver_portable' AND (v_staff.position ILIKE '%cutter%' OR v_staff.position ILIKE '%production%') THEN
    RETURN json_build_object(
      'success', false,
      'code', 'WRONG_LOCATION',
      'message', 'Production staff must scan using the commissary base reader.',
      'staff_name', v_full_name,
      'device_id', p_device_id
    );
  END IF;

  -- Determine Branch context
  IF p_device_id = 'esp32_commissary_base' THEN
    v_branch_id := 'commissary';
    v_branch_name := 'Central Commissary (Base)';
  ELSE
    v_branch_id := COALESCE(NULLIF(p_branch_id, ''), v_staff.branch_name, 'br1');
    v_branch_name := COALESCE(v_staff.branch_name, 'Assigned Branch');
  END IF;

  -- ============================================================================
  -- RULE 3: STRICT DRIVER DISPATCH ENFORCEMENT FOR BRANCH COOKS:
  -- Branch Cooks tapping on the Driver Portable Unit MUST have the driver
  -- actively "On the way" in the Driver App!
  -- If driver hasn't tapped "On the way", REJECT the tap!
  -- ============================================================================
  IF p_device_id = 'esp32_driver_portable' AND v_staff.position = 'Branch Cook' THEN
    SELECT * INTO v_dispatch
    FROM public.driver_dispatch_status
    WHERE driver_on_the_way = true
      AND updated_at >= (now() - interval '18 hours')
    ORDER BY updated_at DESC
    LIMIT 1;

    -- Kung hindi pa pinipindot ni driver ang "On the way": HARANG (RED LED)
    IF v_dispatch IS NULL THEN
      RETURN json_build_object(
        'success', false,
        'code', 'DRIVER_NOT_ON_THE_WAY',
        'message', 'Driver route is not yet active for this branch. Please wait for driver arrival.',
        'staff_name', v_full_name,
        'device_id', p_device_id
      );
    END IF;
  END IF;

  -- Check if staff already has an attendance log for Philippine today
  SELECT * INTO v_log
  FROM public.attendance_logs
  WHERE staff_id = v_staff.id
    AND date = v_today
  ORDER BY time_in DESC
  LIMIT 1;

  -- CASE 1: NO ATTENDANCE TODAY -> RECORD TIME-IN
  IF v_log IS NULL THEN
    -- VALIDATION: If Branch Cook taps during afternoon Retrieval without a morning Time-In: REJECT!
    IF p_device_id = 'esp32_driver_portable' AND v_staff.position = 'Branch Cook' AND v_dispatch IS NOT NULL AND v_dispatch.mode = 'retrieval' THEN
      RETURN json_build_object(
        'success', false,
        'code', 'NO_TIME_IN',
        'message', 'No morning Time-In found. Shift cannot be recorded.',
        'staff_name', v_full_name,
        'device_id', p_device_id
      );
    END IF;

    -- Check if late (e.g. past 8:00 AM in Philippine Time)
    IF v_current_time > v_late_cutoff THEN
      v_status := 'late';
    ELSE
      v_status := 'on_time';
    END IF;

    INSERT INTO public.attendance_logs (
      staff_id,
      staff_name,
      position,
      branch_id,
      branch_name,
      date,
      time_in,
      status,
      rfid_uid,
      device_id
    ) VALUES (
      v_staff.id,
      v_full_name,
      COALESCE(v_staff.position, 'Staff'),
      v_branch_id,
      v_branch_name,
      v_today,
      now(),
      v_status,
      v_clean_uid,
      p_device_id
    );

    -- Consume driver dispatch for this stop so cook cannot tap repeatedly without new driver dispatch
    IF p_device_id = 'esp32_driver_portable' AND v_staff.position = 'Branch Cook' AND v_dispatch IS NOT NULL THEN
      UPDATE public.driver_dispatch_status
      SET driver_on_the_way = false,
          updated_at = now()
      WHERE branch_id = v_dispatch.branch_id;
    END IF;

    RETURN json_build_object(
      'success', true,
      'type', 'time_in',
      'staff_id', v_staff.id,
      'staff_name', v_full_name,
      'position', v_staff.position,
      'branch_id', v_branch_id,
      'branch_name', v_branch_name,
      'status', v_status,
      'time', now(),
      'message', 'Time-In recorded successfully.'
    );

  -- CASE 2: HAS TIME-IN BUT NO TIME-OUT -> RECORD TIME-OUT
  ELSIF v_log.time_out IS NULL THEN
    -- VALIDATION: Branch Cook cannot clock out during morning Deployment mode
    IF p_device_id = 'esp32_driver_portable' AND v_staff.position = 'Branch Cook' AND v_dispatch IS NOT NULL AND v_dispatch.mode = 'deployment' THEN
      RETURN json_build_object(
        'success', false,
        'code', 'ALREADY_TIMED_IN',
        'message', 'Morning Time-In already recorded for this branch.',
        'staff_name', v_full_name,
        'device_id', p_device_id
      );
    END IF;

    -- Debounce: Ignore only if tapped within 5 seconds of time-in (to prevent accidental hardware bounce)
    IF now() < (v_log.time_in + interval '5 seconds') THEN
      RETURN json_build_object(
        'success', false,
        'code', 'DEBOUNCED',
        'type', 'debounced',
        'staff_name', v_full_name,
        'message', 'Card was scanned recently. Please wait before clocking out.'
      );
    END IF;

    -- ============================================================================
    -- PRODUCTION STAFF CLEARANCE CHECK:
    -- Cutters and Production Cooks tapping on Base Unit must be authorized by Admin
    -- (timeout_allowed = true) before their Time-Out tap is accepted!
    -- ============================================================================
    IF p_device_id = 'esp32_commissary_base' AND (v_staff.position ILIKE '%cutter%' OR v_staff.position ILIKE '%production%') THEN
      IF v_log.timeout_allowed IS NOT TRUE THEN
        RETURN json_build_object(
          'success', false,
          'code', 'TIMEOUT_NOT_ALLOWED',
          'message', 'Shift time-out is not yet authorized by administrator.',
          'staff_name', v_full_name,
          'device_id', p_device_id
        );
      END IF;
    END IF;

    -- Calculate total hours worked (wrapped in abs to protect against timezone skew)
    v_hours := abs(round(extract(epoch from (now() - v_log.time_in))::numeric / 3600.0, 2));

    UPDATE public.attendance_logs
    SET time_out = now(),
        total_hours = v_hours
    WHERE id = v_log.id;

    -- Consume driver dispatch for this stop so cook cannot tap repeatedly without new driver dispatch
    IF p_device_id = 'esp32_driver_portable' AND v_staff.position = 'Branch Cook' AND v_dispatch IS NOT NULL THEN
      UPDATE public.driver_dispatch_status
      SET driver_on_the_way = false,
          updated_at = now()
      WHERE branch_id = v_dispatch.branch_id;
    END IF;

    RETURN json_build_object(
      'success', true,
      'type', 'time_out',
      'staff_id', v_staff.id,
      'staff_name', v_full_name,
      'position', v_staff.position,
      'branch_id', v_branch_id,
      'branch_name', v_branch_name,
      'time_in', v_log.time_in,
      'time_out', now(),
      'total_hours', v_hours,
      'message', 'Time-Out recorded successfully.'
    );

  -- CASE 3: BOTH TIME-IN & TIME-OUT ALREADY RECORDED (1 SHIFT PER DAY ONLY)
  ELSE
    RETURN json_build_object(
      'success', false,
      'code', 'ALREADY_COMPLETED',
      'type', 'already_completed',
      'staff_name', v_full_name,
      'message', 'Shift attendance for today has already been completed.'
    );
  END IF;

END;
$$;

END;
$$;
