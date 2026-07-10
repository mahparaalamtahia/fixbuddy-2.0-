-- ============================================================
-- Support Multiple Service Areas for Workers
-- File: 13_WORKER_AREAS.sql
-- ============================================================

-- 1. Create worker_areas table
CREATE TABLE IF NOT EXISTS public.worker_areas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id   UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
  area_id     UUID NOT NULL REFERENCES public.areas(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(worker_id, area_id)
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_worker_areas_wid ON public.worker_areas(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_areas_aid ON public.worker_areas(area_id);

-- 3. Enable RLS
ALTER TABLE public.worker_areas ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can read worker areas
CREATE POLICY "worker_areas: public read"
  ON public.worker_areas FOR SELECT
  USING (true);

-- Policy: Worker can manage their own areas
CREATE POLICY "worker_areas: worker manage own"
  ON public.worker_areas FOR ALL
  USING (worker_id = public.get_my_worker_id());

-- Policy: Admin full access
CREATE POLICY "worker_areas: admin full"
  ON public.worker_areas FOR ALL
  USING (public.get_my_role() = 'admin');

-- 4. Data Migration: Copy existing area_id from profiles to worker_areas
INSERT INTO public.worker_areas (worker_id, area_id)
SELECT w.id, p.area_id
FROM public.workers w
JOIN public.profiles p ON w.profile_id = p.id
WHERE p.area_id IS NOT NULL
ON CONFLICT (worker_id, area_id) DO NOTHING;

-- Note: We are keeping the area_id column in profiles because:
-- 1. Seekers still need a primary area.
-- 2. It acts as the "primary/default" area for a worker.

SELECT 'Migration 13_WORKER_AREAS.sql completed successfully!' AS status;
