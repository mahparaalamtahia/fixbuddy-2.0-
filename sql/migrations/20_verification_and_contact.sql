-- ============================================================
-- FixBuddy Migration: Verification and Contact updates
-- File: 20_verification_and_contact.sql
-- ============================================================

DO $$
BEGIN
  -- We need to ensure realtime is enabled for worker_documents.
  -- PostgreSQL allows altering publication multiple times safely if we check if it's already in the publication.
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'worker_documents'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.worker_documents;
  END IF;
END $$;
