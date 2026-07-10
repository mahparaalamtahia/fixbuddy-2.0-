-- ============================================================
-- Fix Worker Registration Issue
-- File: 11_FIX_WORKER_TRIGGER.sql
-- 
-- Restores the handle_worker_profile trigger that was deleted 
-- in migration 10 when converting the role column to TEXT.
-- Without this, workers don't get a row in the workers table.
-- ============================================================

-- Step 1: Re-create the function cleanly handling TG_OP
CREATE OR REPLACE FUNCTION public.handle_worker_profile()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.role = 'worker' THEN
      INSERT INTO public.workers (profile_id)
      VALUES (NEW.id)
      ON CONFLICT (profile_id) DO NOTHING;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.role = 'worker' AND OLD.role IS DISTINCT FROM 'worker' THEN
      INSERT INTO public.workers (profile_id)
      VALUES (NEW.id)
      ON CONFLICT (profile_id) DO NOTHING;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Step 2: Re-create the trigger on public.profiles
DROP TRIGGER IF EXISTS trg_on_worker_role_set ON public.profiles;

CREATE TRIGGER trg_on_worker_role_set
  AFTER INSERT OR UPDATE OF role ON public.profiles
  FOR EACH ROW 
  EXECUTE FUNCTION public.handle_worker_profile();

-- Verification
SELECT 'Migration 11_FIX_WORKER_TRIGGER.sql completed successfully!' AS status;
