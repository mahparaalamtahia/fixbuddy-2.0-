-- 28_admin_role_security.sql
-- Description: Prevent admins from overwriting personal profile data (full_name, phone, avatar_url) during an administrative sync.

-- 1. Create a function to prevent admin profile overwrite
CREATE OR REPLACE FUNCTION public.prevent_admin_profile_overwrite()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if the user performing the update is an admin
  -- We assume role is checked via auth.jwt() or the user's role in the DB.
  -- In Supabase, if the user's JWT claims they are admin, or if we want to be strict against ANY service role or admin client:
  
  -- If this is an administrative update (e.g. by service_role or an admin user)
  -- But we also want to allow users to update their own profiles.
  -- The simplest way is to check if the current user ID matches the row ID.
  -- If auth.uid() != NEW.id (meaning someone else is updating the row),
  -- we must restrict changes to personal fields.
  
  IF auth.uid() IS NULL OR auth.uid() != NEW.id THEN
    -- It's an administrative update (Admin or Service Role)
    IF NEW.full_name IS DISTINCT FROM OLD.full_name OR
       NEW.phone IS DISTINCT FROM OLD.phone OR
       NEW.avatar_url IS DISTINCT FROM OLD.avatar_url THEN
       
      RAISE EXCEPTION '403 Period/Policy Violation: Administrative updates cannot modify personal profile fields (full_name, phone, avatar_url).';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop the trigger if it exists
DROP TRIGGER IF EXISTS trg_prevent_admin_profile_overwrite ON public.profiles;

-- 3. Create the trigger on the profiles table
CREATE TRIGGER trg_prevent_admin_profile_overwrite
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_admin_profile_overwrite();
