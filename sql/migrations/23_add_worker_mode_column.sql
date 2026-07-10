-- ============================================================
-- FixBuddy Migration: Add Worker Mode Column
-- File: 23_add_worker_mode_column.sql
-- Adds 'mode' column to workers table for seeking/providing toggle
-- ============================================================

-- Step 1: Add mode column to workers table
ALTER TABLE public.workers
  ADD COLUMN IF NOT EXISTS mode TEXT NOT NULL DEFAULT 'providing'
  CHECK (mode IN ('providing', 'seeking'));

-- Step 2: Create index for mode filtering
CREATE INDEX IF NOT EXISTS idx_workers_mode ON public.workers(mode);

-- Step 3: Update existing workers to have default mode
UPDATE public.workers SET mode = 'providing' WHERE mode IS NULL;

-- Verification
SELECT '23_add_worker_mode_column.sql applied successfully' AS status;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'workers' AND column_name = 'mode';