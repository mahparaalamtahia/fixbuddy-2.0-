-- ============================================================
-- FixBuddy Database Audit Patches
-- File: 21_assign_admin_role.sql
-- ============================================================

-- Ensure the 'role' column exists in 'profiles'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'profiles' 
          AND column_name = 'role'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN role text DEFAULT 'user';
    END IF;
END $$;

-- Assign admin role to ramim123@gmail.com
UPDATE public.profiles
SET role = 'admin'
WHERE id = '26f22055-7c86-41bd-bda4-a4249c2fe1f6';
