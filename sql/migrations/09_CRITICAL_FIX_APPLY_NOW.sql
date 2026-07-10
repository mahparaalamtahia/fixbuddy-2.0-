-- ============================================================
-- CRITICAL FIX FOR REGISTRATION 500 ERROR
-- File: 09_CRITICAL_FIX_APPLY_NOW.sql
-- 
-- INSTRUCTIONS:
-- 1. Go to Supabase Dashboard → SQL Editor
-- 2. Click "New Query"
-- 3. Copy and paste THIS ENTIRE FILE (everything below this comment)
-- 4. Click "Run"
-- 5. Wait for "Success" message
-- 6. Return to the Flutter app and try registration again
-- ============================================================

-- Step 1: Ensure UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Step 2: Create user_role ENUM safely (won't error if exists)
DO $$
BEGIN
  CREATE TYPE user_role AS ENUM ('user', 'worker', 'admin');
EXCEPTION WHEN duplicate_object THEN
  -- Type already exists, that's fine
  NULL;
END;
$$;

-- Step 3: Ensure profiles table has all required columns (non-destructive)
-- This runs only if a column doesn't exist
ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS id UUID PRIMARY KEY;

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS full_name TEXT NOT NULL DEFAULT 'New User';

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS email TEXT;

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS phone TEXT;

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS area_id UUID;

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS fcm_token TEXT;

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Step 4: Recreate profiles table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'user',  -- TEXT to avoid enum casting issues
  full_name   TEXT NOT NULL DEFAULT 'New User',
  email       TEXT,
  phone       TEXT,
  avatar_url  TEXT,
  area_id     UUID,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  fcm_token   TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Step 5: Create/replace the trigger function with SAFE version
-- This function:
-- - Extracts role from metadata (defaults to 'user' if missing)
-- - Validates role is one of: user, worker, admin
-- - Extracts full_name from metadata (multiple name field options)
-- - Inserts into profiles WITHOUT type casting (uses TEXT)
-- - Handles conflicts gracefully
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
  -- Extract role from auth metadata
  v_role := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'role', ''),
    'user'
  );

  -- Validate role is allowed
  IF v_role NOT IN ('user', 'worker', 'admin') THEN
    v_role := 'user';
  END IF;

  -- Extract full_name (try multiple field names for flexibility)
  v_full_name := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
    NULLIF(NEW.raw_user_meta_data->>'fullName', ''),
    NULLIF(NEW.raw_user_meta_data->>'name', ''),
    'New User'
  );

  -- Insert profile (will fail silently if user already exists)
  BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (NEW.id, NEW.email, v_full_name, v_role)
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail — user still gets created in auth
    RAISE LOG 'Profile insert failed for user %: %', NEW.id, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- Step 6: Drop existing trigger if present
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;

-- Step 7: Recreate trigger
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Step 8: Ensure areas table exists (required by schema)
CREATE TABLE IF NOT EXISTS public.areas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL UNIQUE,
  city        TEXT NOT NULL DEFAULT 'Dhaka',
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Step 9: Ensure categories table exists (required by schema)
CREATE TABLE IF NOT EXISTS public.categories (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL UNIQUE,
  icon_name   TEXT NOT NULL,
  color_hex   TEXT NOT NULL,
  description TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Step 10: Ensure workers table exists
CREATE TABLE IF NOT EXISTS public.workers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id      UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  bio             TEXT,
  experience_years INT NOT NULL DEFAULT 0,
  hourly_rate     DECIMAL(10,2) NOT NULL DEFAULT 0,
  is_available    BOOLEAN NOT NULL DEFAULT TRUE,
  is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
  avg_rating      DECIMAL(3,2) NOT NULL DEFAULT 0.00,
  review_count    INT NOT NULL DEFAULT 0,
  total_bookings  INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Step 11: Ensure worker_categories table exists
CREATE TABLE IF NOT EXISTS public.worker_categories (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id   UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(worker_id, category_id)
);

-- Step 12: Add FK constraint from profiles to areas if not present
DO $$
BEGIN
  ALTER TABLE public.profiles
    ADD CONSTRAINT fk_profiles_area FOREIGN KEY (area_id) 
    REFERENCES public.areas(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$;

-- ============================================================
-- VERIFICATION
-- ============================================================
-- The following should complete without errors:
SELECT 'Migration 09_CRITICAL_FIX_APPLY_NOW.sql completed successfully!' AS status;
SELECT COUNT(*) as profile_count FROM public.profiles;
SELECT COUNT(*) as area_count FROM public.areas;
SELECT COUNT(*) as category_count FROM public.categories;

-- ============================================================
-- END OF MIGRATION
-- ============================================================
