-- ============================================================
-- Fix Orphaned Accounts and Missing Rows
-- File: 12_REPAIR_ORPHANED_ACCOUNTS.sql
-- 
-- Repairs any auth.users that failed to get a profiles row
-- due to previous enum casting errors, and repairs any worker 
-- profiles that failed to get a workers row due to the missing trigger.
-- ============================================================

-- Step 1: Create missing profile rows for existing auth.users
INSERT INTO public.profiles (id, email, full_name, role)
SELECT 
  u.id, 
  u.email, 
  COALESCE(
    NULLIF(u.raw_user_meta_data->>'full_name', ''), 
    NULLIF(u.raw_user_meta_data->>'fullName', ''), 
    NULLIF(u.raw_user_meta_data->>'name', ''), 
    'User'
  ), 
  COALESCE(
    NULLIF(u.raw_user_meta_data->>'role', ''), 
    'user'
  )
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- Step 2: Create missing worker rows for profiles with role 'worker'
INSERT INTO public.workers (profile_id)
SELECT p.id 
FROM public.profiles p
LEFT JOIN public.workers w ON p.id = w.profile_id
WHERE p.role = 'worker' AND w.id IS NULL
ON CONFLICT (profile_id) DO NOTHING;

-- Verification
SELECT 'Migration 12_REPAIR_ORPHANED_ACCOUNTS.sql completed successfully!' AS status;
SELECT COUNT(*) AS repaired_profiles FROM public.profiles p JOIN auth.users u ON p.id = u.id WHERE p.created_at > NOW() - INTERVAL '1 minute';
