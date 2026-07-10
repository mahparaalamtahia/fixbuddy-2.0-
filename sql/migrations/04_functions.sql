-- ============================================================
-- FixBuddy PostgreSQL Functions & Triggers
-- File: 04_functions.sql
-- Run AFTER 03_storage.sql
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- TRIGGER: auto-update updated_at columns
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_workers_updated_at
  BEFORE UPDATE ON public.workers
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ────────────────────────────────────────────────────────────
-- TRIGGER: auto-create profile on auth.users insert
-- Runs when a user registers via Supabase Auth
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'user')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ────────────────────────────────────────────────────────────
-- TRIGGER: auto-create workers row when profile role = worker
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_worker_profile()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.role = 'worker' AND (OLD.role IS NULL OR OLD.role != 'worker') THEN
    INSERT INTO public.workers (profile_id)
    VALUES (NEW.id)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_on_worker_role_set
  AFTER INSERT OR UPDATE OF role ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_worker_profile();

-- ────────────────────────────────────────────────────────────
-- FUNCTION: recalculate worker avg_rating after review insert
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.recalculate_worker_rating()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.workers
  SET
    avg_rating   = (SELECT AVG(rating) FROM public.reviews
                    WHERE worker_id = NEW.worker_id AND is_flagged = FALSE),
    review_count = (SELECT COUNT(*) FROM public.reviews
                    WHERE worker_id = NEW.worker_id AND is_flagged = FALSE)
  WHERE id = NEW.worker_id;

  -- Mark the booking as reviewed
  UPDATE public.bookings SET is_reviewed = TRUE WHERE id = NEW.booking_id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_on_review_insert
  AFTER INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.recalculate_worker_rating();

-- ────────────────────────────────────────────────────────────
-- FUNCTION: auto-create chat thread when booking is confirmed
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_chat_on_booking_confirm()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status = 'confirmed' AND OLD.status = 'pending' THEN
    INSERT INTO public.chats (booking_id, user_id, worker_id)
    VALUES (NEW.id, NEW.user_id, NEW.worker_id)
    ON CONFLICT (booking_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_on_booking_confirmed
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.create_chat_on_booking_confirm();

-- ────────────────────────────────────────────────────────────
-- FUNCTION: update chat last_message on new message
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_chat_last_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.chats
  SET last_message = NEW.text, last_message_at = NEW.created_at
  WHERE id = NEW.chat_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_on_message_insert
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.update_chat_last_message();

-- ────────────────────────────────────────────────────────────
-- FUNCTION: insert notification (SECURITY DEFINER — used by app)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_notification(
  p_recipient_id    UUID,
  p_type            notification_type,
  p_title           TEXT,
  p_body            TEXT,
  p_reference_id    UUID DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.notifications (recipient_id, type, title, body, reference_id)
  VALUES (p_recipient_id, p_type, p_title, p_body, p_reference_id);
END;
$$;

-- ────────────────────────────────────────────────────────────
-- FUNCTION: get worker full profile (join view for Flutter)
-- Returns worker + profile + categories + skills in one call
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_worker_full_profile(p_worker_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE result JSON;
BEGIN
  SELECT json_build_object(
    'worker',      row_to_json(w),
    'profile',     row_to_json(p),
    'categories',  (SELECT json_agg(c) FROM public.categories c
                    JOIN public.worker_categories wc ON wc.category_id = c.id
                    WHERE wc.worker_id = w.id),
    'skills',      (SELECT json_agg(ws.skill) FROM public.worker_skills ws WHERE ws.worker_id = w.id),
    'reviews',     (SELECT json_agg(r) FROM public.reviews r WHERE r.worker_id = w.id
                    AND r.is_flagged = FALSE ORDER BY r.created_at DESC LIMIT 10)
  )
  INTO result
  FROM public.workers w
  JOIN public.profiles p ON p.id = w.profile_id
  WHERE w.id = p_worker_id;

  RETURN result;
END;
$$;

-- ────────────────────────────────────────────────────────────
-- FUNCTION: admin dashboard stats
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_admin_stats()
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN json_build_object(
    'total_users',          (SELECT COUNT(*) FROM public.profiles WHERE role = 'user'),
    'total_workers',        (SELECT COUNT(*) FROM public.profiles WHERE role = 'worker'),
    'total_bookings',       (SELECT COUNT(*) FROM public.bookings),
    'bookings_today',       (SELECT COUNT(*) FROM public.bookings WHERE scheduled_date = CURRENT_DATE),
    'pending_approvals',    (SELECT COUNT(*) FROM public.workers WHERE is_verified = FALSE),
    'completed_bookings',   (SELECT COUNT(*) FROM public.bookings WHERE status = 'completed'),
    'active_categories',    (SELECT COUNT(*) FROM public.categories WHERE is_active = TRUE),
    'active_areas',         (SELECT COUNT(*) FROM public.areas WHERE is_active = TRUE)
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- FUNCTION: worker dashboard stats
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_worker_stats(p_worker_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN json_build_object(
    'total_bookings',     (SELECT COUNT(*) FROM public.bookings WHERE worker_id = p_worker_id),
    'completed',          (SELECT COUNT(*) FROM public.bookings WHERE worker_id = p_worker_id AND status = 'completed'),
    'pending',            (SELECT COUNT(*) FROM public.bookings WHERE worker_id = p_worker_id AND status = 'pending'),
    'avg_rating',         (SELECT avg_rating FROM public.workers WHERE id = p_worker_id),
    'review_count',       (SELECT review_count FROM public.workers WHERE id = p_worker_id)
  );
END;
$$;
