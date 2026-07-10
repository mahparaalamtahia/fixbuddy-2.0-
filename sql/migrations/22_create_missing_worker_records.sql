-- ============================================================
-- FixBuddy Migration: Create Missing Worker Records & Trigger
-- File: 22_create_missing_worker_records.sql
-- Fixes: PGRST116 error when worker logs in (worker record missing)
-- ============================================================

-- Step 1: Backfill worker records for existing profiles with role='worker'
-- that don't have a corresponding workers row
INSERT INTO public.workers (profile_id)
SELECT p.id
FROM public.profiles p
LEFT JOIN public.workers w ON w.profile_id = p.id
WHERE p.role = 'worker'
  AND w.id IS NULL
ON CONFLICT (profile_id) DO NOTHING;

-- Step 2: Create/recreate the trigger function to auto-create worker record
-- when profile role is set to 'worker'
CREATE OR REPLACE FUNCTION public.handle_worker_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.role = 'worker' AND (OLD.role IS NULL OR OLD.role != 'worker') THEN
    INSERT INTO public.workers (profile_id)
    VALUES (NEW.id)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

-- Step 3: Recreate the trigger on profiles table
DROP TRIGGER IF EXISTS trg_on_worker_role_set ON public.profiles;

CREATE TRIGGER trg_on_worker_role_set
  AFTER INSERT OR UPDATE OF role ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_worker_profile();

-- Step 4: Verification
SELECT 'Backfill complete. Workers created:' AS status,
       COUNT(*) AS count
FROM public.workers w
JOIN public.profiles p ON p.id = w.profile_id
WHERE p.role = 'worker';

SELECT '22_create_missing_worker_records.sql applied successfully' AS status;