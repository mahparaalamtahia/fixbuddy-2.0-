-- ============================================================
-- FixBuddy Database Audit Patches
-- File: 20_audit_patches.sql
-- Run AFTER 04_functions.sql
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Prevent Worker Metric Tampering via RLS / Triggers
-- Workers should not be able to update is_verified, avg_rating,
-- review_count, or total_bookings.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.prevent_worker_metric_tampering()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- If the user making the update is NOT an admin, force the metrics back to original values
  IF public.get_my_role() != 'admin' THEN
    NEW.is_verified := OLD.is_verified;
    NEW.avg_rating := OLD.avg_rating;
    NEW.review_count := OLD.review_count;
    NEW.total_bookings := OLD.total_bookings;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_worker_metric_tampering ON public.workers;
CREATE TRIGGER trg_prevent_worker_metric_tampering
  BEFORE UPDATE ON public.workers
  FOR EACH ROW EXECUTE FUNCTION public.prevent_worker_metric_tampering();

-- ────────────────────────────────────────────────────────────
-- 2. Notification Automations for Bookings & Messages
-- ────────────────────────────────────────────────────────────

-- Booking event notifications
CREATE OR REPLACE FUNCTION public.notify_booking_events()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_worker_profile_id UUID;
BEGIN
  -- Get worker's profile_id to send notifications to
  SELECT profile_id INTO v_worker_profile_id FROM public.workers WHERE id = NEW.worker_id;

  -- New booking created
  IF TG_OP = 'INSERT' THEN
    PERFORM public.create_notification(
      v_worker_profile_id,
      'booking_new',
      'New Booking Request',
      'You have received a new booking request.',
      NEW.id
    );
  -- Booking updated
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.status = 'confirmed' AND OLD.status = 'pending' THEN
      PERFORM public.create_notification(
        NEW.user_id,
        'booking_confirmed',
        'Booking Confirmed',
        'Your booking has been accepted by the worker.',
        NEW.id
      );
    ELSIF NEW.status = 'declined' AND OLD.status = 'pending' THEN
      PERFORM public.create_notification(
        NEW.user_id,
        'booking_declined',
        'Booking Declined',
        'Your booking request was declined.',
        NEW.id
      );
    ELSIF NEW.status = 'completed' AND OLD.status != 'completed' THEN
      PERFORM public.create_notification(
        NEW.user_id,
        'booking_completed',
        'Job Completed',
        'Your job has been marked as completed. Please leave a review!',
        NEW.id
      );
    ELSIF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
      -- If user cancelled, notify worker. If worker cancelled, notify user.
      IF public.get_my_role() = 'user' THEN
        PERFORM public.create_notification(
          v_worker_profile_id,
          'booking_cancelled',
          'Booking Cancelled',
          'The user has cancelled the booking.',
          NEW.id
        );
      ELSE
        PERFORM public.create_notification(
          NEW.user_id,
          'booking_cancelled',
          'Booking Cancelled',
          'The worker has cancelled the booking.',
          NEW.id
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_booking_events ON public.bookings;
CREATE TRIGGER trg_notify_booking_events
  AFTER INSERT OR UPDATE OF status ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.notify_booking_events();

-- Chat message notifications
CREATE OR REPLACE FUNCTION public.notify_chat_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_recipient_id UUID;
  v_chat_record public.chats%ROWTYPE;
  v_worker_profile_id UUID;
BEGIN
  -- Get the chat record to find participants
  SELECT * INTO v_chat_record FROM public.chats WHERE id = NEW.chat_id;
  SELECT profile_id INTO v_worker_profile_id FROM public.workers WHERE id = v_chat_record.worker_id;

  -- Determine who the recipient is
  IF NEW.sender_id = v_chat_record.user_id THEN
    v_recipient_id := v_worker_profile_id;
  ELSE
    v_recipient_id := v_chat_record.user_id;
  END IF;

  PERFORM public.create_notification(
    v_recipient_id,
    'chat_message',
    'New Message',
    'You received a new message.',
    NEW.chat_id
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_chat_message ON public.messages;
CREATE TRIGGER trg_notify_chat_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_chat_message();

-- ────────────────────────────────────────────────────────────
-- 3. Missing `updated_at` Triggers for Admin Tables
-- ────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_categories_updated_at ON public.categories;
CREATE TRIGGER trg_categories_updated_at
  BEFORE UPDATE ON public.categories
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_areas_updated_at ON public.areas;
CREATE TRIGGER trg_areas_updated_at
  BEFORE UPDATE ON public.areas
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_app_config_updated_at ON public.app_config;
CREATE TRIGGER trg_app_config_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ────────────────────────────────────────────────────────────
-- 4. Fix Foreign Key Constraints for Safe Deletions
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.bookings
  DROP CONSTRAINT bookings_category_id_fkey,
  DROP CONSTRAINT bookings_area_id_fkey;

ALTER TABLE public.bookings
  ALTER COLUMN category_id DROP NOT NULL,
  ALTER COLUMN area_id DROP NOT NULL;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_category_id_fkey
    FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL,
  ADD CONSTRAINT bookings_area_id_fkey
    FOREIGN KEY (area_id) REFERENCES public.areas(id) ON DELETE SET NULL;
