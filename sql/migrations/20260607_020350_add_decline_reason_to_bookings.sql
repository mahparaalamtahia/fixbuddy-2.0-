-- ============================================================
-- FixBuddy Migration: Add Decline Reason to Bookings
-- File: 20260607_020350_add_decline_reason_to_bookings.sql
-- Run AFTER 20260607_020349_add_typing_status.sql
-- ============================================================
-- This migration adds a decline_reason column to the bookings table
-- Depends on: 01_tables.sql (bookings table)
-- Order: Run after all initial schema migrations and typing_status

-- ────────────────────────────────────────────────────────────
-- ALTER TABLE: bookings
-- Add decline_reason column for worker rejection feedback
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS decline_reason TEXT;

-- Index for filtering declined bookings with reasons
CREATE INDEX IF NOT EXISTS idx_bookings_declined_reason
  ON public.bookings(status, decline_reason)
  WHERE status = 'declined';

-- Comment for documentation
COMMENT ON COLUMN public.bookings.decline_reason IS 'Reason provided by worker when declining a booking';
