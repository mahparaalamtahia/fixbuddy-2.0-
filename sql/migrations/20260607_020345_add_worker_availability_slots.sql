-- ============================================================
-- FixBuddy Migration: Worker Availability Slots
-- File: 20260607_020345_add_worker_availability_slots.sql
-- Run AFTER 06_realtime.sql
-- ============================================================
-- This migration adds a table for worker weekly availability schedule
-- Depends on: 01_tables.sql (workers table)
-- Order: Run after all initial schema migrations (01-06)

-- ────────────────────────────────────────────────────────────
-- TABLE: worker_availability_slots
-- Stores weekly recurring availability for workers
-- Mon-Sun × Morning/Afternoon/Evening time slots
-- ────────────────────────────────────────────────────────────
CREATE TYPE availability_period AS ENUM ('morning', 'afternoon', 'evening');

CREATE TABLE public.worker_availability_slots (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id     UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
  day_of_week   SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday, 1=Monday, ..., 6=Saturday
  period        availability_period NOT NULL,
  is_available  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(worker_id, day_of_week, period)
);

-- Enable RLS
ALTER TABLE public.worker_availability_slots ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read availability of available workers
CREATE POLICY "worker_availability: auth read available workers"
  ON public.worker_availability_slots FOR SELECT
  USING (
    auth.role() = 'authenticated'
    AND EXISTS (
      SELECT 1 FROM public.workers w
      JOIN public.profiles p ON p.id = w.profile_id
      WHERE w.id = worker_availability_slots.worker_id
        AND w.is_available = TRUE
        AND p.is_active = TRUE
    )
  );

-- Worker manages their own availability
CREATE POLICY "worker_availability: worker write own"
  ON public.worker_availability_slots FOR ALL
  USING (worker_id = public.get_my_worker_id());

-- Admin full access
CREATE POLICY "worker_availability: admin full"
  ON public.worker_availability_slots FOR ALL
  USING (public.get_my_role() = 'admin');

-- Indexes for performance
CREATE INDEX idx_worker_availability_worker ON public.worker_availability_slots(worker_id);
CREATE INDEX idx_worker_availability_day ON public.worker_availability_slots(day_of_week);

-- Trigger for updated_at
CREATE TRIGGER trg_worker_availability_updated_at
  BEFORE UPDATE ON public.worker_availability_slots
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Enable realtime for availability changes (optional, for live updates)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.worker_availability_slots;
