-- ============================================================
-- FINAL FIX: Convert role column from ENUM to TEXT
-- File: 10_FINAL_FIX_ENUM_TO_TEXT.sql
-- 
-- THIS IS THE DEFINITIVE FIX - run this if 09 didn't fully work
-- Converts the user_role enum column to TEXT to fix type casting errors
-- ============================================================

-- Step 0: DROP ALL TRIGGERS THAT USE THE ROLE COLUMN
DROP TRIGGER IF EXISTS trg_on_worker_role_set ON public.profiles;
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;

-- Step 1: Ensure we can handle the role column properly
ALTER TABLE public.profiles
  ALTER COLUMN role DROP DEFAULT;

-- Step 2: Convert role from user_role ENUM to TEXT
ALTER TABLE public.profiles
  ALTER COLUMN role TYPE TEXT USING (role::TEXT);

-- Step 3: Re-apply the default
ALTER TABLE public.profiles
  ALTER COLUMN role SET DEFAULT 'user';

-- Step 4: Replace the trigger function with proper TEXT handling
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

-- Step 5: Recreate trigger
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;

CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- VERIFICATION
-- ============================================================
SELECT 'Migration 10_FINAL_FIX_ENUM_TO_TEXT.sql completed successfully!' AS status;
SELECT column_name, data_type FROM information_schema.columns 
  WHERE table_name='profiles' AND column_name='role';

-- ============================================================
-- END OF MIGRATION
-- ============================================================
