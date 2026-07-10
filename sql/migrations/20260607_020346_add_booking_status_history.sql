-- ============================================================
-- FixBuddy Migration: Booking Status History
-- File: 20260607_020346_add_booking_status_history.sql
-- Run AFTER 20260607_020345_add_worker_availability_slots.sql
-- ============================================================
-- This migration adds a table to track booking status changes over time
-- Depends on: 01_tables.sql (bookings table)
-- Order: Run after all initial schema migrations and worker_availability_slots

-- ────────────────────────────────────────────────────────────
-- TABLE: booking_status_history
-- Audit trail for booking status transitions
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.booking_status_history (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id    UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  from_status   booking_status,
  to_status     booking_status NOT NULL,
  changed_by    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  change_reason TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.booking_status_history ENABLE ROW LEVEL SECURITY;

-- Participants can read status history of their bookings
CREATE POLICY "booking_status_history: participant read"
  ON public.booking_status_history FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_status_history.booking_id
        AND (b.user_id = auth.uid() OR b.worker_id = public.get_my_worker_id())
    )
  );

-- Insert via SECURITY DEFINER function only (trigger)
-- Admin full access
CREATE POLICY "booking_status_history: admin full"
  ON public.booking_status_history FOR ALL
  USING (public.get_my_role() = 'admin');

-- Indexes
CREATE INDEX idx_booking_status_history_booking ON public.booking_status_history(booking_id);
CREATE INDEX idx_booking_status_history_created ON public.booking_status_history(created_at DESC);

-- ────────────────────────────────────────────────────────────
-- FUNCTION: Auto-record status changes
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.record_booking_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.booking_status_history (booking_id, from_status, to_status, changed_by)
    VALUES (NEW.id, OLD.status, NEW.status, auth.uid());
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_booking_status_change
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.record_booking_status_change();
