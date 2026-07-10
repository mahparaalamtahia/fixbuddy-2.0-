-- ============================================================
-- FixBuddy Admin Dashboard Metrics
-- File: 22_admin_dashboard_metrics.sql
-- ============================================================

-- Function to aggregate real-time admin statistics
-- Uses SECURITY DEFINER to allow admin metrics reading across tables 
-- without directly exposing RLS policies on row counts.

DROP FUNCTION IF EXISTS get_admin_stats();

CREATE OR REPLACE FUNCTION get_admin_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    res jsonb;
BEGIN
    SELECT jsonb_build_object(
        'total_users', (SELECT count(*) FROM public.profiles WHERE role = 'user'),
        'total_workers', (SELECT count(*) FROM public.workers),
        'total_bookings', (SELECT count(*) FROM public.bookings),
        'bookings_today', (SELECT count(*) FROM public.bookings WHERE created_at >= CURRENT_DATE),
        'pending_approvals', (SELECT count(*) FROM public.workers WHERE is_verified = FALSE),
        'completed_bookings', (SELECT count(*) FROM public.bookings WHERE status = 'completed'),
        'active_categories', (SELECT count(*) FROM public.categories WHERE is_active = TRUE),
        'active_areas', (SELECT count(*) FROM public.areas WHERE is_active = TRUE)
    ) INTO res;
    
    RETURN res;
END;
$$;
