-- ============================================================
-- FixBuddy Migration: 22_profile_photos_verification.sql
-- ============================================================

-- Ensure avatar_url exists in profiles (should already exist per 01_tables.sql)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'avatar_url'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN avatar_url TEXT;
    END IF;
END $$;

-- Enable real-time for worker_documents (the existing verification table)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE public.worker_documents;
EXCEPTION WHEN OTHERS THEN
  -- Ignore if it wasn't there
END $$;
ALTER PUBLICATION supabase_realtime ADD TABLE public.worker_documents;

-- Ensure worker_documents table has the needed check constraint on status
-- (It already has it from 20260607_020347_add_worker_documents.sql, but we can't easily alter check constraints idempotently without dropping, so we'll rely on the existing one which allows 'pending', 'verified', 'rejected').

-- Enable real-time for profiles if not already enabled
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE public.profiles;
EXCEPTION WHEN OTHERS THEN
END $$;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;

-- Ensure worker_documents policies match the requirements:
-- Workers cannot update their own rows after insert (already handled because we only have INSERT, SELECT, DELETE for workers in the original migration).
-- Wait, let's explicitly add a policy to prevent worker updates if missing.
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'worker_documents' 
        AND policyname = 'worker_documents: admin update'
    ) THEN
        CREATE POLICY "worker_documents: admin update"
        ON public.worker_documents FOR UPDATE
        USING (public.get_my_role() = 'admin');
    END IF;
END $$;
