-- ============================================================
-- Add Reviews Infrastructure (Idempotent)
-- File: 27_add_reviews_system.sql
-- ============================================================

-- 1. Ensure the reviews table exists
CREATE TABLE IF NOT EXISTS public.reviews (
  id          UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id  UUID    NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id     UUID    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  worker_id   UUID    NOT NULL REFERENCES public.workers(id)  ON DELETE CASCADE,
  rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  is_flagged  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Enable Row Level Security (RLS) safely
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- We use DO blocks to avoid errors if policies already exist
DO $$
BEGIN
  CREATE POLICY "Enable read access for all users"
    ON public.reviews FOR SELECT
    USING (auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  CREATE POLICY "Users can insert their own reviews"
    ON public.reviews FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  CREATE POLICY "Users can update their own reviews"
    ON public.reviews FOR UPDATE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  CREATE POLICY "Users can delete their own reviews"
    ON public.reviews FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

-- 3. Function to aggregate ratings and update the workers table
CREATE OR REPLACE FUNCTION public.update_worker_rating_and_review_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- A. Update the average rating and review count on the workers table
  UPDATE public.workers
  SET 
    avg_rating   = (SELECT COALESCE(AVG(rating), 0) FROM public.reviews WHERE worker_id = NEW.worker_id AND is_flagged = FALSE),
    review_count = (SELECT COUNT(*) FROM public.reviews WHERE worker_id = NEW.worker_id AND is_flagged = FALSE)
  WHERE id = NEW.worker_id;

  -- B. Update the booking's is_reviewed status
  UPDATE public.bookings
  SET is_reviewed = TRUE
  WHERE id = NEW.booking_id;

  RETURN NEW;
END;
$$;

-- 4. Recreate the trigger
DROP TRIGGER IF EXISTS trg_update_worker_rating ON public.reviews;

CREATE TRIGGER trg_update_worker_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.update_worker_rating_and_review_status();
