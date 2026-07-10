ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS notification_prefs JSONB
  DEFAULT '{"booking_alerts": true, "registration_alerts": true, "review_alerts": true}'::jsonb;
