-- ============================================================
-- FixBuddy Migration: Analytics Events Table
-- File: 20260609_000001_add_analytics_events.sql
-- ============================================================
CREATE TABLE public.analytics_events (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_name    TEXT NOT NULL,
  parameters    JSONB DEFAULT '{}'::jsonb,
  user_id       UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "analytics_events: admin read all"
  ON public.analytics_events FOR SELECT
  USING (public.get_my_role() = 'admin');

CREATE POLICY "analytics_events: insert own"
  ON public.analytics_events FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

CREATE INDEX idx_analytics_events_name ON public.analytics_events(event_name);
CREATE INDEX idx_analytics_events_created ON public.analytics_events(created_at DESC);
