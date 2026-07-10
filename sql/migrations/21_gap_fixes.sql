-- 21_gap_fixes.sql

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='reviews' AND column_name='review_tags') THEN
        ALTER TABLE reviews ADD COLUMN review_tags TEXT[];
    END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'reviews'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE reviews';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'worker_availability_slots'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE worker_availability_slots';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'support_tickets'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE support_tickets';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_id ON notifications(recipient_id);
