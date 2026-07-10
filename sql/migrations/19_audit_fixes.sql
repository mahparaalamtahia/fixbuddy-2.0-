-- ============================================================
-- FixBuddy Audit Fixes
-- File: 19_audit_fixes.sql
-- ============================================================

-- 1. Add missing category_id to workers table
ALTER TABLE public.workers
ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL;

-- 2. Add missing UPDATE policy for support_tickets (Admin)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'support_tickets' AND policyname = 'Admins can update tickets'
  ) THEN
    CREATE POLICY "Admins can update tickets"
      ON public.support_tickets
      FOR UPDATE
      USING (public.get_my_role() = 'admin');
  END IF;
END $$;

-- 3. Add missing UPDATE policy for worker_documents (Worker)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'worker_documents' AND policyname = 'worker_documents: worker update own'
  ) THEN
    CREATE POLICY "worker_documents: worker update own"
      ON public.worker_documents
      FOR UPDATE
      USING (worker_id = public.get_my_worker_id());
  END IF;
END $$;

-- 4. Add missing RPC for get_available_slots
CREATE OR REPLACE FUNCTION public.get_available_slots(p_worker_id UUID, p_date DATE)
RETURNS TABLE (
  period availability_period,
  is_available BOOLEAN
) LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT period, is_available
  FROM public.worker_availability_slots
  WHERE worker_id = p_worker_id
    AND day_of_week = EXTRACT(DOW FROM p_date)::smallint;
$$;
