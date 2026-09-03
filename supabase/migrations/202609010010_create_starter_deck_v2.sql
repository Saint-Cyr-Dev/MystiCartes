-- Deck d'initiation V2 : famille Babi.
-- Babi est retenue pour ses interactions directes (attaque, position, cartes
-- posées) et évite les mécaniques plus indirectes de Cimetière/retournement.

alter table public.rewards
  drop constraint if exists rewards_reward_type_check;
alter table public.rewards
  add constraint rewards_reward_type_check check (
    reward_type in (
      'xp', 'gold', 'gems', 'card', 'starter_deck',
      'starter_deck_v2', 'campaign'
    )
  );

create unique index if not exists rewards_one_starter_deck_v2_per_user
  on public.rewards(user_id, reward_type)
  where reward_type = 'starter_deck_v2';

create or replace function public.create_starter_deck_v2()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_deck_id uuid;
  v_player_name text;
  v_non_mythic_count integer;
  v_main_count integer;
  v_main_deck jsonb;
  v_mythic_reserve jsonb;
  v_already_existed boolean := false;
begin
  if v_user_id is null then
    raise exception 'Authentification requise.' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 10));

  select coalesce(
    nullif(btrim(p.display_name), ''),
    nullif(btrim(p.username), ''),
    'Joueur'
  ) into v_player_name
  from public.profiles p
  where p.id = v_user_id;
  v_player_name := coalesce(v_player_name, 'Joueur');

  select d.id
    into v_deck_id
    from public.rewards r
    join public.decks d
      on d.id = (r.metadata ->> 'deck_id')::uuid
     and d.user_id = r.user_id
    where r.user_id = v_user_id
      and r.reward_type = 'starter_deck_v2'
      and d.ruleset_version = 'v2-gdd-1.1'
    order by r.created_at
    limit 1;

  if found then
    v_already_existed := true;
  else
    select count(*)::integer
      into v_non_mythic_count
      from public.cards c
      where c.is_active
        and c.primary_family = 'babi'
        and c.category <> 'mythique';

    if v_non_mythic_count <> 14 then
      raise exception 'La famille Babi doit contenir 14 cartes non-Mythiques actives.'
        using errcode = '23514';
    end if;
    if not exists (
      select 1 from public.cards c
      where c.code = 'BAB-015' and c.category = 'mythique' and c.is_active
    ) then
      raise exception 'La Mythique BAB-015 est absente du catalogue actif.'
        using errcode = '23514';
    end if;

    insert into public.player_cards (user_id, card_id, quantity)
    select
      v_user_id,
      c.id,
      case when c.code = 'BAB-003' then 1 else 3 end
    from public.cards c
    where c.is_active
      and c.primary_family = 'babi'
      and c.category <> 'mythique'
    on conflict (user_id, card_id) do update set
      quantity = greatest(public.player_cards.quantity, excluded.quantity);

    insert into public.player_cards (user_id, card_id, quantity)
    select v_user_id, c.id, 1
    from public.cards c
    where c.code = 'BAB-015' and c.category = 'mythique' and c.is_active
    on conflict (user_id, card_id) do update set
      quantity = greatest(public.player_cards.quantity, excluded.quantity);

    update public.decks
      set is_selected = false
      where user_id = v_user_id and is_selected;

    insert into public.decks (
      user_id, name, status, is_selected, ruleset_version
    ) values (
      v_user_id, 'Deck de départ Babi', 'draft', false, 'v2-gdd-1.1'
    ) returning id into v_deck_id;

    insert into public.deck_cards (
      deck_id, user_id, card_id, quantity, zone
    )
    select
      v_deck_id,
      v_user_id,
      c.id,
      case when c.code = 'BAB-003' then 1 else 3 end,
      'main'
    from public.cards c
    where c.is_active
      and c.primary_family = 'babi'
      and c.category <> 'mythique';

    insert into public.deck_cards (
      deck_id, user_id, card_id, quantity, zone
    )
    select v_deck_id, v_user_id, c.id, 1, 'mythic'
    from public.cards c
    where c.code = 'BAB-015' and c.category = 'mythique' and c.is_active;

    select coalesce(sum(dc.quantity), 0)::integer
      into v_main_count
      from public.deck_cards dc
      where dc.deck_id = v_deck_id and dc.zone = 'main';
    if v_main_count <> 40 then
      raise exception 'Le deck de départ Babi doit contenir exactement 40 cartes principales.'
        using errcode = '23514';
    end if;

    update public.decks
      set status = 'ready', is_selected = true
      where id = v_deck_id and user_id = v_user_id;

    insert into public.rewards (
      user_id, reward_type, amount, metadata, claimed_at
    ) values (
      v_user_id,
      'starter_deck_v2',
      41,
      jsonb_build_object(
        'deck_id', v_deck_id,
        'family', 'babi',
        'main_count', 40,
        'mythic_count', 1,
        'ruleset_version', 'v2-gdd-1.1'
      ),
      timezone('utc', now())
    ) on conflict do nothing;

    update public.rewards
      set metadata = jsonb_build_object(
        'deck_id', v_deck_id,
        'family', 'babi',
        'main_count', 40,
        'mythic_count', 1,
        'ruleset_version', 'v2-gdd-1.1'
      ),
      claimed_at = coalesce(claimed_at, timezone('utc', now()))
      where user_id = v_user_id and reward_type = 'starter_deck_v2';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'code', c.code,
        'name', c.name,
        'category', c.category,
        'subtype', c.subtype,
        'rank', c.rank,
        'atk', c.atk,
        'def', c.def,
        'attribute', c.attribute,
        'primary_family', c.primary_family,
        'secondary_families', c.secondary_families,
        'mythic_summon_condition', c.mythic_summon_condition,
        'effect_key', c.effect_key,
        'effect_data', c.effect_data,
        'revision', c.revision,
        'quantity', dc.quantity
      ) order by c.sort_order, c.code
    ),
    '[]'::jsonb
  ) into v_main_deck
  from public.deck_cards dc
  join public.cards c on c.id = dc.card_id
  where dc.deck_id = v_deck_id and dc.zone = 'main';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'code', c.code,
        'name', c.name,
        'category', c.category,
        'subtype', c.subtype,
        'rank', c.rank,
        'atk', c.atk,
        'def', c.def,
        'attribute', c.attribute,
        'primary_family', c.primary_family,
        'secondary_families', c.secondary_families,
        'mythic_summon_condition', c.mythic_summon_condition,
        'effect_key', c.effect_key,
        'effect_data', c.effect_data,
        'revision', c.revision,
        'quantity', dc.quantity
      ) order by c.sort_order, c.code
    ),
    '[]'::jsonb
  ) into v_mythic_reserve
  from public.deck_cards dc
  join public.cards c on c.id = dc.card_id
  where dc.deck_id = v_deck_id and dc.zone = 'mythic';

  return jsonb_build_object(
    'deck_id', v_deck_id,
    'player_name', v_player_name,
    'family', 'babi',
    'main_deck', v_main_deck,
    'mythic_reserve', v_mythic_reserve,
    'already_existed', v_already_existed
  );
end;
$$;

revoke all on function public.create_starter_deck_v2() from public, anon;
grant execute on function public.create_starter_deck_v2() to authenticated;
