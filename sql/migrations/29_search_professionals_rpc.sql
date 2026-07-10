-- Migration 29: Create search_professionals RPC for robust searching

CREATE OR REPLACE FUNCTION search_professionals(
    p_search_query TEXT DEFAULT NULL,
    p_category_id UUID DEFAULT NULL,
    p_area_id UUID DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'top_rated',
    p_limit INT DEFAULT 10,
    p_offset INT DEFAULT 0
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT jsonb_build_object(
        'id', w.id,
        'profile_id', w.profile_id,
        'bio', w.bio,
        'experience_years', w.experience_years,
        'hourly_rate', w.hourly_rate,
        'is_available', w.is_available,
        'is_verified', w.is_verified,
        'avg_rating', w.avg_rating,
        'review_count', w.review_count,
        'total_bookings', w.total_bookings,
        'mode', w.mode,
        'created_at', w.created_at,
        'profiles', jsonb_build_object(
            'full_name', p.full_name,
            'email', p.email,
            'phone', p.phone,
            'avatar_url', p.avatar_url,
            'area_id', p.area_id,
            'areas', CASE WHEN pa.id IS NOT NULL THEN jsonb_build_object('name', pa.name) ELSE NULL END
        ),
        'worker_categories', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'category_id', wc.category_id,
                    'categories', jsonb_build_object(
                        'name', c.name,
                        'icon_name', c.icon_name,
                        'color_hex', c.color_hex
                    )
                )
            )
            FROM worker_categories wc
            JOIN categories c ON c.id = wc.category_id
            WHERE wc.worker_id = w.id
        ), '[]'::jsonb),
        'worker_skills', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object('skill', ws.skill)
            )
            FROM worker_skills ws
            WHERE ws.worker_id = w.id
        ), '[]'::jsonb),
        'worker_areas', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'area_id', wa.area_id,
                    'areas', jsonb_build_object('name', a.name)
                )
            )
            FROM worker_areas wa
            JOIN areas a ON a.id = wa.area_id
            WHERE wa.worker_id = w.id
        ), '[]'::jsonb)
    )
    FROM workers w
    JOIN profiles p ON p.id = w.profile_id
    LEFT JOIN areas pa ON pa.id = p.area_id
    WHERE w.is_available = true
    AND (
        p_search_query IS NULL 
        OR p_search_query = ''
        OR p.full_name ILIKE '%' || p_search_query || '%' 
        OR w.bio ILIKE '%' || p_search_query || '%'
        OR EXISTS (
            SELECT 1 FROM worker_skills ws WHERE ws.worker_id = w.id AND ws.skill ILIKE '%' || p_search_query || '%'
        )
        OR EXISTS (
            SELECT 1 FROM worker_categories wc JOIN categories c ON c.id = wc.category_id WHERE wc.worker_id = w.id AND c.name ILIKE '%' || p_search_query || '%'
        )
        OR EXISTS (
            SELECT 1 FROM worker_areas wa JOIN areas a ON a.id = wa.area_id WHERE wa.worker_id = w.id AND a.name ILIKE '%' || p_search_query || '%'
        )
    )
    AND (
        p_category_id IS NULL
        OR EXISTS (
            SELECT 1 FROM worker_categories wc WHERE wc.worker_id = w.id AND wc.category_id = p_category_id
        )
    )
    AND (
        p_area_id IS NULL
        OR EXISTS (
            SELECT 1 FROM worker_areas wa WHERE wa.worker_id = w.id AND wa.area_id = p_area_id
        )
    )
    ORDER BY 
        CASE WHEN p_sort_by = 'top_rated' THEN w.avg_rating END DESC NULLS LAST,
        CASE WHEN p_sort_by = 'lowest_price' THEN w.hourly_rate END ASC NULLS LAST,
        CASE WHEN p_sort_by = 'newest' THEN w.created_at END DESC NULLS LAST,
        CASE WHEN p_sort_by = 'most_reviewed' THEN w.review_count END DESC NULLS LAST,
        w.avg_rating DESC NULLS LAST
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;
