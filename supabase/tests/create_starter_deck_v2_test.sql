begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;

select plan(8);

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values (
  '10000000-0000-4000-8000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated',
  'authenticated',
  'starter-v2-test@mysticartes.invalid',
  '',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

create temporary table starter_rpc_results (
  call_number integer primary key,
  payload jsonb not null
);

insert into starter_rpc_results values
  (1, public.create_starter_deck_v2());
insert into starter_rpc_results values
  (2, public.create_starter_deck_v2());

select is(
  (select payload ->> 'deck_id' from starter_rpc_results where call_number = 1),
  (select payload ->> 'deck_id' from starter_rpc_results where call_number = 2),
  'les deux appels réutilisent le même deck'
);
select is(
  (select (payload ->> 'already_existed')::boolean
   from starter_rpc_results where call_number = 1),
  false,
  'le premier appel crée le deck'
);
select is(
  (select (payload ->> 'already_existed')::boolean
   from starter_rpc_results where call_number = 2),
  true,
  'le second appel est idempotent'
);
select is(
  (select sum(dc.quantity)::integer
   from public.deck_cards dc
   join starter_rpc_results r
     on dc.deck_id = (r.payload ->> 'deck_id')::uuid
   where r.call_number = 1 and dc.zone = 'main'),
  40,
  'le deck principal contient 40 cartes'
);
select is(
  (select sum(dc.quantity)::integer
   from public.deck_cards dc
   join starter_rpc_results r
     on dc.deck_id = (r.payload ->> 'deck_id')::uuid
   where r.call_number = 1 and dc.zone = 'mythic'),
  1,
  'la Réserve contient une Mythique'
);
select ok(
  not exists (
    select 1
    from public.deck_cards dc
    join starter_rpc_results r
      on dc.deck_id = (r.payload ->> 'deck_id')::uuid
    join public.cards c on c.id = dc.card_id
    where r.call_number = 1
    group by lower(btrim(c.name))
    having sum(dc.quantity) > 3
  ),
  'aucun nom ne dépasse trois exemplaires combinés'
);
select is(
  (select count(*)::integer
   from public.decks d
   where d.user_id = '10000000-0000-4000-8000-000000000001'::uuid
     and d.name = 'Deck de départ Babi'),
  1,
  'un seul deck de départ est créé'
);
select is(
  (select count(*)::integer
   from public.rewards r
   where r.user_id = '10000000-0000-4000-8000-000000000001'::uuid
     and r.reward_type = 'starter_deck_v2'),
  1,
  'une seule récompense starter_deck_v2 est créée'
);

select * from finish();
rollback;
