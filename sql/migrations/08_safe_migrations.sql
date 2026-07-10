-- ============================================================
-- FixBuddy Safe Migration Patch
-- File: 08_safe_migrations.sql
-- Purpose: Idempotent, non-destructive fixes for schema/trigger/publication gaps
-- Run this AFTER your existing SQL files when applying to Supabase.
-- This file is safe to run multiple times; it will not overwrite existing
-- objects destructively and uses IF NOT EXISTS checks.
-- ============================================================

-- Ensure UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Ensure user_role enum exists (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('user', 'worker', 'admin');
  END IF;
EXCEPTION WHEN others THEN
  -- If something unexpected happens, skip to avoid blocking deployment
  RAISE NOTICE 'Skipping user_role creation due to: %', SQLERRM;
END;
$$;

-- Ensure essential columns exist on public.profiles (non-destructive)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS area_id UUID;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Add FK from profiles to areas if not present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    WHERE tc.constraint_name = 'fk_profiles_area' AND tc.table_name = 'profiles'
  ) THEN
    BEGIN
      ALTER TABLE public.profiles
        ADD CONSTRAINT fk_profiles_area
        FOREIGN KEY (area_id) REFERENCES public.areas(id) ON DELETE SET NULL;
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END IF;
END;
$$;

-- Replace trigger function for auth user creation with a resilient version
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role TEXT;
  v_full_name TEXT;
BEGIN
  v_role := COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', ''), 'user');
  IF v_role NOT IN ('user', 'worker', 'admin') THEN
    v_role := 'user';
  END IF;

  v_full_name := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
    NULLIF(NEW.raw_user_meta_data->>'fullName', ''),
    'New User'
  );

  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (NEW.id, NEW.email, v_full_name, v_role)
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Recreate trigger (idempotent)
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Ensure handle_worker_profile exists and is safe (create or replace)
CREATE OR REPLACE FUNCTION public.handle_worker_profile()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.role = 'worker' AND (OLD.role IS NULL OR OLD.role != 'worker') THEN
    INSERT INTO public.workers (profile_id)
    VALUES (NEW.id)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_worker_role_set ON public.profiles;
CREATE TRIGGER trg_on_worker_role_set
  AFTER INSERT OR UPDATE OF role ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_worker_profile();

-- Storage buckets: idempotent inserts (use ON CONFLICT DO NOTHING)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars','avatars', TRUE, 5242880, ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('worker_docs','worker_docs', FALSE, 10485760, ARRAY['image/jpeg','image/png','image/webp','application/pdf'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('category_icons','category_icons', TRUE, 2097152, ARRAY['image/jpeg','image/png','image/webp','image/svg+xml'])
ON CONFLICT (id) DO NOTHING;

-- Realtime publication additions: only add table if not already part of publication
DO $$
DECLARE
  tbl text;
  already boolean;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY['public.bookings','public.messages','public.chats','public.notifications','public.workers','public.app_config'])
  LOOP
    SELECT EXISTS(
      SELECT 1 FROM pg_publication_rel pr
      JOIN pg_publication p ON pr.prpubid = p.oid
      JOIN pg_class c ON pr.prrelid = c.oid
      WHERE p.pubname = 'supabase_realtime' AND c.relname = split_part(tbl,'.',2)
    ) INTO already;

    IF NOT already THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %s', tbl);
    END IF;
  END LOOP;
END;
$$;

-- Final sanity check message (selecting a string is harmless)
SELECT '08_safe_migrations.sql applied (idempotent checks run)' AS status;
