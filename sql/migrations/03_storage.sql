-- ============================================================
-- FixBuddy Storage Buckets & Policies
-- File: 03_storage.sql
-- Run AFTER 02_rls_policies.sql
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- BUCKET: avatars
-- Public read, authenticated write (own folder only)
-- Path convention: avatars/{user_id}/avatar.jpg
-- ────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  TRUE,
  5242880,   -- 5 MB max
  ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- Public read for avatars
CREATE POLICY "avatars: public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- Authenticated user uploads to their own folder
CREATE POLICY "avatars: owner upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Owner can update their own avatar
CREATE POLICY "avatars: owner update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Owner can delete their own avatar
CREATE POLICY "avatars: owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Admin can manage all avatars
CREATE POLICY "avatars: admin full"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'avatars'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ────────────────────────────────────────────────────────────
-- BUCKET: worker_docs
-- Private — only owner and admin can read
-- Path convention: worker_docs/{worker_profile_id}/{filename}
-- ────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'worker_docs',
  'worker_docs',
  FALSE,
  10485760,  -- 10 MB max
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
);

-- Owner reads own docs
CREATE POLICY "worker_docs: owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'worker_docs'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Owner uploads
CREATE POLICY "worker_docs: owner upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'worker_docs'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Owner deletes
CREATE POLICY "worker_docs: owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'worker_docs'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Admin full access to worker docs
CREATE POLICY "worker_docs: admin full"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'worker_docs'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ────────────────────────────────────────────────────────────
-- BUCKET: category_icons
-- Public read, admin write only
-- Path convention: category_icons/{category_id}.png
-- ────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'category_icons',
  'category_icons',
  TRUE,
  2097152,   -- 2 MB max
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml']
);

CREATE POLICY "category_icons: public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'category_icons');

CREATE POLICY "category_icons: admin write"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'category_icons'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "category_icons: admin update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'category_icons'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "category_icons: admin delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'category_icons'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );
