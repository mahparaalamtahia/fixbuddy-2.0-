-- Migration 28: Create highly optimized views for the Admin Directory Dashboard

-- Worker Directory View
CREATE OR REPLACE VIEW admin_worker_directory_view AS
SELECT 
    w.id AS worker_id,
    p.id AS profile_id,
    p.full_name,
    p.email,
    p.phone,
    p.avatar_url,
    w.is_verified,
    w.is_available,
    w.experience_years,
    w.hourly_rate,
    w.mode,
    w.avg_rating,
    
    -- Booking aggregations
    COUNT(b.id) FILTER (WHERE b.status = 'confirmed' OR b.status = 'in_progress') AS active_orders_count,
    COUNT(b.id) FILTER (WHERE b.status = 'pending') AS pending_orders_count,
    COUNT(b.id) FILTER (WHERE b.status = 'completed') AS completed_orders_count,
    COALESCE(SUM(b.total_amount) FILTER (WHERE b.status = 'completed'), 0) AS total_earnings,
    
    -- Array aggregations for easy filtering in Supabase .contains() or .cs()
    ARRAY_AGG(DISTINCT c.name) AS categories,
    ARRAY_AGG(DISTINCT a.name) AS areas,
    
    -- Text search vector for blazing fast .ilike() / FTS
    (p.full_name || ' ' || p.email || ' ' || COALESCE(p.phone, '')) AS search_text
FROM 
    workers w
JOIN 
    profiles p ON w.profile_id = p.id
LEFT JOIN 
    bookings b ON w.id = b.worker_id
LEFT JOIN 
    worker_categories wc ON w.id = wc.worker_id
LEFT JOIN 
    categories c ON wc.category_id = c.id
LEFT JOIN 
    worker_areas wa ON w.id = wa.worker_id
LEFT JOIN 
    areas a ON wa.area_id = a.id
GROUP BY 
    w.id, p.id;

-- User Directory View
CREATE OR REPLACE VIEW admin_user_directory_view AS
SELECT 
    p.id AS profile_id,
    p.full_name,
    p.email,
    p.phone,
    p.avatar_url,
    p.is_active,
    p.created_at,
    
    -- Booking aggregations
    COUNT(b.id) FILTER (WHERE b.status = 'confirmed' OR b.status = 'in_progress') AS active_requests_count,
    COUNT(b.id) FILTER (WHERE b.status = 'pending') AS pending_requests_count,
    COUNT(b.id) FILTER (WHERE b.status = 'completed') AS completed_requests_count,
    COALESCE(SUM(b.total_amount) FILTER (WHERE b.status = 'completed'), 0) AS total_spent,
    
    (p.full_name || ' ' || p.email || ' ' || COALESCE(p.phone, '')) AS search_text
FROM 
    profiles p
LEFT JOIN 
    bookings b ON p.id = b.user_id
WHERE 
    p.role = 'user'
GROUP BY 
    p.id;
