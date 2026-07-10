-- ============================================================
-- FixBuddy Migration: Typing Status for Chat
-- File: 20260607_020349_add_typing_status.sql
-- Run AFTER 20260607_020348_add_review_photos.sql
-- ============================================================
-- This migration adds a table for real-time typing indicators
-- Depends on: 01_tables.sql (chats table)
-- Order: Run after all initial schema migrations and review_photos

-- ────────────────────────────────────────────────────────────
-- TABLE: typing_status
-- Tracks who is currently typing in which chat
-- Auto-expires after inactivity (handled by app)
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.typing_status (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id       UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_typing     BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(chat_id, user_id)
);

-- Enable RLS
ALTER TABLE public.typing_status ENABLE ROW LEVEL SECURITY;

-- Chat participants can read typing status
CREATE POLICY "typing_status: participant read"
  ON public.typing_status FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = typing_status.chat_id
        AND (c.user_id = auth.uid() OR c.worker_id = public.get_my_worker_id())
    )
  );

-- Chat participants can update their own typing status
CREATE POLICY "typing_status: participant update own"
  ON public.typing_status FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Chat participants can insert their own typing status
CREATE POLICY "typing_status: participant insert own"
  ON public.typing_status FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Admin full access
CREATE POLICY "typing_status: admin full"
  ON public.typing_status FOR ALL
  USING (public.get_my_role() = 'admin');

-- Indexes
CREATE INDEX idx_typing_status_chat ON public.typing_status(chat_id);
CREATE INDEX idx_typing_status_updated ON public.typing_status(updated_at DESC);

-- Enable realtime for typing indicators
ALTER PUBLICATION supabase_realtime ADD TABLE public.typing_status;

-- ────────────────────────────────────────────────────────────
-- FUNCTION: Auto-expire typing status after 5 seconds of inactivity
-- Can be called via pg_cron or handled client-side
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.expire_typing_status()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.typing_status
  SET is_typing = FALSE
  WHERE is_typing = TRUE
    AND updated_at < NOW() - INTERVAL '5 seconds';
END;
$$;
