-- ============================================================
-- FixBuddy Migration: Cash Payment Fields
-- File: 18_cash_payment.sql
-- Run AFTER 06_realtime.sql
-- ============================================================
-- This migration adds cash payment tracking to bookings table
-- Depends on: 01_tables.sql (bookings table)
-- Order: Run after all initial schema migrations (01-06)

-- ────────────────────────────────────────────────────────────
-- ALTER TABLE: bookings
-- Add payment tracking columns for cash payments
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'cash'
  CHECK (payment_method IN ('cash')),
ADD COLUMN IF NOT EXISTS payment_received BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS payment_received_at TIMESTAMPTZ;

-- Create index for payment tracking queries
CREATE INDEX IF NOT EXISTS idx_bookings_payment_received
  ON public.bookings(payment_received)
  WHERE payment_method = 'cash';

-- Comment for documentation
COMMENT ON COLUMN public.bookings.payment_method IS 'Payment method - currently only cash is supported';
COMMENT ON COLUMN public.bookings.payment_received IS 'Whether the worker has confirmed receiving cash payment';
COMMENT ON COLUMN public.bookings.payment_received_at IS 'Timestamp when payment was confirmed as received';

-- ────────────────────────────────────────────────────────────
-- RLS POLICIES: payment tracking is part of bookings table
-- Existing policies already cover these columns
-- No additional policies needed since they're part of bookings
-- ────────────────────────────────────────────────────────────
