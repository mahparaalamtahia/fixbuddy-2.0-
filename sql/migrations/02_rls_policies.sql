-- ============================================================
-- FixBuddy Row Level Security Policies
-- File: 02_rls_policies.sql
-- Run AFTER 01_tables.sql
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- HELPER FUNCTION: get current user role
-- Used in RLS policies to avoid repeated subqueries
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- ────────────────────────────────────────────────────────────
-- HELPER FUNCTION: get worker id from profile id
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_worker_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT id FROM public.workers WHERE profile_id = auth.uid();
$$;

-- ════════════════════════════════
-- TABLE: profiles
-- ════════════════════════════════
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Own profile: full access
CREATE POLICY "profiles: owner full access"
  ON public.profiles FOR ALL
  USING (id = auth.uid());

-- Admin: read all profiles
CREATE POLICY "profiles: admin read all"
  ON public.profiles FOR SELECT
  USING (public.get_my_role() = 'admin');

-- Admin: update any profile (deactivate, change role)
CREATE POLICY "profiles: admin update any"
  ON public.profiles FOR UPDATE
  USING (public.get_my_role() = 'admin');

-- Admin: delete any profile
CREATE POLICY "profiles: admin delete any"
  ON public.profiles FOR DELETE
  USING (public.get_my_role() = 'admin');

-- Authenticated users: read basic profile info of workers (for listing)
CREATE POLICY "profiles: auth users read worker profiles"
  ON public.profiles FOR SELECT
  USING (
    auth.role() = 'authenticated'
    AND role = 'worker'
    AND is_active = TRUE
  );

-- ════════════════════════════════
-- TABLE: areas
-- ════════════════════════════════
ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read active areas
CREATE POLICY "areas: auth read active"
  ON public.areas FOR SELECT
  USING (auth.role() = 'authenticated' AND is_active = TRUE);

-- Admin reads all areas (including inactive)
CREATE POLICY "areas: admin read all"
  ON public.areas FOR SELECT
  USING (public.get_my_role() = 'admin');

-- Only admin can insert/update/delete areas
CREATE POLICY "areas: admin write"
  ON public.areas FOR INSERT
  WITH CHECK (public.get_my_role() = 'admin');

CREATE POLICY "areas: admin update"
  ON public.areas FOR UPDATE
  USING (public.get_my_role() = 'admin');

CREATE POLICY "areas: admin delete"
  ON public.areas FOR DELETE
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: categories
-- ════════════════════════════════
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- All authenticated users read active categories
CREATE POLICY "categories: auth read active"
  ON public.categories FOR SELECT
  USING (auth.role() = 'authenticated' AND is_active = TRUE);

-- Admin reads all
CREATE POLICY "categories: admin read all"
  ON public.categories FOR SELECT
  USING (public.get_my_role() = 'admin');

-- Only admin writes
CREATE POLICY "categories: admin insert"
  ON public.categories FOR INSERT
  WITH CHECK (public.get_my_role() = 'admin');

CREATE POLICY "categories: admin update"
  ON public.categories FOR UPDATE
  USING (public.get_my_role() = 'admin');

CREATE POLICY "categories: admin delete"
  ON public.categories FOR DELETE
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: workers
-- ════════════════════════════════
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read available, active workers
CREATE POLICY "workers: auth read available"
  ON public.workers FOR SELECT
  USING (
    auth.role() = 'authenticated'
    AND is_available = TRUE
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = workers.profile_id AND p.is_active = TRUE
    )
  );

-- Worker can read their own record (even if unavailable)
CREATE POLICY "workers: own record read"
  ON public.workers FOR SELECT
  USING (profile_id = auth.uid());

-- Worker can update their own record
CREATE POLICY "workers: own record update"
  ON public.workers FOR UPDATE
  USING (profile_id = auth.uid());

-- Worker can insert their own record (on registration)
CREATE POLICY "workers: own record insert"
  ON public.workers FOR INSERT
  WITH CHECK (profile_id = auth.uid());

-- Admin: full access
CREATE POLICY "workers: admin full access"
  ON public.workers FOR ALL
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: worker_categories
-- ════════════════════════════════
ALTER TABLE public.worker_categories ENABLE ROW LEVEL SECURITY;

-- Authenticated users read (needed for filtering)
CREATE POLICY "worker_categories: auth read"
  ON public.worker_categories FOR SELECT
  USING (auth.role() = 'authenticated');

-- Worker manages their own categories
CREATE POLICY "worker_categories: worker write own"
  ON public.worker_categories FOR ALL
  USING (worker_id = public.get_my_worker_id());

-- Admin full access
CREATE POLICY "worker_categories: admin full"
  ON public.worker_categories FOR ALL
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: worker_skills
-- ════════════════════════════════
ALTER TABLE public.worker_skills ENABLE ROW LEVEL SECURITY;

CREATE POLICY "worker_skills: auth read"
  ON public.worker_skills FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "worker_skills: worker write own"
  ON public.worker_skills FOR ALL
  USING (worker_id = public.get_my_worker_id());

CREATE POLICY "worker_skills: admin full"
  ON public.worker_skills FOR ALL
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: bookings
-- ════════════════════════════════
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- User reads their own bookings
CREATE POLICY "bookings: user reads own"
  ON public.bookings FOR SELECT
  USING (user_id = auth.uid());

-- Worker reads bookings assigned to them
CREATE POLICY "bookings: worker reads own"
  ON public.bookings FOR SELECT
  USING (worker_id = public.get_my_worker_id());

-- User creates bookings (only for themselves)
CREATE POLICY "bookings: user creates"
  ON public.bookings FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND public.get_my_role() = 'user'
  );

-- User can cancel their own pending/confirmed booking
CREATE POLICY "bookings: user cancel own"
  ON public.bookings FOR UPDATE
  USING (
    user_id = auth.uid()
    AND status IN ('pending', 'confirmed')
  )
  WITH CHECK (status = 'cancelled');

-- Worker can update status of their own bookings
CREATE POLICY "bookings: worker update status"
  ON public.bookings FOR UPDATE
  USING (worker_id = public.get_my_worker_id());

-- Admin full access
CREATE POLICY "bookings: admin full"
  ON public.bookings FOR ALL
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: reviews
-- ════════════════════════════════
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read non-flagged reviews
CREATE POLICY "reviews: auth read non-flagged"
  ON public.reviews FOR SELECT
  USING (auth.role() = 'authenticated' AND is_flagged = FALSE);

-- Admin reads all including flagged
CREATE POLICY "reviews: admin read all"
  ON public.reviews FOR SELECT
  USING (public.get_my_role() = 'admin');

-- User can insert a review only for their own completed, unreviewed booking
CREATE POLICY "reviews: user insert own"
  ON public.reviews FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id
        AND b.user_id = auth.uid()
        AND b.status = 'completed'
        AND b.is_reviewed = FALSE
    )
  );

-- Admin: update (flag/unflag) and delete
CREATE POLICY "reviews: admin update"
  ON public.reviews FOR UPDATE
  USING (public.get_my_role() = 'admin');

CREATE POLICY "reviews: admin delete"
  ON public.reviews FOR DELETE
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: chats
-- ════════════════════════════════
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- Participants (user or worker) can read their chat
CREATE POLICY "chats: participant read"
  ON public.chats FOR SELECT
  USING (
    user_id = auth.uid()
    OR worker_id = public.get_my_worker_id()
  );

-- System/booking trigger inserts chat (via SECURITY DEFINER function)
-- Users cannot directly insert chats — done via function
CREATE POLICY "chats: admin full"
  ON public.chats FOR ALL
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: messages
-- ════════════════════════════════
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Chat participants can read messages
CREATE POLICY "messages: participant read"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = chat_id
        AND (c.user_id = auth.uid() OR c.worker_id = public.get_my_worker_id())
    )
  );

-- Chat participants can send messages
CREATE POLICY "messages: participant insert"
  ON public.messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = chat_id
        AND (c.user_id = auth.uid() OR c.worker_id = public.get_my_worker_id())
    )
  );

-- Recipient can mark as read
CREATE POLICY "messages: recipient update read"
  ON public.messages FOR UPDATE
  USING (
    sender_id != auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = chat_id
        AND (c.user_id = auth.uid() OR c.worker_id = public.get_my_worker_id())
    )
  );

-- Admin full
CREATE POLICY "messages: admin full"
  ON public.messages FOR ALL
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: notifications
-- ════════════════════════════════
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- User reads their own notifications
CREATE POLICY "notifications: own read"
  ON public.notifications FOR SELECT
  USING (recipient_id = auth.uid());

-- User updates own (mark as read)
CREATE POLICY "notifications: own update"
  ON public.notifications FOR UPDATE
  USING (recipient_id = auth.uid());

-- Insert done via SECURITY DEFINER functions/triggers only
-- Admin full access
CREATE POLICY "notifications: admin full"
  ON public.notifications FOR ALL
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: app_config
-- ════════════════════════════════
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read config (feature flags)
CREATE POLICY "app_config: auth read"
  ON public.app_config FOR SELECT
  USING (auth.role() = 'authenticated');

-- Only admin writes
CREATE POLICY "app_config: admin write"
  ON public.app_config FOR ALL
  USING (public.get_my_role() = 'admin');

-- ════════════════════════════════
-- TABLE: fcm_broadcast_log
-- ════════════════════════════════
ALTER TABLE public.fcm_broadcast_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fcm_broadcast: admin full"
  ON public.fcm_broadcast_log FOR ALL
  USING (public.get_my_role() = 'admin');
