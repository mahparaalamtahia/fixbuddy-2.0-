-- ============================================================
-- FixBuddy Migration: Fix Storage RLS Policies (Migration Gap)
-- File: 24_fix_storage_rls_policies.sql
-- ============================================================
-- The initial storage policies expected the file path `name` to 
-- start directly with the `userId` (e.g. `user_id/avatar.png`). 
-- However, older client SDK calls often prefixed the path with 
-- the bucket name (e.g. `avatars/user_id/avatar.png`), causing 
-- `(storage.foldername(name))[1]` to equal `'avatars'`, resulting 
-- in a 403 Unauthorized error for all authenticated uploads.
--
-- This migration hardens the policies to check BOTH the first 
-- and second segments of the path array to ensure uploads succeed 
-- regardless of whether the bucket prefix is included.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Avatars Bucket
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "avatars: owner upload" ON storage.objects;
DROP POLICY IF EXISTS "avatars: owner update" ON storage.objects;
DROP POLICY IF EXISTS "avatars: owner delete" ON storage.objects;

CREATE POLICY "avatars: owner upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      auth.uid()::TEXT = (storage.foldername(name))[1]
      OR auth.uid()::TEXT = (storage.foldername(name))[2]
    )
  );

CREATE POLICY "avatars: owner update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND (
      auth.uid()::TEXT = (storage.foldername(name))[1]
      OR auth.uid()::TEXT = (storage.foldername(name))[2]
    )
  );

CREATE POLICY "avatars: owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND (
      auth.uid()::TEXT = (storage.foldername(name))[1]
      OR auth.uid()::TEXT = (storage.foldername(name))[2]
    )
  );


-- ────────────────────────────────────────────────────────────
-- 2. Worker Docs Bucket
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "worker_docs: owner read" ON storage.objects;
DROP POLICY IF EXISTS "worker_docs: owner upload" ON storage.objects;
DROP POLICY IF EXISTS "worker_docs: owner delete" ON storage.objects;

CREATE POLICY "worker_docs: owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'worker_docs'
    AND (
      auth.uid()::TEXT = (storage.foldername(name))[1]
      OR auth.uid()::TEXT = (storage.foldername(name))[2]
    )
  );

CREATE POLICY "worker_docs: owner upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'worker_docs'
    AND (
      auth.uid()::TEXT = (storage.foldername(name))[1]
      OR auth.uid()::TEXT = (storage.foldername(name))[2]
    )
  );

CREATE POLICY "worker_docs: owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'worker_docs'
    AND (
      auth.uid()::TEXT = (storage.foldername(name))[1]
      OR auth.uid()::TEXT = (storage.foldername(name))[2]
    )
  );


-- ────────────────────────────────────────────────────────────
-- 3. Review Photos Bucket
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "review_photos: owner upload" ON storage.objects;
DROP POLICY IF EXISTS "review_photos: owner delete" ON storage.objects;

CREATE POLICY "review_photos: owner upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'review_photos'
    AND (
      auth.uid()::TEXT = (storage.foldername(name))[1]
      OR auth.uid()::TEXT = (storage.foldername(name))[2]
    )
  );

CREATE POLICY "review_photos: owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'review_photos'
    AND (
      auth.uid()::TEXT = (storage.foldername(name))[1]
      OR auth.uid()::TEXT = (storage.foldername(name))[2]
    )
  );

-- ============================================================
-- END OF MIGRATION
-- ============================================================
