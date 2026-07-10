-- ============================================================
-- FixBuddy Migration: Review Photos
-- File: 20260607_020348_add_review_photos.sql
-- Run AFTER 20260607_020347_add_worker_documents.sql
-- ============================================================
-- This migration adds a table for review photo attachments
-- Depends on: 01_tables.sql (reviews table), 03_storage.sql (needs new bucket)
-- Order: Run after all initial schema migrations and worker_documents

-- ────────────────────────────────────────────────────────────
-- BUCKET: review_photos
-- Public read, authenticated write (own folder only)
-- Path convention: review_photos/{review_id}/{filename}
-- ────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'review_photos',
  'review_photos',
  TRUE,
  5242880,   -- 5 MB max
  ARRAY['image/jpeg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Public read for review photos
CREATE POLICY "review_photos: public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'review_photos');

-- Authenticated user uploads to review folder
CREATE POLICY "review_photos: owner upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'review_photos'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Owner can delete their own review photos
CREATE POLICY "review_photos: owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'review_photos'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Admin can manage all
CREATE POLICY "review_photos: admin full"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'review_photos'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ────────────────────────────────────────────────────────────
-- TABLE: review_photos
-- Metadata for photos attached to reviews
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.review_photos (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  review_id     UUID NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  file_name     TEXT NOT NULL,
  file_path     TEXT NOT NULL,
  file_size     BIGINT NOT NULL,
  mime_type     TEXT NOT NULL,
  sort_order    INT NOT NULL DEFAULT 0,
  uploaded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.review_photos ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read photos of non-flagged reviews
CREATE POLICY "review_photos: auth read non-flagged"
  ON public.review_photos FOR SELECT
  USING (
    auth.role() = 'authenticated'
    AND EXISTS (
      SELECT 1 FROM public.reviews r
      WHERE r.id = review_photos.review_id
        AND r.is_flagged = FALSE
    )
  );

-- Review author can manage their photos
CREATE POLICY "review_photos: author write"
  ON public.review_photos FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.reviews r
      WHERE r.id = review_photos.review_id
        AND r.user_id = auth.uid()
    )
  );

-- Admin full access
CREATE POLICY "review_photos: admin full"
  ON public.review_photos FOR ALL
  USING (public.get_my_role() = 'admin');

-- Indexes
CREATE INDEX idx_review_photos_review ON public.review_photos(review_id);
