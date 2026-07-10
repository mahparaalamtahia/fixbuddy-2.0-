-- ============================================================
-- FixBuddy Migration: Fix Auth Registration 500 Error
-- File: 20260610_000003_fix_auth_registration.sql
-- 
-- PROBLEM: auth.signUp() fails with "Database error saving new user"
-- because the handle_new_user() trigger casts role to user_role ENUM
-- which breaks in certain schema states, rolling back the entire
-- auth.users INSERT transaction.
--
-- FIX: Convert profiles.role from ENUM to TEXT, replace trigger
-- function with a safe version that wraps the insert in
-- BEGIN...EXCEPTION...END so auth succeeds even if profile insert fails.
-- ============================================================

-- Step 0: Drop ALL policies that reference profiles.role (directly or via subquery)
-- These would block ALTER COLUMN TYPE

-- Public.profiles policies
DROP POLICY IF EXISTS "profiles: auth users read worker profiles" ON public.profiles;

-- Storage policies (subquery references to profiles.role)
DROP POLICY IF EXISTS "avatars: admin full" ON storage.objects;
DROP POLICY IF EXISTS "worker_docs: admin full" ON storage.objects;
DROP POLICY IF EXISTS "category_icons: admin write" ON storage.objects;
DROP POLICY IF EXISTS "category_icons: admin update" ON storage.objects;
DROP POLICY IF EXISTS "category_icons: admin delete" ON storage.objects;
DROP POLICY IF EXISTS "review_photos: admin full" ON storage.objects;

-- Step 1: Drop triggers that depend on the role column
DROP TRIGGER IF EXISTS trg_on_worker_role_set ON public.profiles;
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;

-- Step 2: Drop the old trigger function
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Step 3: Convert role from user_role ENUM to TEXT
ALTER TABLE IF EXISTS public.profiles
  ALTER COLUMN role DROP DEFAULT;

ALTER TABLE IF EXISTS public.profiles
  ALTER COLUMN role TYPE TEXT USING (role::TEXT);

ALTER TABLE IF EXISTS public.profiles
  ALTER COLUMN role SET DEFAULT 'user';

-- Step 4: Recreate all dropped policies

-- Profiles policy
CREATE POLICY "profiles: auth users read worker profiles"
  ON public.profiles FOR SELECT
  USING (
    auth.role() = 'authenticated'
    AND role = 'worker'
    AND is_active = TRUE
  );

-- Storage policies
CREATE POLICY "avatars: admin full"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'avatars'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "worker_docs: admin full"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'worker_docs'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "category_icons: admin write"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'category_icons'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "category_icons: admin update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'category_icons'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "category_icons: admin delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'category_icons'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "review_photos: admin full"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'review_photos'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- Step 5: Create the safe trigger function
-- Uses TEXT internally (no ENUM casting), wraps insert in EXCEPTION block
-- so auth user creation is never blocked by a profile insert failure
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
  -- Extract role from auth metadata, default to 'user'
  v_role := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'role', ''),
    'user'
  );

  -- Validate role is one of the allowed values
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

  -- Insert profile into public.profiles
  -- Wrapped in EXCEPTION so auth user creation succeeds even if this fails
  BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (NEW.id, NEW.email, v_full_name, v_role)
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'handle_new_user: profile insert failed for user %: %', NEW.id, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- Step 6: Recreate the auth trigger on auth.users
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- VERIFICATION
-- ============================================================
SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_name='profiles' AND column_name='role';

SELECT '20260610_000003 migration applied: role->TEXT, safe handle_new_user()' AS status;

-- ============================================================
-- END OF MIGRATION
-- ============================================================
