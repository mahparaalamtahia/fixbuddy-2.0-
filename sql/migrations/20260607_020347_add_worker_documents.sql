-- ============================================================
-- FixBuddy Migration: Worker Verification Documents
-- File: 20260607_020347_add_worker_documents.sql
-- Run AFTER 20260607_020346_add_booking_status_history.sql
-- ============================================================
-- This migration adds a table for worker verification documents metadata
-- Depends on: 01_tables.sql (workers table), 03_storage.sql (worker_docs bucket)
-- Order: Run after all initial schema migrations and booking_status_history

-- ────────────────────────────────────────────────────────────
-- TABLE: worker_documents
-- Metadata for uploaded verification documents
-- Files stored in worker_docs bucket under worker_id folder
-- ────────────────────────────────────────────────────────────
CREATE TYPE document_type AS ENUM ('nid', 'trade_license', 'certificate', 'other');

CREATE TABLE public.worker_documents (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id       UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
  document_type   document_type NOT NULL DEFAULT 'other',
  file_name       TEXT NOT NULL,
  file_path       TEXT NOT NULL,  -- Full path in storage bucket
  file_size       BIGINT NOT NULL,
  mime_type       TEXT NOT NULL,
  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified_at     TIMESTAMPTZ,
  verified_by     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected')),
  rejection_reason TEXT
);

-- Enable RLS
ALTER TABLE public.worker_documents ENABLE ROW LEVEL SECURITY;

-- Worker reads own documents
CREATE POLICY "worker_documents: worker read own"
  ON public.worker_documents FOR SELECT
  USING (worker_id = public.get_my_worker_id());

-- Worker uploads own documents
CREATE POLICY "worker_documents: worker insert own"
  ON public.worker_documents FOR INSERT
  WITH CHECK (worker_id = public.get_my_worker_id());

-- Worker can delete own documents (if not verified)
CREATE POLICY "worker_documents: worker delete own"
  ON public.worker_documents FOR DELETE
  USING (
    worker_id = public.get_my_worker_id()
    AND status = 'pending'
  );

-- Admin reads all
CREATE POLICY "worker_documents: admin read all"
  ON public.worker_documents FOR SELECT
  USING (public.get_my_role() = 'admin');

-- Admin updates (verify/reject)
CREATE POLICY "worker_documents: admin update"
  ON public.worker_documents FOR UPDATE
  USING (public.get_my_role() = 'admin');

-- Indexes
CREATE INDEX idx_worker_documents_worker ON public.worker_documents(worker_id);
CREATE INDEX idx_worker_documents_status ON public.worker_documents(status);
