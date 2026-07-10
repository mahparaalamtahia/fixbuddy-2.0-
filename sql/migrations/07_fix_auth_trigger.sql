-- ============================================================
-- FixBuddy Auth Registration Fix
-- File: 07_fix_auth_trigger.sql
-- Fixes "Database error saving new user" (500) during signup
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- STEP 1: Create ENUM if missing (catch error if already exists)
-- ────────────────────────────────────────────────────────────
DO $$
BEGIN
  CREATE TYPE user_role AS ENUM ('user', 'worker', 'admin');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

-- ────────────────────────────────────────────────────────────
-- STEP 2: Ensure the profiles table exists (using TEXT for role
-- so it works even without the ENUM — we'll ALTER later)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id                UUID PRIMARY KEY,
  role              TEXT              NOT NULL DEFAULT 'user',
  full_name         TEXT              NOT NULL,
  email             TEXT              NOT NULL,
  phone             TEXT,
  avatar_url        TEXT,
  area_id           UUID,
  is_active         BOOLEAN           NOT NULL DEFAULT TRUE,
  fcm_token         TEXT,
  created_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- Add phone column if missing (safety for partial runs)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;

-- ────────────────────────────────────────────────────────────
-- STEP 3: Re-create the trigger function
-- Uses TEXT internally instead of user_role to avoid
-- dependency on the ENUM type at function creation time.
-- Casting to user_role happens at INSERT time.
-- ────────────────────────────────────────────────────────────
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
  -- Safely parse role from metadata
  v_role := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'role', ''),
    'user'
  );

  -- Validate that role is one of the allowed values
  IF v_role NOT IN ('user', 'worker', 'admin') THEN
    v_role := 'user';
  END IF;

  -- Safely parse full_name from metadata
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

-- ────────────────────────────────────────────────────────────
-- STEP 4: Drop and re-create the trigger
-- ────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;

CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ────────────────────────────────────────────────────────────
-- STEP 5: Verify the fix
-- ────────────────────────────────────────────────────────────
SELECT '07_fix_auth_trigger.sql completed successfully' AS status;
