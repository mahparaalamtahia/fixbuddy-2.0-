-- 1. Fix get_my_role return type mismatch (Error 42P13)
-- We cannot change the return type or drop the function because 32 policies depend on it.
-- Instead, we keep the return type as `user_role` and cast the TEXT column back to the ENUM.
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT role::user_role FROM public.profiles WHERE id = auth.uid();
$$;

-- 2. Allow dynamic chats without requiring a booking
ALTER TABLE public.chats ALTER COLUMN booking_id DROP NOT NULL;

-- 3. Drop the unique constraint on booking_id so multiple chats can exist or nulls can exist
ALTER TABLE public.chats DROP CONSTRAINT IF EXISTS chats_booking_id_key;

-- 4. Add a unique constraint to ensure only one chat per (user, worker) when booking is null
CREATE UNIQUE INDEX IF NOT EXISTS chats_user_worker_no_booking_idx 
ON public.chats (user_id, worker_id) WHERE booking_id IS NULL;

-- 5. Add an INSERT policy so users can directly create chats (previously only system/trigger could)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'chats' AND policyname = 'chats: participants insert'
  ) THEN
    CREATE POLICY "chats: participants insert"
      ON public.chats FOR INSERT
      WITH CHECK (
        auth.uid() = user_id OR public.get_my_worker_id() = worker_id
      );
  END IF;
END $$;

-- 6. Fix the trigger function that tries to use ON CONFLICT (booking_id) since we dropped that constraint
CREATE OR REPLACE FUNCTION public.create_chat_on_booking_confirm()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status = 'confirmed' AND OLD.status = 'pending' THEN
    -- If there's an existing pre-booking chat, link it to this booking
    UPDATE public.chats 
    SET booking_id = NEW.id 
    WHERE user_id = NEW.user_id AND worker_id = NEW.worker_id AND booking_id IS NULL;

    -- If no chat exists for this booking, create one
    IF NOT EXISTS (SELECT 1 FROM public.chats WHERE booking_id = NEW.id) THEN
      INSERT INTO public.chats (booking_id, user_id, worker_id)
      VALUES (NEW.id, NEW.user_id, NEW.worker_id);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
