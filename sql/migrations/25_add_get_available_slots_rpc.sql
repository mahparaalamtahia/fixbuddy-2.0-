-- ============================================================
-- FixBuddy Migration: get_available_slots RPC
-- File: 25_add_get_available_slots_rpc.sql
-- Creates the missing RPC function called by BookingScreen
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- FUNCTION: get_available_slots
-- Returns available time-slot periods for a worker on a given date.
-- Cross-references the worker_availability_slots table (weekly schedule)
-- with existing confirmed/pending bookings to determine availability.
-- ────────────────────────────────────────────────────────────
-- Drop the existing function first (return type changed)
DROP FUNCTION IF EXISTS public.get_available_slots(UUID, DATE);

CREATE OR REPLACE FUNCTION public.get_available_slots(
  p_worker_id UUID,
  p_date DATE
)
RETURNS TABLE(period TEXT, is_available BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_of_week SMALLINT;
BEGIN
  -- PostgreSQL EXTRACT(DOW ...) returns 0=Sunday..6=Saturday
  v_day_of_week := EXTRACT(DOW FROM p_date)::SMALLINT;

  RETURN QUERY
  SELECT
    was.period::TEXT AS period,
    -- A slot is available if the worker has marked it available
    -- AND there is no existing pending/confirmed booking for that period
    (was.is_available
      AND NOT EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.worker_id = p_worker_id
          AND b.scheduled_date = p_date
          AND b.status IN ('pending', 'confirmed', 'in_progress')
          AND (
            -- Map booking scheduled_time to period
            (was.period::TEXT = 'morning'   AND b.scheduled_time >= '08:00:00' AND b.scheduled_time < '12:00:00') OR
            (was.period::TEXT = 'afternoon' AND b.scheduled_time >= '12:00:00' AND b.scheduled_time < '16:00:00') OR
            (was.period::TEXT = 'evening'   AND b.scheduled_time >= '16:00:00' AND b.scheduled_time < '20:00:00')
          )
      )
    ) AS is_available
  FROM public.worker_availability_slots was
  WHERE was.worker_id = p_worker_id
    AND was.day_of_week = v_day_of_week
  ORDER BY
    CASE was.period::TEXT
      WHEN 'morning' THEN 1
      WHEN 'afternoon' THEN 2
      WHEN 'evening' THEN 3
      ELSE 4
    END;

  -- If the worker has NO slots configured for this day, return all three
  -- periods as unavailable so the UI can still render them.
  IF NOT FOUND THEN
    RETURN QUERY
    SELECT p.period, FALSE AS is_available
    FROM (VALUES ('morning'), ('afternoon'), ('evening')) AS p(period);
  END IF;
END;
$$;

SELECT '25_add_get_available_slots_rpc.sql applied successfully' AS status;
