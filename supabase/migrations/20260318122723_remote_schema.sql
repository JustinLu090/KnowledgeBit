
  create table "public"."battle_allocations" (
    "room_id" uuid not null,
    "hour_bucket" timestamp with time zone not null,
    "user_id" uuid not null,
    "allocations" jsonb not null default '{}'::jsonb,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."battle_allocations" enable row level security;


  create table "public"."battle_board_state" (
    "room_id" uuid not null,
    "hour_bucket" timestamp with time zone not null,
    "cells" jsonb not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."battle_board_state" enable row level security;


  create table "public"."battle_energy" (
    "user_id" uuid not null,
    "namespace" text not null,
    "available_ke" integer not null default 0,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."battle_energy" enable row level security;


  create table "public"."battle_rooms" (
    "id" uuid not null default gen_random_uuid(),
    "word_set_id" uuid not null,
    "creator_id" uuid not null,
    "start_date" timestamp with time zone not null,
    "duration_days" integer not null default 7,
    "invited_member_ids" uuid[] not null default '{}'::uuid[],
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."battle_rooms" enable row level security;


  create table "public"."cards" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "word_set_id" uuid,
    "title" text not null,
    "content" text not null default ''::text,
    "is_mastered" boolean not null default false,
    "created_at" timestamp with time zone not null default now(),
    "srs_level" integer not null default 0,
    "due_at" timestamp with time zone not null default now(),
    "last_reviewed_at" timestamp with time zone,
    "correct_streak" integer not null default 0
      );


alter table "public"."cards" enable row level security;


  create table "public"."friend_requests" (
    "id" uuid not null default gen_random_uuid(),
    "sender_id" uuid not null,
    "receiver_id" uuid not null,
    "status" text not null default 'pending'::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."friend_requests" enable row level security;


  create table "public"."friendships" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "friend_id" uuid not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."friendships" enable row level security;


  create table "public"."study_logs" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "date" date not null,
    "cards_reviewed" integer not null default 0
      );


alter table "public"."study_logs" enable row level security;


  create table "public"."user_profiles" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "display_name" text not null default '使用者'::text,
    "avatar_url" text,
    "level" integer not null default 1,
    "current_exp" integer not null default 0,
    "updated_at" timestamp with time zone not null default now(),
    "created_at" timestamp with time zone not null default now(),
    "invite_code" text
      );


alter table "public"."user_profiles" enable row level security;


  create table "public"."word_set_collaborators" (
    "word_set_id" uuid not null,
    "user_id" uuid not null,
    "role" text not null default 'editor'::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."word_set_collaborators" enable row level security;


  create table "public"."word_set_invitations" (
    "id" uuid not null default gen_random_uuid(),
    "word_set_id" uuid not null,
    "inviter_id" uuid not null,
    "invitee_id" uuid not null,
    "status" text not null default 'pending'::text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."word_set_invitations" enable row level security;


  create table "public"."word_sets" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "title" text not null,
    "level" text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."word_sets" enable row level security;

CREATE UNIQUE INDEX battle_allocations_pkey ON public.battle_allocations USING btree (room_id, hour_bucket, user_id);

CREATE UNIQUE INDEX battle_board_state_pkey ON public.battle_board_state USING btree (room_id, hour_bucket);

CREATE INDEX battle_energy_namespace_idx ON public.battle_energy USING btree (namespace);

CREATE UNIQUE INDEX battle_energy_pk ON public.battle_energy USING btree (user_id, namespace);

CREATE UNIQUE INDEX battle_rooms_pkey ON public.battle_rooms USING btree (id);

CREATE UNIQUE INDEX cards_pkey ON public.cards USING btree (id);

CREATE UNIQUE INDEX friend_requests_pkey ON public.friend_requests USING btree (id);

CREATE UNIQUE INDEX friend_requests_sender_id_receiver_id_key ON public.friend_requests USING btree (sender_id, receiver_id);

CREATE UNIQUE INDEX friendships_pkey ON public.friendships USING btree (id);

CREATE UNIQUE INDEX friendships_user_id_friend_id_key ON public.friendships USING btree (user_id, friend_id);

CREATE INDEX idx_battle_allocations_room_hour ON public.battle_allocations USING btree (room_id, hour_bucket);

CREATE INDEX idx_battle_board_state_room ON public.battle_board_state USING btree (room_id);

CREATE INDEX idx_battle_energy_user ON public.battle_energy USING btree (user_id);

CREATE INDEX idx_battle_rooms_creator ON public.battle_rooms USING btree (creator_id);

CREATE INDEX idx_battle_rooms_word_set ON public.battle_rooms USING btree (word_set_id);

CREATE INDEX idx_cards_user_id ON public.cards USING btree (user_id);

CREATE INDEX idx_cards_word_set_id ON public.cards USING btree (word_set_id);

CREATE INDEX idx_friend_requests_receiver ON public.friend_requests USING btree (receiver_id);

CREATE INDEX idx_friend_requests_sender ON public.friend_requests USING btree (sender_id);

CREATE INDEX idx_friend_requests_status ON public.friend_requests USING btree (status);

CREATE INDEX idx_friendships_friend_id ON public.friendships USING btree (friend_id);

CREATE INDEX idx_friendships_user_id ON public.friendships USING btree (user_id);

CREATE INDEX idx_study_logs_user_date ON public.study_logs USING btree (user_id, date);

CREATE INDEX idx_study_logs_user_id ON public.study_logs USING btree (user_id);

CREATE UNIQUE INDEX idx_user_profiles_invite_code ON public.user_profiles USING btree (invite_code) WHERE (invite_code IS NOT NULL);

CREATE INDEX idx_user_profiles_user_id ON public.user_profiles USING btree (user_id);

CREATE INDEX idx_word_set_collab_user ON public.word_set_collaborators USING btree (user_id);

CREATE INDEX idx_word_set_invitations_invitee ON public.word_set_invitations USING btree (invitee_id);

CREATE INDEX idx_word_set_invitations_word_set ON public.word_set_invitations USING btree (word_set_id);

CREATE INDEX idx_word_sets_user_id ON public.word_sets USING btree (user_id);

CREATE UNIQUE INDEX study_logs_pkey ON public.study_logs USING btree (id);

CREATE UNIQUE INDEX user_profiles_pkey ON public.user_profiles USING btree (id);

CREATE UNIQUE INDEX user_profiles_user_id_key ON public.user_profiles USING btree (user_id);

CREATE UNIQUE INDEX word_set_collaborators_pkey ON public.word_set_collaborators USING btree (word_set_id, user_id);

CREATE UNIQUE INDEX word_set_invitations_pkey ON public.word_set_invitations USING btree (id);

CREATE UNIQUE INDEX word_set_invitations_word_set_id_invitee_id_key ON public.word_set_invitations USING btree (word_set_id, invitee_id);

CREATE UNIQUE INDEX word_sets_pkey ON public.word_sets USING btree (id);

alter table "public"."battle_allocations" add constraint "battle_allocations_pkey" PRIMARY KEY using index "battle_allocations_pkey";

alter table "public"."battle_board_state" add constraint "battle_board_state_pkey" PRIMARY KEY using index "battle_board_state_pkey";

alter table "public"."battle_energy" add constraint "battle_energy_pk" PRIMARY KEY using index "battle_energy_pk";

alter table "public"."battle_rooms" add constraint "battle_rooms_pkey" PRIMARY KEY using index "battle_rooms_pkey";

alter table "public"."cards" add constraint "cards_pkey" PRIMARY KEY using index "cards_pkey";

alter table "public"."friend_requests" add constraint "friend_requests_pkey" PRIMARY KEY using index "friend_requests_pkey";

alter table "public"."friendships" add constraint "friendships_pkey" PRIMARY KEY using index "friendships_pkey";

alter table "public"."study_logs" add constraint "study_logs_pkey" PRIMARY KEY using index "study_logs_pkey";

alter table "public"."user_profiles" add constraint "user_profiles_pkey" PRIMARY KEY using index "user_profiles_pkey";

alter table "public"."word_set_collaborators" add constraint "word_set_collaborators_pkey" PRIMARY KEY using index "word_set_collaborators_pkey";

alter table "public"."word_set_invitations" add constraint "word_set_invitations_pkey" PRIMARY KEY using index "word_set_invitations_pkey";

alter table "public"."word_sets" add constraint "word_sets_pkey" PRIMARY KEY using index "word_sets_pkey";

alter table "public"."battle_allocations" add constraint "battle_allocations_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.battle_rooms(id) ON DELETE CASCADE not valid;

alter table "public"."battle_allocations" validate constraint "battle_allocations_room_id_fkey";

alter table "public"."battle_allocations" add constraint "battle_allocations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."battle_allocations" validate constraint "battle_allocations_user_id_fkey";

alter table "public"."battle_board_state" add constraint "battle_board_state_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.battle_rooms(id) ON DELETE CASCADE not valid;

alter table "public"."battle_board_state" validate constraint "battle_board_state_room_id_fkey";

alter table "public"."battle_rooms" add constraint "battle_rooms_creator_id_fkey" FOREIGN KEY (creator_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."battle_rooms" validate constraint "battle_rooms_creator_id_fkey";

alter table "public"."cards" add constraint "cards_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."cards" validate constraint "cards_user_id_fkey";

alter table "public"."cards" add constraint "cards_word_set_id_fkey" FOREIGN KEY (word_set_id) REFERENCES public.word_sets(id) ON DELETE SET NULL not valid;

alter table "public"."cards" validate constraint "cards_word_set_id_fkey";

alter table "public"."friend_requests" add constraint "friend_requests_receiver_id_fkey" FOREIGN KEY (receiver_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."friend_requests" validate constraint "friend_requests_receiver_id_fkey";

alter table "public"."friend_requests" add constraint "friend_requests_sender_id_fkey" FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."friend_requests" validate constraint "friend_requests_sender_id_fkey";

alter table "public"."friend_requests" add constraint "friend_requests_sender_id_receiver_id_key" UNIQUE using index "friend_requests_sender_id_receiver_id_key";

alter table "public"."friend_requests" add constraint "friend_requests_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text]))) not valid;

alter table "public"."friend_requests" validate constraint "friend_requests_status_check";

alter table "public"."friendships" add constraint "friendships_check" CHECK ((user_id < friend_id)) not valid;

alter table "public"."friendships" validate constraint "friendships_check";

alter table "public"."friendships" add constraint "friendships_friend_id_fkey" FOREIGN KEY (friend_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."friendships" validate constraint "friendships_friend_id_fkey";

alter table "public"."friendships" add constraint "friendships_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."friendships" validate constraint "friendships_user_id_fkey";

alter table "public"."friendships" add constraint "friendships_user_id_friend_id_key" UNIQUE using index "friendships_user_id_friend_id_key";

alter table "public"."study_logs" add constraint "study_logs_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."study_logs" validate constraint "study_logs_user_id_fkey";

alter table "public"."user_profiles" add constraint "user_profiles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."user_profiles" validate constraint "user_profiles_user_id_fkey";

alter table "public"."user_profiles" add constraint "user_profiles_user_id_key" UNIQUE using index "user_profiles_user_id_key";

alter table "public"."word_set_collaborators" add constraint "word_set_collaborators_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."word_set_collaborators" validate constraint "word_set_collaborators_user_id_fkey";

alter table "public"."word_set_collaborators" add constraint "word_set_collaborators_word_set_id_fkey" FOREIGN KEY (word_set_id) REFERENCES public.word_sets(id) ON DELETE CASCADE not valid;

alter table "public"."word_set_collaborators" validate constraint "word_set_collaborators_word_set_id_fkey";

alter table "public"."word_set_invitations" add constraint "word_set_invitations_invitee_id_fkey" FOREIGN KEY (invitee_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."word_set_invitations" validate constraint "word_set_invitations_invitee_id_fkey";

alter table "public"."word_set_invitations" add constraint "word_set_invitations_inviter_id_fkey" FOREIGN KEY (inviter_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."word_set_invitations" validate constraint "word_set_invitations_inviter_id_fkey";

alter table "public"."word_set_invitations" add constraint "word_set_invitations_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text]))) not valid;

alter table "public"."word_set_invitations" validate constraint "word_set_invitations_status_check";

alter table "public"."word_set_invitations" add constraint "word_set_invitations_word_set_id_fkey" FOREIGN KEY (word_set_id) REFERENCES public.word_sets(id) ON DELETE CASCADE not valid;

alter table "public"."word_set_invitations" validate constraint "word_set_invitations_word_set_id_fkey";

alter table "public"."word_set_invitations" add constraint "word_set_invitations_word_set_id_invitee_id_key" UNIQUE using index "word_set_invitations_word_set_id_invitee_id_key";

alter table "public"."word_sets" add constraint "word_sets_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."word_sets" validate constraint "word_sets_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.battle_initial_board(p_room_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  cells JSONB := '[]'::jsonb;
  i INT;
  owner_val TEXT;
  hp_now_val INT;
  hp_max_val INT;
  decay_val INT := 10;
BEGIN
  FOR i IN 0..15 LOOP
    IF i = 0 THEN
      owner_val := 'invited';
      hp_now_val := 100;
      hp_max_val := 100;
    ELSIF i = 15 THEN
      owner_val := 'creator';
      hp_now_val := 100;
      hp_max_val := 100;
    ELSE
      owner_val := 'neutral';
      hp_now_val := 120;
      hp_max_val := 400;
    END IF;

    cells := cells || jsonb_build_object(
      'id', i,
      'owner', owner_val,
      'hp_now', hp_now_val,
      'hp_max', hp_max_val,
      'decay_per_hour', decay_val,
      'enemy_pressure', 0
    );
  END LOOP;

  RETURN cells;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.compute_one_battle_step(p_room_id uuid, p_creator_id uuid, p_invited_ids uuid[], p_prev_cells jsonb, p_prev_hour timestamp with time zone, p_bucket_seconds integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_next_hour TIMESTAMPTZ;
  v_prev_hour_end TIMESTAMPTZ;
  v_my_alloc JSONB;
  v_others_alloc JSONB;
  v_new_cells JSONB := '[]'::jsonb;
  v_idx INT;
  v_prev JSONB;
  v_owner TEXT;
  v_hp INT;
  v_hp_max INT;
  v_decay INT;
  v_my_ke INT;
  v_enemy_ke INT;
  v_net INT;
  v_other_rec RECORD;
  v_is_mine BOOLEAN;
  v_cells JSONB;
  v_is_start_cell BOOLEAN;
BEGIN
  v_cells := p_prev_cells;
  v_next_hour := p_prev_hour + make_interval(secs => p_bucket_seconds);
  v_prev_hour_end := p_prev_hour + (p_bucket_seconds || ' seconds')::interval;

  FOR v_idx IN 0..15 LOOP
    v_prev := v_cells->v_idx;
    v_owner := v_prev->>'owner';
    IF v_owner = 'player' THEN
      v_cells := jsonb_set(v_cells, ARRAY[v_idx::text, 'owner'], to_jsonb(
        CASE WHEN auth.uid() = p_creator_id THEN 'creator'::text ELSE 'invited'::text END
      ));
    ELSIF v_owner = 'enemy' THEN
      v_cells := jsonb_set(v_cells, ARRAY[v_idx::text, 'owner'], to_jsonb(
        CASE WHEN auth.uid() = p_creator_id THEN 'invited'::text ELSE 'creator'::text END
      ));
    END IF;
  END LOOP;

  SELECT allocations INTO v_my_alloc
  FROM public.battle_allocations
  WHERE room_id = p_room_id AND user_id = auth.uid()
    AND hour_bucket >= p_prev_hour AND hour_bucket < v_prev_hour_end
  ORDER BY hour_bucket DESC LIMIT 1;
  v_my_alloc := COALESCE(v_my_alloc, '{}'::jsonb);

  v_others_alloc := '{}'::jsonb;
  FOR v_other_rec IN
    SELECT DISTINCT ON (user_id) user_id, allocations
    FROM public.battle_allocations
    WHERE room_id = p_room_id AND user_id != auth.uid()
      AND hour_bucket >= p_prev_hour AND hour_bucket < v_prev_hour_end
    ORDER BY user_id, hour_bucket DESC
  LOOP
    FOR v_idx IN 0..15 LOOP
      v_others_alloc := jsonb_set(
        v_others_alloc,
        ARRAY[v_idx::text],
        to_jsonb(
          (COALESCE((v_others_alloc->>v_idx::text)::int, 0)
           + COALESCE((v_other_rec.allocations->>v_idx::text)::int, 0))::text::int
        )
      );
    END LOOP;
  END LOOP;

  FOR v_idx IN 0..15 LOOP
    v_prev := v_cells->v_idx;
    v_owner := v_prev->>'owner';
    v_hp_max := (v_prev->>'hp_max')::int;
    v_decay := (v_prev->>'decay_per_hour')::int;
    v_is_start_cell := (v_idx = 0 OR v_idx = 15) AND v_owner IN ('creator', 'invited');

    IF v_is_start_cell THEN
      v_new_cells := v_new_cells || jsonb_build_object(
        'id', v_idx,
        'owner', v_owner,
        'hp_now', 100,
        'hp_max', 100,
        'decay_per_hour', 0,
        'enemy_pressure', 0
      );
      CONTINUE;
    END IF;

    v_hp := (v_prev->>'hp_now')::int;
    v_my_ke := COALESCE((v_my_alloc->>(v_idx::text))::int, 0);
    v_enemy_ke := COALESCE((v_others_alloc->>(v_idx::text))::int, 0);

    v_is_mine := (v_owner = 'creator' AND auth.uid() = p_creator_id)
      OR (v_owner = 'invited' AND auth.uid() = ANY(p_invited_ids));

    IF v_owner = 'neutral' AND v_my_ke > 0 AND v_enemy_ke > 0 THEN
      v_net := v_my_ke - v_enemy_ke;
      IF v_net > 0 THEN
        v_owner := CASE WHEN auth.uid() = p_creator_id THEN 'creator' ELSE 'invited' END;
        v_hp := LEAST(v_hp_max, v_net);
      ELSIF v_net < 0 THEN
        v_owner := CASE WHEN auth.uid() = p_creator_id THEN 'invited' ELSE 'creator' END;
        v_hp := LEAST(v_hp_max, -v_net);
      ELSE
        v_owner := 'neutral';
        v_hp := 0;
      END IF;
    ELSE
      -- 己方格子：+己方 KE（加固）- 對方 KE（被攻擊）- decay
      -- 對方格子：+對方 KE（加固）- 己方 KE（被攻擊）- decay
      IF v_is_mine THEN
        v_hp := v_hp + v_my_ke - v_enemy_ke;
      ELSE
        v_hp := v_hp + v_enemy_ke - v_my_ke;
      END IF;
      v_hp := v_hp - v_decay;
      v_hp := GREATEST(0, v_hp);
      IF v_hp = 0 AND v_enemy_ke = 0 AND v_my_ke = 0 AND v_is_mine THEN
        v_hp := 1;
      END IF;
      IF v_hp = 0 THEN
        v_owner := 'neutral';
      END IF;
      IF NOT v_is_mine AND v_my_ke > 0 THEN
        IF v_my_ke > v_hp THEN
          v_owner := CASE WHEN auth.uid() = p_creator_id THEN 'creator' ELSE 'invited' END;
          v_hp := LEAST(v_hp_max, v_my_ke - v_hp);
        ELSE
          v_hp := v_hp - v_my_ke;
          v_hp := GREATEST(0, v_hp);
          IF v_hp = 0 THEN
            v_owner := 'neutral';
          END IF;
        END IF;
      END IF;
    END IF;

    v_new_cells := v_new_cells || jsonb_build_object(
      'id', v_idx,
      'owner', v_owner,
      'hp_now', v_hp,
      'hp_max', v_hp_max,
      'decay_per_hour', v_decay,
      'enemy_pressure', 0
    );
  END LOOP;

  INSERT INTO public.battle_board_state (room_id, hour_bucket, cells)
  VALUES (p_room_id, v_next_hour, v_new_cells)
  ON CONFLICT (room_id, hour_bucket) DO UPDATE
    SET cells = EXCLUDED.cells,
        created_at = now();

  RETURN v_new_cells;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_battle_room(p_word_set_id uuid, p_creator_id uuid, p_start_date timestamp with time zone, p_duration_days text DEFAULT '7'::text, p_invited_ids text DEFAULT '[]'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_room_id UUID;
  v_ids UUID[];
  v_owner_id UUID;
BEGIN
  -- 1) 驗證 caller 與參數中的 creator_id 一致
  IF auth.uid() IS DISTINCT FROM p_creator_id THEN
    RAISE EXCEPTION 'Only creator can create a room';
  END IF;

  -- 2) 確認 creator 為該單字集的擁有者
  SELECT user_id INTO v_owner_id FROM public.word_sets WHERE id = p_word_set_id;
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'word_set not found';
  END IF;
  IF v_owner_id IS DISTINCT FROM p_creator_id THEN
    RAISE EXCEPTION 'only word set owner can create battle room';
  END IF;

  -- 3) 解析受邀成員 ID 陣列
  v_ids := COALESCE(
    (SELECT array_agg(elem::uuid) FROM jsonb_array_elements_text((COALESCE(p_invited_ids, '[]')::jsonb)) AS elem),
    '{}'
  );

  -- 4) 建立房間
  INSERT INTO public.battle_rooms (word_set_id, creator_id, start_date, duration_days, invited_member_ids)
  VALUES (p_word_set_id, p_creator_id, p_start_date, (COALESCE(p_duration_days, '7')::int), v_ids)
  RETURNING id INTO v_room_id;

  RETURN v_room_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_word_set_invitation(p_word_set_id uuid, p_invitee_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_owner_id UUID;
  v_invitation_id UUID;
  v_can_invite BOOLEAN;
BEGIN
  SELECT user_id INTO v_owner_id FROM public.word_sets WHERE id = p_word_set_id;
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'word_set not found';
  END IF;

  -- 擁有者或共編者都可以邀請
  v_can_invite := (auth.uid() = v_owner_id)
    OR EXISTS (
      SELECT 1 FROM public.word_set_collaborators
      WHERE word_set_id = p_word_set_id AND user_id = auth.uid()
    );
  IF NOT v_can_invite THEN
    RAISE EXCEPTION 'only owner or collaborator can invite';
  END IF;

  IF EXISTS (SELECT 1 FROM public.word_set_collaborators WHERE word_set_id = p_word_set_id AND user_id = p_invitee_id) THEN
    RAISE EXCEPTION 'user is already a collaborator';
  END IF;

  -- 若對方已經邀請過你（pending），你就不能再邀請對方，避免互相重複邀請
  IF EXISTS (
    SELECT 1 FROM public.word_set_invitations
    WHERE word_set_id = p_word_set_id
      AND inviter_id = p_invitee_id
      AND invitee_id = auth.uid()
      AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'cannot invite someone who has already invited you';
  END IF;

  INSERT INTO public.word_set_invitations (word_set_id, inviter_id, invitee_id, status)
  VALUES (p_word_set_id, auth.uid(), p_invitee_id, 'pending')
  ON CONFLICT (word_set_id, invitee_id) DO UPDATE SET updated_at = now()
  RETURNING id INTO v_invitation_id;
  RETURN v_invitation_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.generate_invite_code()
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_active_battle_room_for_user(p_word_set_id uuid)
 RETURNS TABLE(id uuid, word_set_id uuid, creator_id uuid, start_date timestamp with time zone, duration_days integer, invited_member_ids uuid[])
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    br.id,
    br.word_set_id,
    br.creator_id,
    br.start_date,
    br.duration_days,
    br.invited_member_ids
  FROM public.battle_rooms br
  WHERE br.word_set_id = p_word_set_id
    AND (
      br.creator_id = auth.uid()
      OR auth.uid() = ANY(br.invited_member_ids)
    )
    -- 僅回傳「尚在期間內」的房間
    AND now() <= br.start_date + (br.duration_days || ' days')::interval
  ORDER BY br.start_date DESC
  LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_battle_board_state(p_room_id uuid, p_hour_bucket text)
 RETURNS TABLE(cells jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_hour TIMESTAMPTZ;
  v_prev_hour TIMESTAMPTZ;
  v_cached JSONB;
  v_prev_cells JSONB;
  v_allocations JSONB;
  v_my_alloc JSONB;
  v_others_alloc JSONB;
  v_cell JSONB;
  v_new_cells JSONB := '[]'::jsonb;
  v_idx INT;
  v_owner TEXT;
  v_hp INT;
  v_hp_max INT;
  v_decay INT;
  v_my_ke INT;
  v_enemy_ke INT;
  v_other_rec RECORD;
  v_prev JSONB;
BEGIN
  v_hour := (p_hour_bucket::timestamptz);
  v_hour := date_trunc('hour', v_hour);
  v_prev_hour := v_hour - interval '1 hour';

  -- 1) Return cached if exists
  SELECT b.cells INTO v_cached FROM public.battle_board_state b WHERE b.room_id = p_room_id AND b.hour_bucket = v_hour;
  IF v_cached IS NOT NULL AND jsonb_array_length(v_cached) > 0 THEN
    cells := v_cached;
    RETURN NEXT;
    RETURN;
  END IF;

  -- 2) Previous hour board (or initial)
  SELECT b.cells INTO v_prev_cells FROM public.battle_board_state b WHERE b.room_id = p_room_id AND b.hour_bucket = v_prev_hour;
  IF v_prev_cells IS NULL OR jsonb_array_length(v_prev_cells) = 0 THEN
    v_prev_cells := public.battle_initial_board(p_room_id);
  END IF;

  -- 3) 使用「上一小時」的 allocations（客戶端整點送出的是 previousHourBucket）
  SELECT allocations INTO v_my_alloc FROM public.battle_allocations WHERE room_id = p_room_id AND hour_bucket = v_prev_hour AND user_id = auth.uid();
  v_my_alloc := COALESCE(v_my_alloc, '{}'::jsonb);

  v_others_alloc := '{}'::jsonb;
  FOR v_other_rec IN SELECT user_id, allocations FROM public.battle_allocations WHERE room_id = p_room_id AND hour_bucket = v_prev_hour AND user_id != auth.uid()
  LOOP
    FOR v_idx IN 0..15 LOOP
      v_others_alloc := jsonb_set(v_others_alloc, ARRAY[v_idx::text], to_jsonb((COALESCE((v_others_alloc->>v_idx::text)::int, 0) + COALESCE((v_other_rec.allocations->>v_idx::text)::int, 0))::text::int));
    END LOOP;
  END LOOP;

  -- 4) Apply reinforce (my KE to my cells) then decay + enemy pressure then attacks (simplified: one pass per cell)
  FOR v_idx IN 0..15 LOOP
    v_prev := v_prev_cells->v_idx;
    v_owner := v_prev->>'owner';
    v_hp := (v_prev->>'hp_now')::int;
    v_hp_max := (v_prev->>'hp_max')::int;
    v_decay := (v_prev->>'decay_per_hour')::int;
    v_my_ke := (v_my_alloc->>(v_idx::text))::int;
    v_my_ke := COALESCE(v_my_ke, 0);
    v_enemy_ke := (v_others_alloc->>(v_idx::text))::int;
    v_enemy_ke := COALESCE(v_enemy_ke, 0);

    IF v_owner = 'player' THEN
      v_hp := LEAST(v_hp_max, v_hp + v_my_ke);
    END IF;
    v_hp := v_hp - v_enemy_ke - v_decay;
    v_hp := GREATEST(0, v_hp);
    IF v_hp = 0 THEN
      v_owner := 'neutral';
    END IF;

    IF v_owner != 'player' AND v_my_ke > 0 THEN
      IF v_my_ke > v_hp THEN
        v_owner := 'player';
        v_hp := LEAST(v_hp_max, v_my_ke - v_hp);
      ELSE
        v_hp := v_hp - v_my_ke;
        v_hp := GREATEST(0, v_hp);
        IF v_hp = 0 THEN v_owner := 'neutral'; END IF;
      END IF;
    END IF;

    v_new_cells := v_new_cells || jsonb_build_object(
      'id', v_idx,
      'owner', v_owner,
      'hp_now', v_hp,
      'hp_max', v_hp_max,
      'decay_per_hour', v_decay,
      'enemy_pressure', 0
    );
  END LOOP;

  INSERT INTO public.battle_board_state (room_id, hour_bucket, cells) VALUES (p_room_id, v_hour, v_new_cells);

  cells := v_new_cells;
  RETURN NEXT;
  RETURN;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_battle_board_state(p_room_id uuid, p_hour_bucket text, p_bucket_seconds integer DEFAULT 3600)
 RETURNS TABLE(cells jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_creator_id UUID;
  v_invited_ids UUID[];
  v_hour TIMESTAMPTZ;
  v_prev_hour TIMESTAMPTZ;
  v_prev_hour_end TIMESTAMPTZ;
  v_cursor_end TIMESTAMPTZ;
  v_prev_cells JSONB;
  v_my_alloc JSONB;
  v_others_alloc JSONB;
  v_new_cells JSONB := '[]'::jsonb;
  v_idx INT;
  v_owner TEXT;
  v_hp INT;
  v_hp_max INT;
  v_decay INT;
  v_my_ke INT;
  v_enemy_ke INT;
  v_net INT;
  v_other_rec RECORD;
  v_prev JSONB;
  v_bucket_seconds INT;
  v_is_mine BOOLEAN;
  v_output_owner TEXT;
  v_output_cells JSONB := '[]'::jsonb;
  v_cursor_hour TIMESTAMPTZ;
  v_step INT;
  v_max_steps INT := 500;
  v_is_start_cell BOOLEAN;
BEGIN
  SELECT creator_id, invited_member_ids INTO v_creator_id, v_invited_ids
  FROM public.battle_rooms WHERE id = p_room_id LIMIT 1;
  v_creator_id := COALESCE(v_creator_id, auth.uid());
  v_invited_ids := COALESCE(v_invited_ids, '{}');

  v_bucket_seconds := GREATEST(60, COALESCE(p_bucket_seconds, 3600));
  v_hour := to_timestamp(floor(extract(epoch from (p_hour_bucket::timestamptz)) / v_bucket_seconds) * v_bucket_seconds);
  v_prev_hour := v_hour - make_interval(secs => v_bucket_seconds);
  v_prev_hour_end := v_prev_hour + (v_bucket_seconds || ' seconds')::interval;

  SELECT b.cells INTO v_prev_cells
  FROM public.battle_board_state b
  WHERE b.room_id = p_room_id
    AND b.hour_bucket >= v_prev_hour AND b.hour_bucket < v_prev_hour_end
  ORDER BY b.hour_bucket DESC LIMIT 1;

  IF v_prev_cells IS NULL OR jsonb_array_length(v_prev_cells) = 0 THEN
    v_cursor_hour := v_prev_hour;
    v_step := 0;
    v_prev_cells := NULL;
    WHILE v_step < v_max_steps LOOP
      v_cursor_end := v_cursor_hour + (v_bucket_seconds || ' seconds')::interval;
      SELECT b.cells INTO v_prev_cells
      FROM public.battle_board_state b
      WHERE b.room_id = p_room_id
        AND b.hour_bucket >= v_cursor_hour AND b.hour_bucket < v_cursor_end
      ORDER BY b.hour_bucket DESC LIMIT 1;
      IF v_prev_cells IS NOT NULL AND jsonb_array_length(v_prev_cells) > 0 THEN
        EXIT;
      END IF;
      v_prev_cells := NULL;
      v_cursor_hour := v_cursor_hour - make_interval(secs => v_bucket_seconds);
      v_step := v_step + 1;
    END LOOP;

    IF v_prev_cells IS NULL OR jsonb_array_length(v_prev_cells) = 0 THEN
      v_prev_cells := public.battle_initial_board(p_room_id);
      v_cursor_hour := v_prev_hour - make_interval(secs => v_bucket_seconds * v_max_steps);
    ELSE
      v_cursor_hour := v_cursor_hour + make_interval(secs => v_bucket_seconds);
    END IF;

    WHILE v_cursor_hour < v_prev_hour LOOP
      v_prev_cells := public.compute_one_battle_step(
        p_room_id, v_creator_id, v_invited_ids,
        v_prev_cells, v_cursor_hour, v_bucket_seconds
      );
      v_cursor_hour := v_cursor_hour + make_interval(secs => v_bucket_seconds);
    END LOOP;
  END IF;

  FOR v_idx IN 0..15 LOOP
    v_prev := v_prev_cells->v_idx;
    v_owner := v_prev->>'owner';
    IF v_owner = 'player' THEN
      v_prev_cells := jsonb_set(v_prev_cells, ARRAY[v_idx::text, 'owner'], to_jsonb(
        CASE WHEN auth.uid() = v_creator_id THEN 'creator'::text ELSE 'invited'::text END
      ));
    ELSIF v_owner = 'enemy' THEN
      v_prev_cells := jsonb_set(v_prev_cells, ARRAY[v_idx::text, 'owner'], to_jsonb(
        CASE WHEN auth.uid() = v_creator_id THEN 'invited'::text ELSE 'creator'::text END
      ));
    END IF;
  END LOOP;

  SELECT allocations INTO v_my_alloc
  FROM public.battle_allocations
  WHERE room_id = p_room_id AND user_id = auth.uid()
    AND hour_bucket >= v_prev_hour AND hour_bucket < v_prev_hour_end
  ORDER BY hour_bucket DESC LIMIT 1;
  v_my_alloc := COALESCE(v_my_alloc, '{}'::jsonb);

  v_others_alloc := '{}'::jsonb;
  FOR v_other_rec IN
    SELECT DISTINCT ON (user_id) user_id, allocations
    FROM public.battle_allocations
    WHERE room_id = p_room_id AND user_id != auth.uid()
      AND hour_bucket >= v_prev_hour AND hour_bucket < v_prev_hour_end
    ORDER BY user_id, hour_bucket DESC
  LOOP
    FOR v_idx IN 0..15 LOOP
      v_others_alloc := jsonb_set(
        v_others_alloc,
        ARRAY[v_idx::text],
        to_jsonb(
          (COALESCE((v_others_alloc->>v_idx::text)::int, 0)
           + COALESCE((v_other_rec.allocations->>v_idx::text)::int, 0))::text::int
        )
      );
    END LOOP;
  END LOOP;

  FOR v_idx IN 0..15 LOOP
    v_prev := v_prev_cells->v_idx;
    v_owner := v_prev->>'owner';
    v_hp_max := (v_prev->>'hp_max')::int;
    v_decay := (v_prev->>'decay_per_hour')::int;
    v_is_start_cell := (v_idx = 0 OR v_idx = 15) AND v_owner IN ('creator', 'invited');

    IF v_is_start_cell THEN
      v_new_cells := v_new_cells || jsonb_build_object(
        'id', v_idx,
        'owner', v_owner,
        'hp_now', 100,
        'hp_max', 100,
        'decay_per_hour', 0,
        'enemy_pressure', 0
      );
      CONTINUE;
    END IF;

    v_hp := (v_prev->>'hp_now')::int;
    v_my_ke := COALESCE((v_my_alloc->>(v_idx::text))::int, 0);
    v_enemy_ke := COALESCE((v_others_alloc->>(v_idx::text))::int, 0);

    v_is_mine := (v_owner = 'creator' AND auth.uid() = v_creator_id)
      OR (v_owner = 'invited' AND auth.uid() = ANY(v_invited_ids));

    IF v_owner = 'neutral' AND v_my_ke > 0 AND v_enemy_ke > 0 THEN
      v_net := v_my_ke - v_enemy_ke;
      IF v_net > 0 THEN
        v_owner := CASE WHEN auth.uid() = v_creator_id THEN 'creator' ELSE 'invited' END;
        v_hp := LEAST(v_hp_max, v_net);
      ELSIF v_net < 0 THEN
        v_owner := CASE WHEN auth.uid() = v_creator_id THEN 'invited' ELSE 'creator' END;
        v_hp := LEAST(v_hp_max, -v_net);
      ELSE
        v_owner := 'neutral';
        v_hp := 0;
      END IF;
    ELSE
      -- 己方格子：+己方 KE（加固）- 對方 KE（被攻擊）- decay
      -- 對方格子：+對方 KE（加固）- 己方 KE（被攻擊）- decay
      IF v_is_mine THEN
        v_hp := v_hp + v_my_ke - v_enemy_ke;
      ELSE
        v_hp := v_hp + v_enemy_ke - v_my_ke;
      END IF;
      v_hp := v_hp - v_decay;
      v_hp := GREATEST(0, v_hp);
      IF v_hp = 0 AND v_enemy_ke = 0 AND v_my_ke = 0 AND v_is_mine THEN
        v_hp := 1;
      END IF;
      IF v_hp = 0 THEN
        v_owner := 'neutral';
      END IF;
      IF NOT v_is_mine AND v_my_ke > 0 THEN
        IF v_my_ke > v_hp THEN
          v_owner := CASE WHEN auth.uid() = v_creator_id THEN 'creator' ELSE 'invited' END;
          v_hp := LEAST(v_hp_max, v_my_ke - v_hp);
        ELSE
          v_hp := v_hp - v_my_ke;
          v_hp := GREATEST(0, v_hp);
          IF v_hp = 0 THEN
            v_owner := 'neutral';
          END IF;
        END IF;
      END IF;
    END IF;

    v_new_cells := v_new_cells || jsonb_build_object(
      'id', v_idx,
      'owner', v_owner,
      'hp_now', v_hp,
      'hp_max', v_hp_max,
      'decay_per_hour', v_decay,
      'enemy_pressure', 0
    );
  END LOOP;

  INSERT INTO public.battle_board_state (room_id, hour_bucket, cells)
  VALUES (p_room_id, v_hour, v_new_cells)
  ON CONFLICT (room_id, hour_bucket) DO UPDATE
    SET cells = EXCLUDED.cells,
        created_at = now();

  FOR v_idx IN 0..15 LOOP
    v_owner := (v_new_cells->v_idx)->>'owner';
    v_output_owner := CASE v_owner
      WHEN 'creator' THEN CASE WHEN auth.uid() = v_creator_id THEN 'player' ELSE 'enemy' END
      WHEN 'invited' THEN CASE WHEN auth.uid() = v_creator_id THEN 'enemy' ELSE 'player' END
      ELSE 'neutral'
    END;
    v_output_cells := v_output_cells || jsonb_set(
      v_new_cells->v_idx,
      '{owner}',
      to_jsonb(v_output_owner)
    );
  END LOOP;

  cells := v_output_cells;
  RETURN NEXT;
  RETURN;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_battle_round_summary(p_room_id uuid, p_hour_bucket text, p_bucket_seconds integer DEFAULT 3600)
 RETURNS TABLE(blue_allocations jsonb, red_allocations jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_creator_id UUID;
  v_invited_ids UUID[];
  v_bucket_seconds INT;
  v_hour_start TIMESTAMPTZ;
  v_hour_end TIMESTAMPTZ;
  v_blue JSONB := '{}'::jsonb;
  v_red JSONB := '{}'::jsonb;
  v_rec RECORD;
  v_idx INT;
  v_cell_key TEXT;
  v_ke INT;
  v_cur INT;
BEGIN
  -- 僅限房間內成員
  IF NOT EXISTS (
    SELECT 1 FROM public.battle_rooms r
    WHERE r.id = p_room_id AND (r.creator_id = auth.uid() OR auth.uid() = ANY(r.invited_member_ids))
  ) THEN
    RAISE EXCEPTION 'Not a member of this battle room';
  END IF;

  SELECT creator_id, invited_member_ids INTO v_creator_id, v_invited_ids
  FROM public.battle_rooms WHERE id = p_room_id LIMIT 1;
  v_creator_id := COALESCE(v_creator_id, auth.uid());
  v_invited_ids := COALESCE(v_invited_ids, '{}');

  v_bucket_seconds := GREATEST(60, COALESCE(p_bucket_seconds, 3600));
  v_hour_start := to_timestamp(
    floor(extract(epoch from (p_hour_bucket::timestamptz)) / v_bucket_seconds)::bigint * v_bucket_seconds
  );
  v_hour_end := v_hour_start + (v_bucket_seconds || ' seconds')::interval;

  -- 用時間範圍比對，避免 timestamp 精度或不同正規化方式導致對不到
  FOR v_rec IN
    SELECT user_id, allocations
    FROM public.battle_allocations
    WHERE room_id = p_room_id
      AND hour_bucket >= v_hour_start
      AND hour_bucket < v_hour_end
  LOOP
    IF v_rec.user_id = v_creator_id THEN
      -- 藍隊：合併到 v_blue（每個 cell 的 KE 相加）
      FOR v_idx IN 0..15 LOOP
        v_cell_key := v_idx::text;
        v_ke := COALESCE((v_rec.allocations->>v_cell_key)::int, 0);
        IF v_ke > 0 THEN
          v_cur := COALESCE((v_blue->>v_cell_key)::int, 0);
          v_blue := jsonb_set(v_blue, ARRAY[v_cell_key], to_jsonb((v_cur + v_ke)::text::int));
        END IF;
      END LOOP;
    ELSE
      -- 紅隊
      FOR v_idx IN 0..15 LOOP
        v_cell_key := v_idx::text;
        v_ke := COALESCE((v_rec.allocations->>v_cell_key)::int, 0);
        IF v_ke > 0 THEN
          v_cur := COALESCE((v_red->>v_cell_key)::int, 0);
          v_red := jsonb_set(v_red, ARRAY[v_cell_key], to_jsonb((v_cur + v_ke)::text::int));
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_blue, v_red;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_cards_for_word_set(p_word_set_id uuid)
 RETURNS TABLE(id uuid, user_id uuid, word_set_id uuid, title text, content text, is_mastered boolean, srs_level integer, due_at timestamp with time zone, last_reviewed_at timestamp with time zone, correct_streak integer, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT c.id, c.user_id, c.word_set_id, c.title, c.content, c.is_mastered,
         c.srs_level, c.due_at, c.last_reviewed_at, c.correct_streak, c.created_at
  FROM public.cards c
  WHERE c.word_set_id = p_word_set_id
    AND (
      EXISTS (SELECT 1 FROM public.word_sets ws WHERE ws.id = c.word_set_id AND ws.user_id = auth.uid())
      OR EXISTS (
        SELECT 1 FROM public.word_set_collaborators col
        WHERE col.word_set_id = c.word_set_id AND col.user_id = auth.uid()
      )
    );
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_pending_word_set_invitations()
 RETURNS TABLE(id uuid, word_set_id uuid, word_set_title text, inviter_id uuid, inviter_display_name text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT i.id, i.word_set_id, ws.title, i.inviter_id, COALESCE(p.display_name, '使用者'), i.created_at
  FROM public.word_set_invitations i
  JOIN public.word_sets ws ON ws.id = i.word_set_id
  LEFT JOIN public.user_profiles p ON p.user_id = i.inviter_id
  WHERE i.invitee_id = auth.uid() AND i.status = 'pending';
$function$
;

CREATE OR REPLACE FUNCTION public.get_profile_by_invite_code(code text)
 RETURNS TABLE(user_id uuid, display_name text, avatar_url text, level integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT p.user_id, p.display_name, p.avatar_url, COALESCE(p.level, 0)
  FROM public.user_profiles p
  WHERE p.invite_code = code
  LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_visible_word_sets()
 RETURNS TABLE(id uuid, user_id uuid, title text, level text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT ws.id, ws.user_id, ws.title, ws.level, ws.created_at
  FROM public.word_sets ws
  WHERE ws.user_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.word_set_collaborators c
    WHERE c.word_set_id = ws.id
      AND c.user_id = auth.uid()
  );
$function$
;

CREATE OR REPLACE FUNCTION public.get_word_set_collaborators(p_word_set_id uuid)
 RETURNS TABLE(word_set_id uuid, user_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.word_sets w
    WHERE w.id = p_word_set_id
      AND (w.user_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.word_set_collaborators c
        WHERE c.word_set_id = w.id AND c.user_id = auth.uid()
      ))
  ) THEN
    RETURN;  -- 無權限則回傳空
  END IF;

  -- 擁有者 + 共編成員（含擁有者時 UNION 會去重）
  RETURN QUERY
  SELECT w.id, w.user_id
  FROM public.word_sets w
  WHERE w.id = p_word_set_id
  UNION
  SELECT c.word_set_id, c.user_id
  FROM public.word_set_collaborators c
  WHERE c.word_set_id = p_word_set_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_word_set_pending_invitations(p_word_set_id uuid)
 RETURNS TABLE(invitation_id uuid, invitee_id uuid, invitee_display_name text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT i.id, i.invitee_id, COALESCE(p.display_name, '使用者'), i.created_at
  FROM public.word_set_invitations i
  LEFT JOIN public.user_profiles p ON p.user_id = i.invitee_id
  WHERE i.word_set_id = p_word_set_id AND i.status = 'pending'
    AND EXISTS (SELECT 1 FROM public.word_sets ws WHERE ws.id = i.word_set_id AND ws.user_id = auth.uid());
$function$
;

CREATE OR REPLACE FUNCTION public.ke_increment(p_user_id uuid, p_namespace text, p_delta integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if p_delta <= 0 then
    return;
  end if;

  insert into public.battle_energy(user_id, namespace, available_ke, updated_at)
  values (p_user_id, p_namespace, p_delta, now())
  on conflict (user_id, namespace)
  do update set
    available_ke = public.battle_energy.available_ke + excluded.available_ke,
    updated_at = now();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ke_increment(p_user_id uuid, p_namespace text, p_delta text DEFAULT '0'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_delta INT := GREATEST(0, (p_delta::int));
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'User mismatch';
  END IF;
  IF v_delta <= 0 THEN
    RETURN;
  END IF;
  INSERT INTO public.battle_energy (user_id, namespace, available_ke, updated_at)
  VALUES (p_user_id, p_namespace, v_delta, now())
  ON CONFLICT (user_id, namespace) DO UPDATE SET
    available_ke = public.battle_energy.available_ke + v_delta,
    updated_at = now();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.ke_spend(p_user_id uuid, p_namespace text, p_amount integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if p_amount <= 0 then
    return;
  end if;

  update public.battle_energy
  set available_ke = greatest(available_ke - p_amount, 0),
      updated_at = now()
  where user_id = p_user_id
    and namespace = p_namespace;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ke_spend(p_user_id uuid, p_namespace text, p_amount text DEFAULT '0'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_amount INT := GREATEST(0, (p_amount::int));
  v_current INT;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'User mismatch';
  END IF;
  IF v_amount <= 0 THEN
    RETURN;
  END IF;
  SELECT available_ke INTO v_current FROM public.battle_energy WHERE user_id = p_user_id AND namespace = p_namespace;
  v_current := COALESCE(v_current, 0);
  IF v_current < v_amount THEN
    RAISE EXCEPTION 'Insufficient KE: have %, need %', v_current, v_amount;
  END IF;
  UPDATE public.battle_energy SET available_ke = available_ke - v_amount, updated_at = now()
  WHERE user_id = p_user_id AND namespace = p_namespace;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient KE';
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.on_friend_request_accepted()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  u_id UUID;
  f_id UUID;
BEGIN
  IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN
    u_id := LEAST(NEW.sender_id, NEW.receiver_id);
    f_id := GREATEST(NEW.sender_id, NEW.receiver_id);
    INSERT INTO friendships (user_id, friend_id, created_at)
    VALUES (u_id, f_id, NOW())
    ON CONFLICT (user_id, friend_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.respond_word_set_invitation(p_invitation_id uuid, p_accept text DEFAULT 'true'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_invitee_id UUID; v_word_set_id UUID; v_accept BOOLEAN;
BEGIN
  v_accept := lower(trim(p_accept)) = 'true';
  SELECT invitee_id, word_set_id INTO v_invitee_id, v_word_set_id
  FROM public.word_set_invitations WHERE id = p_invitation_id AND status = 'pending';
  IF v_invitee_id IS NULL THEN RAISE EXCEPTION 'invitation not found or already responded'; END IF;
  IF auth.uid() IS DISTINCT FROM v_invitee_id THEN RAISE EXCEPTION 'only invitee can respond'; END IF;
  IF v_accept THEN
    INSERT INTO public.word_set_collaborators (word_set_id, user_id)
    VALUES (v_word_set_id, v_invitee_id) ON CONFLICT (word_set_id, user_id) DO NOTHING;
  END IF;
  UPDATE public.word_set_invitations
  SET status = CASE WHEN v_accept THEN 'accepted' ELSE 'declined' END, updated_at = now()
  WHERE id = p_invitation_id;
END; $function$
;

CREATE OR REPLACE FUNCTION public.set_invite_code_on_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  new_code TEXT;
  attempts INT := 0;
BEGIN
  IF NEW.invite_code IS NULL OR trim(NEW.invite_code) = '' THEN
    LOOP
      new_code := public.generate_invite_code();
      IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE invite_code = new_code) THEN
        NEW.invite_code := new_code;
        EXIT;
      END IF;
      attempts := attempts + 1;
      IF attempts > 50 THEN
        RAISE EXCEPTION 'Could not generate unique invite_code';
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_word_set_collaborators(p_word_set_id uuid, p_collaborator_ids text DEFAULT '[]'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_owner_id UUID;
  v_ids UUID[];
  v_uid UUID;
BEGIN
  SELECT ws.user_id INTO v_owner_id
  FROM public.word_sets ws
  WHERE ws.id = p_word_set_id;

  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'word_set not found';
  END IF;

  IF auth.uid() IS DISTINCT FROM v_owner_id THEN
    RAISE EXCEPTION 'only owner can set collaborators';
  END IF;

  v_ids := ARRAY(
    SELECT (elem::text)::uuid
    FROM jsonb_array_elements_text(COALESCE(p_collaborator_ids::jsonb, '[]'::jsonb)) AS elem
  );

  DELETE FROM public.word_set_collaborators
  WHERE word_set_id = p_word_set_id;

  IF array_length(v_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  FOREACH v_uid IN ARRAY v_ids
  LOOP
    INSERT INTO public.word_set_collaborators (word_set_id, user_id)
    VALUES (p_word_set_id, v_uid)
    ON CONFLICT (word_set_id, user_id) DO NOTHING;
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.submit_battle_allocations(p_room_id uuid, p_hour_bucket text, p_user_id uuid, p_allocations jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_hour TIMESTAMPTZ;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'User mismatch';
  END IF;
  v_hour := date_trunc('hour', (p_hour_bucket::timestamptz));
  INSERT INTO public.battle_allocations (room_id, hour_bucket, user_id, allocations, updated_at)
  VALUES (p_room_id, v_hour, p_user_id, COALESCE(p_allocations, '{}'), now())
  ON CONFLICT (room_id, hour_bucket, user_id) DO UPDATE SET
    allocations = EXCLUDED.allocations,
    updated_at = now();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.submit_battle_allocations(p_room_id uuid, p_hour_bucket text, p_user_id uuid, p_allocations text DEFAULT '{}'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_hour TIMESTAMPTZ;
  v_alloc JSONB;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'User mismatch';
  END IF;
  v_hour := date_trunc('hour', (p_hour_bucket::timestamptz));
  v_alloc := COALESCE((p_allocations::jsonb), '{}'::jsonb);
  INSERT INTO public.battle_allocations (room_id, hour_bucket, user_id, allocations, updated_at)
  VALUES (p_room_id, v_hour, p_user_id, v_alloc, now())
  ON CONFLICT (room_id, hour_bucket, user_id) DO UPDATE SET
    allocations = EXCLUDED.allocations,
    updated_at = now();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.submit_battle_allocations(p_room_id uuid, p_hour_bucket text, p_user_id uuid, p_allocations text DEFAULT '{}'::text, p_bucket_seconds integer DEFAULT 3600)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bucket TIMESTAMPTZ;
  v_alloc JSONB;
  v_bucket_seconds INT;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'User mismatch';
  END IF;

  v_bucket_seconds := GREATEST(60, COALESCE(p_bucket_seconds, 3600));
  v_bucket := to_timestamp(floor(extract(epoch from (p_hour_bucket::timestamptz)) / v_bucket_seconds) * v_bucket_seconds);
  v_alloc := COALESCE((p_allocations::jsonb), '{}'::jsonb);

  INSERT INTO public.battle_allocations (room_id, hour_bucket, user_id, allocations, updated_at)
  VALUES (p_room_id, v_bucket, p_user_id, v_alloc, now())
  ON CONFLICT (room_id, hour_bucket, user_id) DO UPDATE SET
    allocations = EXCLUDED.allocations,
    updated_at = now();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$
;

grant delete on table "public"."battle_allocations" to "anon";

grant insert on table "public"."battle_allocations" to "anon";

grant references on table "public"."battle_allocations" to "anon";

grant select on table "public"."battle_allocations" to "anon";

grant trigger on table "public"."battle_allocations" to "anon";

grant truncate on table "public"."battle_allocations" to "anon";

grant update on table "public"."battle_allocations" to "anon";

grant delete on table "public"."battle_allocations" to "authenticated";

grant insert on table "public"."battle_allocations" to "authenticated";

grant references on table "public"."battle_allocations" to "authenticated";

grant select on table "public"."battle_allocations" to "authenticated";

grant trigger on table "public"."battle_allocations" to "authenticated";

grant truncate on table "public"."battle_allocations" to "authenticated";

grant update on table "public"."battle_allocations" to "authenticated";

grant delete on table "public"."battle_allocations" to "service_role";

grant insert on table "public"."battle_allocations" to "service_role";

grant references on table "public"."battle_allocations" to "service_role";

grant select on table "public"."battle_allocations" to "service_role";

grant trigger on table "public"."battle_allocations" to "service_role";

grant truncate on table "public"."battle_allocations" to "service_role";

grant update on table "public"."battle_allocations" to "service_role";

grant delete on table "public"."battle_board_state" to "anon";

grant insert on table "public"."battle_board_state" to "anon";

grant references on table "public"."battle_board_state" to "anon";

grant select on table "public"."battle_board_state" to "anon";

grant trigger on table "public"."battle_board_state" to "anon";

grant truncate on table "public"."battle_board_state" to "anon";

grant update on table "public"."battle_board_state" to "anon";

grant delete on table "public"."battle_board_state" to "authenticated";

grant insert on table "public"."battle_board_state" to "authenticated";

grant references on table "public"."battle_board_state" to "authenticated";

grant select on table "public"."battle_board_state" to "authenticated";

grant trigger on table "public"."battle_board_state" to "authenticated";

grant truncate on table "public"."battle_board_state" to "authenticated";

grant update on table "public"."battle_board_state" to "authenticated";

grant delete on table "public"."battle_board_state" to "service_role";

grant insert on table "public"."battle_board_state" to "service_role";

grant references on table "public"."battle_board_state" to "service_role";

grant select on table "public"."battle_board_state" to "service_role";

grant trigger on table "public"."battle_board_state" to "service_role";

grant truncate on table "public"."battle_board_state" to "service_role";

grant update on table "public"."battle_board_state" to "service_role";

grant delete on table "public"."battle_energy" to "anon";

grant insert on table "public"."battle_energy" to "anon";

grant references on table "public"."battle_energy" to "anon";

grant select on table "public"."battle_energy" to "anon";

grant trigger on table "public"."battle_energy" to "anon";

grant truncate on table "public"."battle_energy" to "anon";

grant update on table "public"."battle_energy" to "anon";

grant delete on table "public"."battle_energy" to "authenticated";

grant insert on table "public"."battle_energy" to "authenticated";

grant references on table "public"."battle_energy" to "authenticated";

grant select on table "public"."battle_energy" to "authenticated";

grant trigger on table "public"."battle_energy" to "authenticated";

grant truncate on table "public"."battle_energy" to "authenticated";

grant update on table "public"."battle_energy" to "authenticated";

grant delete on table "public"."battle_energy" to "service_role";

grant insert on table "public"."battle_energy" to "service_role";

grant references on table "public"."battle_energy" to "service_role";

grant select on table "public"."battle_energy" to "service_role";

grant trigger on table "public"."battle_energy" to "service_role";

grant truncate on table "public"."battle_energy" to "service_role";

grant update on table "public"."battle_energy" to "service_role";

grant delete on table "public"."battle_rooms" to "anon";

grant insert on table "public"."battle_rooms" to "anon";

grant references on table "public"."battle_rooms" to "anon";

grant select on table "public"."battle_rooms" to "anon";

grant trigger on table "public"."battle_rooms" to "anon";

grant truncate on table "public"."battle_rooms" to "anon";

grant update on table "public"."battle_rooms" to "anon";

grant delete on table "public"."battle_rooms" to "authenticated";

grant insert on table "public"."battle_rooms" to "authenticated";

grant references on table "public"."battle_rooms" to "authenticated";

grant select on table "public"."battle_rooms" to "authenticated";

grant trigger on table "public"."battle_rooms" to "authenticated";

grant truncate on table "public"."battle_rooms" to "authenticated";

grant update on table "public"."battle_rooms" to "authenticated";

grant delete on table "public"."battle_rooms" to "service_role";

grant insert on table "public"."battle_rooms" to "service_role";

grant references on table "public"."battle_rooms" to "service_role";

grant select on table "public"."battle_rooms" to "service_role";

grant trigger on table "public"."battle_rooms" to "service_role";

grant truncate on table "public"."battle_rooms" to "service_role";

grant update on table "public"."battle_rooms" to "service_role";

grant delete on table "public"."cards" to "anon";

grant insert on table "public"."cards" to "anon";

grant references on table "public"."cards" to "anon";

grant select on table "public"."cards" to "anon";

grant trigger on table "public"."cards" to "anon";

grant truncate on table "public"."cards" to "anon";

grant update on table "public"."cards" to "anon";

grant delete on table "public"."cards" to "authenticated";

grant insert on table "public"."cards" to "authenticated";

grant references on table "public"."cards" to "authenticated";

grant select on table "public"."cards" to "authenticated";

grant trigger on table "public"."cards" to "authenticated";

grant truncate on table "public"."cards" to "authenticated";

grant update on table "public"."cards" to "authenticated";

grant delete on table "public"."cards" to "service_role";

grant insert on table "public"."cards" to "service_role";

grant references on table "public"."cards" to "service_role";

grant select on table "public"."cards" to "service_role";

grant trigger on table "public"."cards" to "service_role";

grant truncate on table "public"."cards" to "service_role";

grant update on table "public"."cards" to "service_role";

grant delete on table "public"."friend_requests" to "anon";

grant insert on table "public"."friend_requests" to "anon";

grant references on table "public"."friend_requests" to "anon";

grant select on table "public"."friend_requests" to "anon";

grant trigger on table "public"."friend_requests" to "anon";

grant truncate on table "public"."friend_requests" to "anon";

grant update on table "public"."friend_requests" to "anon";

grant delete on table "public"."friend_requests" to "authenticated";

grant insert on table "public"."friend_requests" to "authenticated";

grant references on table "public"."friend_requests" to "authenticated";

grant select on table "public"."friend_requests" to "authenticated";

grant trigger on table "public"."friend_requests" to "authenticated";

grant truncate on table "public"."friend_requests" to "authenticated";

grant update on table "public"."friend_requests" to "authenticated";

grant delete on table "public"."friend_requests" to "service_role";

grant insert on table "public"."friend_requests" to "service_role";

grant references on table "public"."friend_requests" to "service_role";

grant select on table "public"."friend_requests" to "service_role";

grant trigger on table "public"."friend_requests" to "service_role";

grant truncate on table "public"."friend_requests" to "service_role";

grant update on table "public"."friend_requests" to "service_role";

grant delete on table "public"."friendships" to "anon";

grant insert on table "public"."friendships" to "anon";

grant references on table "public"."friendships" to "anon";

grant select on table "public"."friendships" to "anon";

grant trigger on table "public"."friendships" to "anon";

grant truncate on table "public"."friendships" to "anon";

grant update on table "public"."friendships" to "anon";

grant delete on table "public"."friendships" to "authenticated";

grant insert on table "public"."friendships" to "authenticated";

grant references on table "public"."friendships" to "authenticated";

grant select on table "public"."friendships" to "authenticated";

grant trigger on table "public"."friendships" to "authenticated";

grant truncate on table "public"."friendships" to "authenticated";

grant update on table "public"."friendships" to "authenticated";

grant delete on table "public"."friendships" to "service_role";

grant insert on table "public"."friendships" to "service_role";

grant references on table "public"."friendships" to "service_role";

grant select on table "public"."friendships" to "service_role";

grant trigger on table "public"."friendships" to "service_role";

grant truncate on table "public"."friendships" to "service_role";

grant update on table "public"."friendships" to "service_role";

grant delete on table "public"."study_logs" to "anon";

grant insert on table "public"."study_logs" to "anon";

grant references on table "public"."study_logs" to "anon";

grant select on table "public"."study_logs" to "anon";

grant trigger on table "public"."study_logs" to "anon";

grant truncate on table "public"."study_logs" to "anon";

grant update on table "public"."study_logs" to "anon";

grant delete on table "public"."study_logs" to "authenticated";

grant insert on table "public"."study_logs" to "authenticated";

grant references on table "public"."study_logs" to "authenticated";

grant select on table "public"."study_logs" to "authenticated";

grant trigger on table "public"."study_logs" to "authenticated";

grant truncate on table "public"."study_logs" to "authenticated";

grant update on table "public"."study_logs" to "authenticated";

grant delete on table "public"."study_logs" to "service_role";

grant insert on table "public"."study_logs" to "service_role";

grant references on table "public"."study_logs" to "service_role";

grant select on table "public"."study_logs" to "service_role";

grant trigger on table "public"."study_logs" to "service_role";

grant truncate on table "public"."study_logs" to "service_role";

grant update on table "public"."study_logs" to "service_role";

grant delete on table "public"."user_profiles" to "anon";

grant insert on table "public"."user_profiles" to "anon";

grant references on table "public"."user_profiles" to "anon";

grant select on table "public"."user_profiles" to "anon";

grant trigger on table "public"."user_profiles" to "anon";

grant truncate on table "public"."user_profiles" to "anon";

grant update on table "public"."user_profiles" to "anon";

grant delete on table "public"."user_profiles" to "authenticated";

grant insert on table "public"."user_profiles" to "authenticated";

grant references on table "public"."user_profiles" to "authenticated";

grant select on table "public"."user_profiles" to "authenticated";

grant trigger on table "public"."user_profiles" to "authenticated";

grant truncate on table "public"."user_profiles" to "authenticated";

grant update on table "public"."user_profiles" to "authenticated";

grant delete on table "public"."user_profiles" to "service_role";

grant insert on table "public"."user_profiles" to "service_role";

grant references on table "public"."user_profiles" to "service_role";

grant select on table "public"."user_profiles" to "service_role";

grant trigger on table "public"."user_profiles" to "service_role";

grant truncate on table "public"."user_profiles" to "service_role";

grant update on table "public"."user_profiles" to "service_role";

grant delete on table "public"."word_set_collaborators" to "anon";

grant insert on table "public"."word_set_collaborators" to "anon";

grant references on table "public"."word_set_collaborators" to "anon";

grant select on table "public"."word_set_collaborators" to "anon";

grant trigger on table "public"."word_set_collaborators" to "anon";

grant truncate on table "public"."word_set_collaborators" to "anon";

grant update on table "public"."word_set_collaborators" to "anon";

grant delete on table "public"."word_set_collaborators" to "authenticated";

grant insert on table "public"."word_set_collaborators" to "authenticated";

grant references on table "public"."word_set_collaborators" to "authenticated";

grant select on table "public"."word_set_collaborators" to "authenticated";

grant trigger on table "public"."word_set_collaborators" to "authenticated";

grant truncate on table "public"."word_set_collaborators" to "authenticated";

grant update on table "public"."word_set_collaborators" to "authenticated";

grant delete on table "public"."word_set_collaborators" to "service_role";

grant insert on table "public"."word_set_collaborators" to "service_role";

grant references on table "public"."word_set_collaborators" to "service_role";

grant select on table "public"."word_set_collaborators" to "service_role";

grant trigger on table "public"."word_set_collaborators" to "service_role";

grant truncate on table "public"."word_set_collaborators" to "service_role";

grant update on table "public"."word_set_collaborators" to "service_role";

grant delete on table "public"."word_set_invitations" to "anon";

grant insert on table "public"."word_set_invitations" to "anon";

grant references on table "public"."word_set_invitations" to "anon";

grant select on table "public"."word_set_invitations" to "anon";

grant trigger on table "public"."word_set_invitations" to "anon";

grant truncate on table "public"."word_set_invitations" to "anon";

grant update on table "public"."word_set_invitations" to "anon";

grant delete on table "public"."word_set_invitations" to "authenticated";

grant insert on table "public"."word_set_invitations" to "authenticated";

grant references on table "public"."word_set_invitations" to "authenticated";

grant select on table "public"."word_set_invitations" to "authenticated";

grant trigger on table "public"."word_set_invitations" to "authenticated";

grant truncate on table "public"."word_set_invitations" to "authenticated";

grant update on table "public"."word_set_invitations" to "authenticated";

grant delete on table "public"."word_set_invitations" to "service_role";

grant insert on table "public"."word_set_invitations" to "service_role";

grant references on table "public"."word_set_invitations" to "service_role";

grant select on table "public"."word_set_invitations" to "service_role";

grant trigger on table "public"."word_set_invitations" to "service_role";

grant truncate on table "public"."word_set_invitations" to "service_role";

grant update on table "public"."word_set_invitations" to "service_role";

grant delete on table "public"."word_sets" to "anon";

grant insert on table "public"."word_sets" to "anon";

grant references on table "public"."word_sets" to "anon";

grant select on table "public"."word_sets" to "anon";

grant trigger on table "public"."word_sets" to "anon";

grant truncate on table "public"."word_sets" to "anon";

grant update on table "public"."word_sets" to "anon";

grant delete on table "public"."word_sets" to "authenticated";

grant insert on table "public"."word_sets" to "authenticated";

grant references on table "public"."word_sets" to "authenticated";

grant select on table "public"."word_sets" to "authenticated";

grant trigger on table "public"."word_sets" to "authenticated";

grant truncate on table "public"."word_sets" to "authenticated";

grant update on table "public"."word_sets" to "authenticated";

grant delete on table "public"."word_sets" to "service_role";

grant insert on table "public"."word_sets" to "service_role";

grant references on table "public"."word_sets" to "service_role";

grant select on table "public"."word_sets" to "service_role";

grant trigger on table "public"."word_sets" to "service_role";

grant truncate on table "public"."word_sets" to "service_role";

grant update on table "public"."word_sets" to "service_role";


  create policy "battle_allocations_insert_own"
  on "public"."battle_allocations"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "battle_allocations_select_room"
  on "public"."battle_allocations"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.battle_rooms r
  WHERE ((r.id = battle_allocations.room_id) AND ((r.creator_id = auth.uid()) OR (auth.uid() = ANY (r.invited_member_ids)))))));



  create policy "battle_allocations_update_own"
  on "public"."battle_allocations"
  as permissive
  for update
  to public
using ((auth.uid() = user_id));



  create policy "battle_board_state_all_service"
  on "public"."battle_board_state"
  as permissive
  for all
  to public
using (false);



  create policy "battle_board_state_insert_service"
  on "public"."battle_board_state"
  as permissive
  for insert
  to public
with check (false);



  create policy "battle_board_state_select_room"
  on "public"."battle_board_state"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.battle_rooms r
  WHERE ((r.id = battle_board_state.room_id) AND ((r.creator_id = auth.uid()) OR (auth.uid() = ANY (r.invited_member_ids)))))));



  create policy "battle_energy_own"
  on "public"."battle_energy"
  as permissive
  for all
  to public
using ((auth.uid() = user_id));



  create policy "insert_own_rows"
  on "public"."battle_energy"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "select_own_rows"
  on "public"."battle_energy"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "update_own_rows"
  on "public"."battle_energy"
  as permissive
  for update
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "battle_rooms_creator_all"
  on "public"."battle_rooms"
  as permissive
  for all
  to public
using ((auth.uid() = creator_id));



  create policy "battle_rooms_invited_select"
  on "public"."battle_rooms"
  as permissive
  for select
  to public
using ((auth.uid() = ANY (invited_member_ids)));



  create policy "Users can do everything on own cards"
  on "public"."cards"
  as permissive
  for all
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "cards_delete_own"
  on "public"."cards"
  as permissive
  for delete
  to public
using ((auth.uid() = user_id));



  create policy "cards_insert_own"
  on "public"."cards"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "cards_select_own"
  on "public"."cards"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "cards_update_own"
  on "public"."cards"
  as permissive
  for update
  to public
using ((auth.uid() = user_id));



  create policy "Receivers can update friend requests"
  on "public"."friend_requests"
  as permissive
  for update
  to public
using ((auth.uid() = receiver_id))
with check ((auth.uid() = receiver_id));



  create policy "Users can send friend requests"
  on "public"."friend_requests"
  as permissive
  for insert
  to public
with check ((auth.uid() = sender_id));



  create policy "Users can view own friend requests"
  on "public"."friend_requests"
  as permissive
  for select
  to public
using (((auth.uid() = sender_id) OR (auth.uid() = receiver_id)));



  create policy "Users can delete own friendships"
  on "public"."friendships"
  as permissive
  for delete
  to public
using (((auth.uid() = user_id) OR (auth.uid() = friend_id)));



  create policy "Users can view own friendships"
  on "public"."friendships"
  as permissive
  for select
  to public
using (((auth.uid() = user_id) OR (auth.uid() = friend_id)));



  create policy "Users can do everything on own study_logs"
  on "public"."study_logs"
  as permissive
  for all
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Authenticated users can view profiles for discovery"
  on "public"."user_profiles"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Users can delete own profile"
  on "public"."user_profiles"
  as permissive
  for delete
  to public
using ((auth.uid() = user_id));



  create policy "Users can insert own profile"
  on "public"."user_profiles"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() = user_id));



  create policy "Users can read own profile"
  on "public"."user_profiles"
  as permissive
  for select
  to authenticated
using ((auth.uid() = user_id));



  create policy "Users can update own profile"
  on "public"."user_profiles"
  as permissive
  for update
  to authenticated
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "Users can view own profile"
  on "public"."user_profiles"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "word_set_collab_modify_any_authenticated"
  on "public"."word_set_collaborators"
  as permissive
  for all
  to public
using ((auth.uid() IS NOT NULL))
with check ((auth.uid() IS NOT NULL));



  create policy "word_set_collab_select"
  on "public"."word_set_collaborators"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "word_set_invitations_insert_owner"
  on "public"."word_set_invitations"
  as permissive
  for insert
  to public
with check (((auth.uid() = inviter_id) AND (EXISTS ( SELECT 1
   FROM public.word_sets ws
  WHERE ((ws.id = word_set_invitations.word_set_id) AND (ws.user_id = auth.uid()))))));



  create policy "word_set_invitations_select_invitee"
  on "public"."word_set_invitations"
  as permissive
  for select
  to public
using (((auth.uid() = invitee_id) OR (auth.uid() = inviter_id)));



  create policy "word_set_invitations_update_invitee"
  on "public"."word_set_invitations"
  as permissive
  for update
  to public
using ((auth.uid() = invitee_id));



  create policy "Users can do everything on own word_sets"
  on "public"."word_sets"
  as permissive
  for all
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "word_sets_delete_own"
  on "public"."word_sets"
  as permissive
  for delete
  to public
using ((auth.uid() = user_id));



  create policy "word_sets_insert_own"
  on "public"."word_sets"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "word_sets_select_visible"
  on "public"."word_sets"
  as permissive
  for select
  to public
using (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM public.word_set_collaborators c
  WHERE ((c.word_set_id = word_sets.id) AND (c.user_id = auth.uid()))))));



  create policy "word_sets_update_own"
  on "public"."word_sets"
  as permissive
  for update
  to public
using ((auth.uid() = user_id));


CREATE TRIGGER trigger_friend_request_accepted AFTER UPDATE ON public.friend_requests FOR EACH ROW EXECUTE FUNCTION public.on_friend_request_accepted();

CREATE TRIGGER trg_set_invite_code_on_insert BEFORE INSERT ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.set_invite_code_on_insert();

CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


