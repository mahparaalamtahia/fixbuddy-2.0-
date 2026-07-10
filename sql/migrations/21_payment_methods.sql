-- ============================================================
-- FixBuddy Migration: Extended Payment Methods
-- File: 21_payment_methods.sql
-- ============================================================
-- This migration expands the payment_method CHECK constraint
-- to support digital payment options alongside cash.
-- Depends on: 18_cash_payment.sql

ALTER TABLE public.bookings
DROP CONSTRAINT IF EXISTS bookings_payment_method_check;

ALTER TABLE public.bookings
ADD CONSTRAINT bookings_payment_method_check
  CHECK (payment_method IN ('cash', 'bkash', 'nagad', 'rocket'));

DROP INDEX IF EXISTS idx_bookings_payment_received;

CREATE INDEX IF NOT EXISTS idx_bookings_payment_method
  ON public.bookings(payment_method);

COMMENT ON COLUMN public.bookings.payment_method IS 'Payment method: cash, bkash, nagad, or rocket';
COMMENT ON COLUMN public.bookings.payment_received IS 'Whether the worker has confirmed receiving payment';
COMMENT ON COLUMN public.bookings.payment_received_at IS 'Timestamp when payment was confirmed as received';
