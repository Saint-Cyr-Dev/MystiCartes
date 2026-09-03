-- MystiCartes V2: transition du schéma métier V1 vers le GDD V2 v1.1.
-- Les données personnelles et historiques sont conservées. Les cartes et decks
-- V1 sont neutralisés afin de ne pas être utilisables avec le moteur V2.

-- Les fonctions V1 doivent disparaître avant la modification de leurs tables.
drop function if exists public.complete_solo_match(
  uuid, text, text, text, integer, integer, integer,
  timestamptz, timestamptz, jsonb
);
drop function if exists public.create_starter_deck();

drop trigger if exists decks_validate_ready on public.decks;
drop trigger if exists deck_cards_guard_ready on public.deck_cards;
drop function if exists public.validate_ready_deck();
drop function if exists public.guard_ready_deck_composition();

create or replace function public.text_array_has_unique_values(p_values text[])
returns boolean
language sql
immutable
strict
parallel safe
set search_path = public, pg_temp
as $$
  select count(*) = count(distinct value)
  from unnest(p_values) as values_list(value);
$$;

revoke all on function public.text_array_has_unique_values(text[]) from public;

-- ---------------------------------------------------------------------------
-- Sets de cartes
-- ---------------------------------------------------------------------------

create table public.card_sets (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text not null default '',
  released_at timestamptz,
  is_active boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint card_sets_code_format check (
    code = upper(code)
    and code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'
  ),
  constraint card_sets_name_length check (
    char_length(btrim(name)) between 1 and 80
  )
);

create trigger card_sets_set_updated_at
  before update on public.card_sets
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Catalogue V2
-- ---------------------------------------------------------------------------

alter table public.cards
  drop constraint if exists cards_rarity_check;
alter table public.cards
  drop constraint if exists cards_card_type_check;
alter table public.cards
  drop constraint if exists cards_cost_check;

alter table public.cards
  alter column rarity drop default,
  alter column effect_key drop not null;

alter table public.cards
  add column if not exists set_id uuid references public.card_sets(id)
    on delete set null,
  add column if not exists category text,
  add column if not exists subtype text,
  add column if not exists relic_mode text,
  add column if not exists rank smallint,
  add column if not exists atk integer,
  add column if not exists def integer,
  add column if not exists attribute text,
  add column if not exists primary_family text,
  add column if not exists secondary_families text[] not null default '{}'::text[],
  add column if not exists mythic_summon_condition jsonb,
  add column if not exists effect_text text,
  add column if not exists revision integer not null default 1,
  add column if not exists sort_order integer not null default 0;

-- Tous les enregistrements présents avant cette migration appartiennent au
-- prototype V1. Ils restent référencés par player_cards/rewards mais deviennent
-- inactifs et ne pourront entrer dans aucun deck V2.
update public.cards
set
  rarity = case rarity
    when 'common' then 'commune'
    when 'uncommon' then 'rare'
    when 'rare' then 'rare'
    when 'epic' then 'épique'
    when 'legendary' then 'légendaire'
    else 'commune'
  end,
  category = 'action',
  subtype = 'normal',
  relic_mode = null,
  rank = null,
  atk = null,
  def = null,
  attribute = null,
  primary_family = 'babi',
  secondary_families = '{}'::text[],
  mythic_summon_condition = null,
  effect_text = coalesce(description, ''),
  effect_data = coalesce(effect_data, '{}'::jsonb)
    || jsonb_build_object('legacy_v1', true),
  is_active = false;

alter table public.cards
  alter column rarity set default 'commune',
  alter column category set not null,
  alter column primary_family set not null,
  alter column effect_text set default '',
  alter column effect_text set not null;

alter table public.cards
  drop column if exists description,
  drop column if exists card_type,
  drop column if exists cost;

alter table public.cards
  add constraint cards_category_check check (
    category in ('personnage', 'action', 'piège', 'terrain', 'relique', 'mythique')
  ),
  add constraint cards_rarity_v2_check check (
    rarity in ('commune', 'rare', 'épique', 'légendaire')
  ),
  add constraint cards_attribute_check check (
    attribute is null
    or attribute in ('feu', 'eau', 'nature', 'vent', 'lumière', 'ombre', 'terre', 'esprit')
  ),
  add constraint cards_primary_family_check check (
    primary_family in (
      'babi', 'royaume', 'ancêtre', 'masque', 'dozo',
      'forêt', 'lagune', 'savane', 'village', 'maquis'
    )
  ),
  add constraint cards_secondary_families_check check (
    secondary_families <@ array[
      'babi', 'royaume', 'ancêtre', 'masque', 'dozo',
      'forêt', 'lagune', 'savane', 'village', 'maquis'
    ]::text[]
    and not (primary_family = any(secondary_families))
    and public.text_array_has_unique_values(secondary_families)
  ),
  add constraint cards_effect_data_v2_check check (
    jsonb_typeof(effect_data) = 'object'
  ),
  add constraint cards_revision_check check (revision >= 1),
  add constraint cards_category_fields_check check (
    (
      category = 'personnage'
      and subtype is null
      and relic_mode is null
      and rank between 1 and 8
      and atk is not null and atk >= 0
      and def is not null and def >= 0
      and attribute is not null
      and mythic_summon_condition is null
    )
    or (
      category = 'mythique'
      and subtype is null
      and relic_mode is null
      and rank between 9 and 10
      and atk is not null and atk >= 0
      and def is not null and def >= 0
      and attribute is not null
      and jsonb_typeof(mythic_summon_condition) = 'object'
      and (mythic_summon_condition ->> 'method') in ('fusion', 'ancestrale')
      and nullif(btrim(mythic_summon_condition ->> 'trigger_card_code'), '') is not null
    )
    or (
      category = 'action'
      and subtype in ('normal', 'quick', 'continuous', 'equipment')
      and relic_mode is null
      and rank is null and atk is null and def is null
      and mythic_summon_condition is null
    )
    or (
      category = 'piège'
      and subtype in ('normal', 'continuous', 'counter')
      and relic_mode is null
      and rank is null and atk is null and def is null
      and mythic_summon_condition is null
    )
    or (
      category = 'terrain'
      and subtype is null and relic_mode is null
      and rank is null and atk is null and def is null
      and mythic_summon_condition is null
    )
    or (
      category = 'relique'
      and subtype is null
      and relic_mode in ('action', 'equipment', 'alternative_win')
      and rank is null and atk is null and def is null
      and mythic_summon_condition is null
    )
  );

create unique index cards_name_unique_ci
  on public.cards (lower(btrim(name)));
create index cards_set_id_idx on public.cards(set_id);
create index cards_category_idx on public.cards(category) where is_active;
create index cards_primary_family_idx on public.cards(primary_family) where is_active;
create index cards_secondary_families_gin_idx
  on public.cards using gin(secondary_families);

comment on column public.cards.attribute is
  'Attribut V2 optionnel utilisable par toutes les catégories; obligatoire pour Personnage/Mythique.';
comment on column public.cards.mythic_summon_condition is
  'Objet V2 structuré: method, trigger_card_code et materials ou requirements.';

-- ---------------------------------------------------------------------------
-- Définitions des Jetons
-- ---------------------------------------------------------------------------

create table public.token_definitions (
  id uuid primary key default gen_random_uuid(),
  token_key text not null unique,
  name text not null,
  rank smallint not null check (rank between 1 and 8),
  atk integer not null check (atk >= 0),
  def integer not null check (def >= 0),
  attribute text not null check (
    attribute in ('feu', 'eau', 'nature', 'vent', 'lumière', 'ombre', 'terre', 'esprit')
  ),
  primary_family text check (
    primary_family is null
    or primary_family in (
      'babi', 'royaume', 'ancêtre', 'masque', 'dozo',
      'forêt', 'lagune', 'savane', 'village', 'maquis'
    )
  ),
  art_url text,
  data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(data) = 'object'),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint token_definitions_key_format check (
    token_key = lower(token_key)
    and token_key ~ '^[a-z0-9][a-z0-9_]{1,63}$'
  ),
  constraint token_definitions_name_length check (
    char_length(btrim(name)) between 1 and 80
  )
);

create trigger token_definitions_set_updated_at
  before update on public.token_definitions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Decks V2
-- ---------------------------------------------------------------------------

-- Une composition V1 n'est pas compatible avec les règles 40/3/Mythiques.
-- Les decks restent visibles comme archives, mais leur composition est retirée.
update public.decks
set status = 'archived', is_selected = false;
delete from public.deck_cards;

alter table public.decks
  add column if not exists ruleset_version text;
update public.decks
set ruleset_version = 'v1-legacy'
where ruleset_version is null;
alter table public.decks
  alter column ruleset_version set default 'v2-gdd-1.1',
  alter column ruleset_version set not null;

alter table public.deck_cards
  drop constraint if exists deck_cards_quantity_check;
alter table public.deck_cards
  add column if not exists zone text not null default 'main',
  add constraint deck_cards_quantity_v2_check check (quantity between 1 and 3),
  add constraint deck_cards_zone_check check (zone in ('main', 'mythic'));

create index deck_cards_deck_zone_idx on public.deck_cards(deck_id, zone);

create or replace function public.validate_deck_card_zone_v2()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_category text;
  v_is_active boolean;
begin
  select c.category, c.is_active
    into v_category, v_is_active
    from public.cards c
    where c.id = new.card_id;

  if not found or not v_is_active then
    raise exception 'La carte sélectionnée est absente ou inactive.'
      using errcode = '23514';
  end if;

  if (new.zone = 'mythic' and v_category <> 'mythique')
     or (new.zone = 'main' and v_category = 'mythique') then
    raise exception 'La catégorie de la carte est incompatible avec la zone %.', new.zone
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function public.guard_ready_deck_composition_v2()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_deck_id uuid;
begin
  v_deck_id := case when tg_op = 'DELETE' then old.deck_id else new.deck_id end;

  if exists (
    select 1 from public.decks d
    where d.id = v_deck_id and d.status = 'ready'
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

create or replace function public.validate_ready_deck_v2()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_main_count integer;
  v_mythic_count integer;
begin
  if new.status <> 'ready' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status is not distinct from 'ready' then
    return new;
  end if;

  if new.ruleset_version <> 'v2-gdd-1.1' then
    raise exception 'Un deck ready doit utiliser le ruleset v2-gdd-1.1.'
      using errcode = '23514';
  end if;

  select
    coalesce(sum(dc.quantity) filter (where dc.zone = 'main'), 0)::integer,
    coalesce(sum(dc.quantity) filter (where dc.zone = 'mythic'), 0)::integer
    into v_main_count, v_mythic_count
    from public.deck_cards dc
    where dc.deck_id = new.id and dc.user_id = new.user_id;

  if v_main_count <> 40 then
    raise exception 'Le deck principal doit contenir exactement 40 cartes (total actuel: %).',
      v_main_count using errcode = '23514';
  end if;
  if v_mythic_count > 15 then
    raise exception 'La Réserve des Mythiques ne peut pas dépasser 15 cartes.'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.deck_cards dc
    join public.cards c on c.id = dc.card_id
    where dc.deck_id = new.id
      and (
        not c.is_active
        or (dc.zone = 'mythic' and c.category <> 'mythique')
        or (dc.zone = 'main' and c.category = 'mythique')
      )
  ) then
    raise exception 'Le deck contient une carte inactive ou placée dans une zone invalide.'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.deck_cards dc
    join public.cards c on c.id = dc.card_id
    where dc.deck_id = new.id
    group by lower(btrim(c.name))
    having sum(dc.quantity) > 3
  ) then
    raise exception 'Le deck dépasse trois exemplaires pour un même nom.'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.deck_cards dc
    left join public.player_cards pc
      on pc.user_id = new.user_id and pc.card_id = dc.card_id
    where dc.deck_id = new.id
      and coalesce(pc.quantity, 0) < dc.quantity
  ) then
    raise exception 'Le deck utilise plus de cartes que la collection du joueur.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger deck_cards_guard_ready_v2
  before insert or update or delete on public.deck_cards
  for each row execute function public.guard_ready_deck_composition_v2();

create trigger deck_cards_validate_zone_v2
  before insert or update of card_id, zone on public.deck_cards
  for each row execute function public.validate_deck_card_zone_v2();

create trigger decks_validate_ready_v2
  before insert or update of status on public.decks
  for each row execute function public.validate_ready_deck_v2();

revoke all on function public.validate_deck_card_zone_v2() from public;
revoke all on function public.guard_ready_deck_composition_v2() from public;
revoke all on function public.validate_ready_deck_v2() from public;

-- ---------------------------------------------------------------------------
-- Matchs V2
-- ---------------------------------------------------------------------------

alter table public.matches
  add column if not exists client_match_id uuid,
  add column if not exists ruleset_version text,
  add column if not exists win_reason text,
  add column if not exists starting_player text,
  add column if not exists turn_number integer,
  add column if not exists current_phase text,
  add column if not exists state_schema_version smallint,
  add column if not exists state_snapshot jsonb;

update public.matches
set
  client_match_id = coalesce(client_match_id, gen_random_uuid()),
  ruleset_version = coalesce(ruleset_version, 'v1-legacy'),
  win_reason = coalesce(
    win_reason,
    case when result = 'draw' then 'simultaneous_zero' else 'life_points' end
  ),
  starting_player = coalesce(starting_player, 'player'),
  turn_number = coalesce(turn_number, greatest(turn_count, 1)),
  current_phase = coalesce(current_phase, 'end'),
  state_schema_version = coalesce(state_schema_version, 0),
  state_snapshot = coalesce(
    state_snapshot,
    jsonb_build_object(
      'schemaVersion', 0,
      'rulesetVersion', 'v1-legacy',
      'legacyV1', true,
      'turn', jsonb_build_object(
        'number', greatest(turn_count, 1),
        'activePlayer', 'player',
        'phase', 'end'
      ),
      'players', jsonb_build_object(
        'player', jsonb_build_object('lifePoints', greatest(player_health, 0)),
        'ai', jsonb_build_object('lifePoints', greatest(ai_health, 0))
      ),
      'legacyDeckSnapshot', deck_snapshot,
      'winner', case result when 'win' then 'player' when 'loss' then 'ai' else 'draw' end
    )
  );

alter table public.matches
  drop constraint if exists matches_user_id_started_at_key,
  drop constraint if exists matches_turn_count_check,
  drop constraint if exists matches_deck_snapshot_check;

alter table public.matches
  alter column client_match_id set not null,
  alter column ruleset_version set default 'v2-gdd-1.1',
  alter column ruleset_version set not null,
  alter column win_reason set not null,
  alter column starting_player set not null,
  alter column turn_number set not null,
  alter column current_phase set not null,
  alter column state_schema_version set default 1,
  alter column state_schema_version set not null,
  alter column state_snapshot set not null;

alter table public.matches
  drop column if exists turn_count,
  drop column if exists player_health,
  drop column if exists ai_health,
  drop column if exists deck_snapshot;

alter table public.matches
  add constraint matches_client_id_unique unique (user_id, client_match_id),
  add constraint matches_ruleset_version_check check (
    char_length(btrim(ruleset_version)) > 0
  ),
  add constraint matches_starting_player_check check (
    starting_player in ('player', 'ai')
  ),
  add constraint matches_turn_number_check check (turn_number >= 1),
  add constraint matches_current_phase_check check (
    current_phase in ('draw', 'preparation', 'main_1', 'battle', 'main_2', 'end')
  ),
  add constraint matches_state_schema_version_check check (
    state_schema_version >= 0
  ),
  add constraint matches_state_snapshot_check check (
    jsonb_typeof(state_snapshot) = 'object'
  ),
  add constraint matches_state_snapshot_size_check check (
    octet_length(state_snapshot::text) <= 2097152
  ),
  add constraint matches_win_reason_check check (
    (result = 'draw' and win_reason = 'simultaneous_zero')
    or (
      result in ('win', 'loss')
      and win_reason in ('life_points', 'deck_out', 'alternative_effect', 'surrender')
    )
  );

comment on column public.matches.state_snapshot is
  'État final complet du duel local V2: zones, positions, cartes cachées, Cimetière, bannissement, chaîne et modificateurs.';

-- ---------------------------------------------------------------------------
-- RLS et droits
-- ---------------------------------------------------------------------------

alter table public.cards enable row level security;
alter table public.cards force row level security;
alter table public.card_sets enable row level security;
alter table public.card_sets force row level security;
alter table public.token_definitions enable row level security;
alter table public.token_definitions force row level security;

revoke all on table public.card_sets, public.token_definitions
  from anon, authenticated;
grant select on public.card_sets, public.token_definitions
  to anon, authenticated;

drop policy if exists cards_public_read on public.cards;
create policy cards_public_read
  on public.cards for select
  to anon, authenticated
  using (
    is_active
    and (
      set_id is null
      or exists (
        select 1 from public.card_sets cs
        where cs.id = set_id and cs.is_active
      )
    )
  );

create policy card_sets_public_read
  on public.card_sets for select
  to anon, authenticated
  using (is_active);

create policy token_definitions_public_read
  on public.token_definitions for select
  to anon, authenticated
  using (is_active);

-- Les tables personnelles déjà protégées conservent leurs politiques V1.
-- On réaffirme que matches est en lecture seule côté client.
revoke insert, update, delete on table public.matches
  from anon, authenticated;
