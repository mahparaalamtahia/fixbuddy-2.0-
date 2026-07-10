-- ============================================================
-- FixBuddy Database Migration
-- File: 14_make_chat_booking_nullable.sql
-- Description: Allows users to chat with workers before booking.
-- ============================================================

-- 1. Drop the NOT NULL constraint on booking_id
ALTER TABLE public.chats ALTER COLUMN booking_id DROP NOT NULL;

-- 2. Drop the UNIQUE constraint on booking_id to allow multiple non-booking chats,
-- wait, UNIQUE constraint on NULL allows multiple NULLs in Postgres, so it's fine, 
-- but let's be safe: 
-- (Actually in Postgres NULL != NULL, so multiple chats with booking_id = NULL are allowed by the UNIQUE constraint).

-- 3. We should add a unique constraint to prevent duplicate chats between the same user and worker 
-- if booking_id is null.
CREATE UNIQUE INDEX IF NOT EXISTS idx_chats_user_worker_null_booking
ON public.chats(user_id, worker_id)
WHERE booking_id IS NULL;

SELECT 'Migration 14_make_chat_booking_nullable.sql applied successfully!' as status;
