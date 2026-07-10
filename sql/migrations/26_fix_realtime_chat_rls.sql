-- ============================================================
-- Fix Real-time Chat RLS permissions
-- File: 26_fix_realtime_chat_rls.sql
-- ============================================================

-- 1. Ensure tables exist before altering them
CREATE TABLE IF NOT EXISTS public.chats (
  id              UUID  PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id      UUID  REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id         UUID  NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  worker_id       UUID  NOT NULL REFERENCES public.workers(id)  ON DELETE CASCADE,
  last_message    TEXT,
  last_message_at TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.messages (
  id          UUID  PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id     UUID  NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  sender_id   UUID  NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  text        TEXT  NOT NULL,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Add seeker_id and provider_id to chats to avoid joins in realtime RLS
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS seeker_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS provider_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Backfill data
UPDATE public.chats
SET seeker_id = user_id,
    provider_id = w.profile_id
FROM public.workers w
WHERE public.chats.worker_id = w.id
  AND public.chats.provider_id IS NULL;

-- 3. Add receiver_id to messages
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Backfill data
UPDATE public.messages
SET receiver_id = CASE
  WHEN public.messages.sender_id = c.user_id THEN c.provider_id
  ELSE c.user_id
END
FROM public.chats c
WHERE public.messages.chat_id = c.id
  AND public.messages.receiver_id IS NULL;

-- 3. Drop existing complex policies that break realtime
DROP POLICY IF EXISTS "chats: participant read" ON public.chats;
DROP POLICY IF EXISTS "chats: participant insert" ON public.chats;
DROP POLICY IF EXISTS "messages: participant read" ON public.messages;
DROP POLICY IF EXISTS "messages: participant insert" ON public.messages;
DROP POLICY IF EXISTS "messages: recipient update read" ON public.messages;

-- 4. Create trigger to auto-populate seeker_id and provider_id on insert
CREATE OR REPLACE FUNCTION public.trg_populate_chat_profile_ids()
RETURNS TRIGGER AS $$
BEGIN
  NEW.seeker_id := NEW.user_id;
  SELECT profile_id INTO NEW.provider_id
  FROM public.workers
  WHERE id = NEW.worker_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS populate_chat_profile_ids ON public.chats;
CREATE TRIGGER populate_chat_profile_ids
BEFORE INSERT ON public.chats
FOR EACH ROW
EXECUTE FUNCTION public.trg_populate_chat_profile_ids();

-- 5. Create new direct, realtime-friendly RLS policies
-- Chats: User can read if they are seeker or provider
CREATE POLICY "chats: participant read"
  ON public.chats FOR SELECT
  USING (auth.uid() = seeker_id OR auth.uid() = provider_id);

-- Chats: allow inserting chats direct
CREATE POLICY "chats: participant insert"
  ON public.chats FOR INSERT
  WITH CHECK (auth.uid() = seeker_id OR auth.uid() = provider_id);

-- Messages: User can read if they are sender or receiver
CREATE POLICY "messages: participant read"
  ON public.messages FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Messages: User can insert if they are sender
CREATE POLICY "messages: participant insert"
  ON public.messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- Messages: User can update (mark as read) if they are receiver
CREATE POLICY "messages: recipient update read"
  ON public.messages FOR UPDATE
  USING (auth.uid() = receiver_id);
