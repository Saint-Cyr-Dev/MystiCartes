-- MystiCartes: schéma initial du catalogue et des données personnelles.
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint profiles_username_format check (
    username is null or username ~ '^[A-Za-z0-9_]{3,24}$'
  ),
  constraint profiles_display_name_length check (
    display_name is null or char_length(display_name) between 1 and 40
  )
);

create unique index profiles_username_unique_ci
  on public.profiles (lower(username))
  where username is not null;

create table public.cards (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text not null default '',
  lore_text text,
  rarity text not null default 'common'
    check (rarity in ('common', 'uncommon', 'rare', 'epic', 'legendary')),
  card_type text not null
    check (card_type in ('attack', 'heal', 'control', 'utility', 'defense', 'status')),
  cost smallint not null default 0 check (cost >= 0),
  effect_key text not null,
  effect_data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(effect_data) = 'object'),
  art_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.player_cards (
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id uuid not null references public.cards(id) on delete restrict,
  quantity integer not null default 1 check (quantity > 0),
  first_acquired_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, card_id)
);

create table public.decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 50),
  status text not null default 'draft'
    check (status in ('draft', 'ready', 'archived')),
  is_selected boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (id, user_id)
);

create unique index decks_one_selected_per_user
  on public.decks (user_id)
  where is_selected and status = 'ready';

create table public.deck_cards (
  deck_id uuid not null,
  user_id uuid not null,
  card_id uuid not null references public.cards(id) on delete restrict,
  quantity smallint not null check (quantity between 1 and 4),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (deck_id, card_id),
  foreign key (deck_id, user_id)
    references public.decks(id, user_id) on delete cascade
);

create table public.campaign_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  campaign_key text not null,
  stage_key text not null,
  status text not null default 'locked'
    check (status in ('locked', 'available', 'completed')),
  stars smallint not null default 0 check (stars between 0 and 3),
  best_score integer not null default 0 check (best_score >= 0),
  attempts integer not null default 0 check (attempts >= 0),
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, campaign_key, stage_key)
);

create table public.ai_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ai_key text not null,
  difficulty text not null
    check (difficulty in ('beginner', 'intermediate', 'advanced', 'expert')),
  matches_played integer not null default 0 check (matches_played >= 0),
  wins integer not null default 0 check (wins >= 0),
  losses integer not null default 0 check (losses >= 0),
  draws integer not null default 0 check (draws >= 0),
  current_streak integer not null default 0,
  best_win_streak integer not null default 0 check (best_win_streak >= 0),
  recent_results text[] not null default '{}'::text[],
  last_played_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, ai_key, difficulty),
  constraint ai_progress_totals check (wins + losses + draws <= matches_played),
  constraint ai_progress_recent_results check (
    recent_results <@ array['win', 'loss', 'draw']::text[]
    and cardinality(recent_results) <= 10
  )
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  deck_id uuid references public.decks(id) on delete set null,
  mode text not null default 'solo' check (mode = 'solo'),
  ai_key text not null,
  difficulty text not null
    check (difficulty in ('beginner', 'intermediate', 'advanced', 'expert')),
  result text not null check (result in ('win', 'loss', 'draw')),
  turn_count integer not null check (turn_count >= 0),
  player_health integer not null,
  ai_health integer not null,
  started_at timestamptz not null,
  completed_at timestamptz not null,
  deck_snapshot jsonb not null default '[]'::jsonb
    check (jsonb_typeof(deck_snapshot) = 'array'),
  xp_awarded integer not null default 0 check (xp_awarded >= 0),
  gold_awarded integer not null default 0 check (gold_awarded >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  constraint matches_date_order check (completed_at >= started_at),
  unique (user_id, started_at)
);

create table public.match_history (
  id bigint generated by default as identity primary key,
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  sequence_number integer not null check (sequence_number > 0),
  event_type text not null,
  payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload) = 'object'),
  occurred_at timestamptz not null default timezone('utc', now()),
  unique (match_id, sequence_number)
);

create table public.currencies (
  user_id uuid primary key references auth.users(id) on delete cascade,
  gold bigint not null default 0 check (gold >= 0),
  gems bigint not null default 0 check (gems >= 0),
  total_xp bigint not null default 0 check (total_xp >= 0),
  account_level integer generated always as ((total_xp / 500 + 1)::integer) stored,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on column public.currencies.account_level is
  'Courbe actuelle: niveau = 1 + floor(total_xp / 500).';

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  match_id uuid references public.matches(id) on delete set null,
  reward_type text not null
    check (reward_type in ('xp', 'gold', 'gems', 'card', 'starter_deck', 'campaign')),
  amount integer not null default 1 check (amount > 0),
  card_id uuid references public.cards(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  claimed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  constraint rewards_card_consistency check (
    (reward_type = 'card' and card_id is not null)
    or (reward_type <> 'card' and card_id is null)
  )
);

create index player_cards_user_id_idx on public.player_cards(user_id);
create index decks_user_id_idx on public.decks(user_id);
create index deck_cards_user_id_idx on public.deck_cards(user_id);
create index campaign_progress_user_id_idx on public.campaign_progress(user_id);
create index ai_progress_user_id_idx on public.ai_progress(user_id);
create index matches_user_completed_idx on public.matches(user_id, completed_at desc);
create index match_history_user_idx on public.match_history(user_id, occurred_at desc);
create index rewards_user_created_idx on public.rewards(user_id, created_at desc);

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger cards_set_updated_at before update on public.cards
  for each row execute function public.set_updated_at();
create trigger player_cards_set_updated_at before update on public.player_cards
  for each row execute function public.set_updated_at();
create trigger decks_set_updated_at before update on public.decks
  for each row execute function public.set_updated_at();
create trigger deck_cards_set_updated_at before update on public.deck_cards
  for each row execute function public.set_updated_at();
create trigger campaign_progress_set_updated_at before update on public.campaign_progress
  for each row execute function public.set_updated_at();
create trigger ai_progress_set_updated_at before update on public.ai_progress
  for each row execute function public.set_updated_at();
create trigger currencies_set_updated_at before update on public.currencies
  for each row execute function public.set_updated_at();

create or replace function public.validate_ready_deck()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  card_total integer;
begin
  if new.status = 'ready' and (tg_op = 'INSERT' or old.status is distinct from 'ready') then
    select coalesce(sum(quantity), 0)::integer
      into card_total
      from public.deck_cards
      where deck_id = new.id and user_id = new.user_id;

    if card_total <> 50 then
      raise exception 'Un deck ready doit contenir exactement 50 cartes (total actuel: %).', card_total
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger decks_validate_ready
  before insert or update of status on public.decks
  for each row execute function public.validate_ready_deck();

create or replace function public.guard_ready_deck_composition()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  target_deck_id uuid;
begin
  if tg_op = 'DELETE' then
    target_deck_id := old.deck_id;
  else
    target_deck_id := new.deck_id;
  end if;

  if exists (
    select 1 from public.decks
    where id = target_deck_id and status = 'ready'
  ) then
    raise exception 'Passez le deck en draft avant de modifier sa composition.'
      using errcode = '23514';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger deck_cards_guard_ready
  before insert or update or delete on public.deck_cards
  for each row execute function public.guard_ready_deck_composition();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    nullif(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '')
  )
  on conflict (id) do nothing;

  insert into public.currencies (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

revoke all on function public.set_updated_at() from public;
revoke all on function public.validate_ready_deck() from public;
revoke all on function public.guard_ready_deck_composition() from public;
revoke all on function public.handle_new_user() from public;
