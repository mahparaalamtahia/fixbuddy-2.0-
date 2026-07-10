-- ============================================================
-- FixBuddy Realtime Configuration
-- File: 06_realtime.sql
-- Run LAST (after 05_seed_data.sql)
-- ============================================================

-- Enable Realtime publication for required tables
-- These tables need live data streaming in the Flutter app

ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.workers;
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_config;

-- Note: categories and areas do NOT need realtime as they
-- change rarely and can be refetched on app resume.
