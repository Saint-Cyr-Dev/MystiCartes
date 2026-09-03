-- Première expérience: backfill des comptes existants et création idempotente
-- d'un deck de départ prêt à jouer, avec au plus 4 exemplaires par carte.

insert into public.profiles (id, display_name)
select
  u.id,
  nullif(btrim(coalesce(u.raw_user_meta_data ->> 'display_name', '')), '')
from auth.users u
on conflict (id) do nothing;

insert into public.currencies (user_id)
select u.id from auth.users u
on conflict (user_id) do nothing;

create or replace function public.create_starter_deck()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_deck_id uuid;
  v_base_card_count integer;
  v_card record;
  v_quantity integer;
  v_copy integer;
  v_card_number integer;
  v_snapshot jsonb := '[]'::jsonb;
  v_player_name text;
begin
  if v_user_id is null then
    raise exception 'Authentification requise.' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 1));

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
    from public.decks d
    where d.user_id = v_user_id and d.status = 'ready'
    order by d.is_selected desc, d.created_at
    limit 1;

  if found then
    select coalesce(
      jsonb_agg(
        substring(c.code from '[0-9]+')::integer
        order by c.sort_order, c.code, copies.copy_number
      ),
      '[]'::jsonb
    )
      into v_snapshot
      from public.deck_cards dc
      join public.cards c on c.id = dc.card_id
      cross join lateral generate_series(1, dc.quantity) copies(copy_number)
      where dc.deck_id = v_deck_id and dc.user_id = v_user_id;

    return jsonb_build_object(
      'deck_id', v_deck_id,
      'deck_snapshot', v_snapshot,
      'player_name', v_player_name,
      'already_existed', true
    );
  end if;

  select count(*)::integer
    into v_base_card_count
    from public.cards c
    where c.is_active and c.code ~ '^CARD_(0[1-9]|1[0-5])$';

  if v_base_card_count <> 15 then
    raise exception 'Le catalogue doit contenir les 15 cartes de base actives.'
      using errcode = '23514';
  end if;

  insert into public.decks (user_id, name, status, is_selected)
  values (v_user_id, 'Deck de départ', 'draft', false)
  returning id into v_deck_id;

  for v_card in
    select
      c.id,
      c.code,
      row_number() over (order by c.sort_order, c.code) as position
    from public.cards c
    where c.is_active and c.code ~ '^CARD_(0[1-9]|1[0-5])$'
    order by c.sort_order, c.code
  loop
    v_quantity := case when v_card.position <= 5 then 4 else 3 end;
    v_card_number := substring(v_card.code from '[0-9]+')::integer;

    insert into public.player_cards (user_id, card_id, quantity)
    values (v_user_id, v_card.id, v_quantity)
    on conflict (user_id, card_id) do update set
      quantity = greatest(public.player_cards.quantity, excluded.quantity);

    insert into public.deck_cards (deck_id, user_id, card_id, quantity)
    values (v_deck_id, v_user_id, v_card.id, v_quantity);

    for v_copy in 1..v_quantity loop
      v_snapshot := v_snapshot || to_jsonb(v_card_number);
    end loop;
  end loop;

  if jsonb_array_length(v_snapshot) <> 50 then
    raise exception 'Le deck de départ doit contenir exactement 50 cartes.'
      using errcode = '23514';
  end if;

  update public.decks
    set status = 'ready', is_selected = true
    where id = v_deck_id and user_id = v_user_id;

  insert into public.rewards (
    user_id, reward_type, amount, metadata, claimed_at
  ) values (
    v_user_id,
    'starter_deck',
    50,
    jsonb_build_object('deck_id', v_deck_id),
    timezone('utc', now())
  );

  return jsonb_build_object(
    'deck_id', v_deck_id,
    'deck_snapshot', v_snapshot,
    'player_name', v_player_name,
    'already_existed', false
  );
end;
$$;

revoke all on function public.create_starter_deck() from public, anon;
grant execute on function public.create_starter_deck() to authenticated;
