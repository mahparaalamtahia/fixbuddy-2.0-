-- ============================================================
-- FixBuddy Database Schema
-- File: 01_tables.sql
-- Run this FIRST in Supabase SQL Editor
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ────────────────────────────────────────────────────────────
-- ENUM TYPES
-- ────────────────────────────────────────────────────────────
CREATE TYPE user_role       AS ENUM ('user', 'worker', 'admin');
CREATE TYPE booking_status  AS ENUM (
  'pending', 'confirmed', 'in_progress', 'completed', 'cancelled', 'declined'
);
CREATE TYPE notification_type AS ENUM (
  'booking_new', 'booking_confirmed', 'booking_declined',
  'booking_completed', 'booking_cancelled', 'chat_message',
  'admin_broadcast', 'review_received'
);

-- ────────────────────────────────────────────────────────────
-- TABLE: profiles
-- Extends Supabase auth.users — one row per registered user
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role              user_role         NOT NULL DEFAULT 'user',
  full_name         TEXT              NOT NULL,
  email             TEXT              NOT NULL UNIQUE,
  phone             TEXT,
  avatar_url        TEXT,
  area_id           UUID,             -- FK added after areas table
  is_active         BOOLEAN           NOT NULL DEFAULT TRUE,
  fcm_token         TEXT,
  created_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- TABLE: areas
-- Dynamic geographic zones — managed by admin
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.areas (
  id          UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT    NOT NULL UNIQUE,
  city        TEXT    NOT NULL DEFAULT 'Dhaka',
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INT     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add FK from profiles to areas
ALTER TABLE public.profiles
  ADD CONSTRAINT fk_profiles_area
  FOREIGN KEY (area_id) REFERENCES public.areas(id) ON DELETE SET NULL;

-- ────────────────────────────────────────────────────────────
-- TABLE: categories
-- Dynamic service categories — managed by admin
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.categories (
  id            UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT    NOT NULL UNIQUE,
  icon_name     TEXT    NOT NULL,        -- Flutter icon codepoint or name string
  color_hex     TEXT    NOT NULL,        -- e.g. '#FF6B35'
  description   TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order    INT     NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- TABLE: workers
-- Extended profile for users with role = 'worker'
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.workers (
  id              UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id      UUID    NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  bio             TEXT,
  experience_years INT    NOT NULL DEFAULT 0,
  hourly_rate     DECIMAL(10,2) NOT NULL DEFAULT 0,
  is_available    BOOLEAN NOT NULL DEFAULT TRUE,
  is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
  avg_rating      DECIMAL(3,2) NOT NULL DEFAULT 0.00,
  review_count    INT     NOT NULL DEFAULT 0,
  total_bookings  INT     NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- TABLE: worker_categories
-- Many-to-many: a worker can offer multiple service categories
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.worker_categories (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id   UUID NOT NULL REFERENCES public.workers(id)     ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.categories(id)  ON DELETE CASCADE,
  UNIQUE(worker_id, category_id)
);

-- ────────────────────────────────────────────────────────────
-- TABLE: worker_skills
-- Free-text skills tags per worker
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.worker_skills (
  id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
  skill     TEXT NOT NULL,
  UNIQUE(worker_id, skill)
);

-- ────────────────────────────────────────────────────────────
-- TABLE: bookings
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.bookings (
  id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID          NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  worker_id       UUID          NOT NULL REFERENCES public.workers(id)     ON DELETE CASCADE,
  category_id     UUID          NOT NULL REFERENCES public.categories(id)  ON DELETE RESTRICT,
  area_id         UUID          NOT NULL REFERENCES public.areas(id)       ON DELETE RESTRICT,
  scheduled_date  DATE          NOT NULL,
  scheduled_time  TIME          NOT NULL,
  status          booking_status NOT NULL DEFAULT 'pending',
  notes           TEXT,
  total_amount    DECIMAL(10,2),
  is_reviewed     BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- TABLE: reviews
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.reviews (
  id          UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id  UUID    NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id     UUID    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  worker_id   UUID    NOT NULL REFERENCES public.workers(id)  ON DELETE CASCADE,
  rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  is_flagged  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- TABLE: chats
-- One chat thread per booking
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.chats (
  id              UUID  PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id      UUID  NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id         UUID  NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  worker_id       UUID  NOT NULL REFERENCES public.workers(id)  ON DELETE CASCADE,
  last_message    TEXT,
  last_message_at TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- TABLE: messages
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.messages (
  id          UUID  PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id     UUID  NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  sender_id   UUID  NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  text        TEXT  NOT NULL,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- TABLE: notifications
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.notifications (
  id              UUID              PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_id    UUID              NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type            notification_type NOT NULL,
  title           TEXT              NOT NULL,
  body            TEXT              NOT NULL,
  reference_id    UUID,             -- bookingId, chatId, etc.
  is_read         BOOLEAN           NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- TABLE: app_config
-- Admin-controlled feature flags and app settings
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.app_config (
  id                  UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
  key                 TEXT    NOT NULL UNIQUE,
  value               TEXT    NOT NULL,
  description         TEXT,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- TABLE: fcm_broadcast_log
-- Tracks admin push notification broadcasts
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.fcm_broadcast_log (
  id            UUID  PRIMARY KEY DEFAULT uuid_generate_v4(),
  title         TEXT  NOT NULL,
  body          TEXT  NOT NULL,
  target        TEXT  NOT NULL,   -- 'all_users', 'all_workers', 'specific', 'by_area'
  target_id     UUID,             -- area_id or profile_id when target is specific
  sent_by       UUID  NOT NULL REFERENCES public.profiles(id),
  sent_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- INDEXES (performance)
-- ────────────────────────────────────────────────────────────
CREATE INDEX idx_profiles_role         ON public.profiles(role);
CREATE INDEX idx_profiles_area         ON public.profiles(area_id);
CREATE INDEX idx_workers_available     ON public.workers(is_available);
CREATE INDEX idx_workers_verified      ON public.workers(is_verified);
CREATE INDEX idx_bookings_user         ON public.bookings(user_id);
CREATE INDEX idx_bookings_worker       ON public.bookings(worker_id);
CREATE INDEX idx_bookings_status       ON public.bookings(status);
CREATE INDEX idx_bookings_date         ON public.bookings(scheduled_date);
CREATE INDEX idx_messages_chat         ON public.messages(chat_id);
CREATE INDEX idx_messages_created      ON public.messages(created_at DESC);
CREATE INDEX idx_notifications_recip   ON public.notifications(recipient_id);
CREATE INDEX idx_notifications_read    ON public.notifications(is_read);
CREATE INDEX idx_worker_categories_wid ON public.worker_categories(worker_id);
CREATE INDEX idx_worker_categories_cid ON public.worker_categories(category_id);