begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;

select plan(13);

select results_eq(
  $$
    select public.solo_match_reward_rarity_v2(roll)
    from (values
      (1, 0.00::double precision),
      (2, 0.699999::double precision),
      (3, 0.70::double precision),
      (4, 0.899999::double precision),
      (5, 0.90::double precision),
      (6, 0.979999::double precision),
      (7, 0.98::double precision),
      (8, 0.999999::double precision)
    ) as samples(position, roll)
    order by position
  $$,
  $$ values
    ('commune'::text),
    ('commune'::text),
    ('rare'::text),
    ('rare'::text),
    ('épique'::text),
    ('épique'::text),
    ('légendaire'::text),
    ('légendaire'::text)
  $$,
  'les intervalles de rareté sont exactement 70/20/8/2'
);

select results_eq(
  $$
    select difficulty, result,
           public.solo_match_xp_reward_v2(result, difficulty)
    from (values
      (1, 'beginner'::text, 'win'::text),
      (2, 'beginner', 'loss'),
      (3, 'beginner', 'draw'),
      (4, 'intermediate', 'win'),
      (5, 'intermediate', 'loss'),
      (6, 'intermediate', 'draw'),
      (7, 'advanced', 'win'),
      (8, 'advanced', 'loss'),
      (9, 'advanced', 'draw'),
      (10, 'expert', 'win'),
      (11, 'expert', 'loss'),
      (12, 'expert', 'draw')
    ) as cases(position, difficulty, result)
    order by position
  $$,
  $$ values
    ('beginner'::text, 'win'::text, 120::integer),
    ('beginner', 'loss', 30),
    ('beginner', 'draw', 50),
    ('intermediate', 'win', 144),
    ('intermediate', 'loss', 36),
    ('intermediate', 'draw', 60),
    ('advanced', 'win', 180),
    ('advanced', 'loss', 45),
    ('advanced', 'draw', 75),
    ('expert', 'win', 240),
    ('expert', 'loss', 60),
    ('expert', 'draw', 100)
  $$,
  'les 12 combinaisons résultat-difficulté donnent le bon XP'
);

select results_eq(
  $$
    select difficulty, result,
           public.solo_match_gold_reward_v2(result, difficulty)
    from (values
      (1, 'beginner'::text, 'win'::text),
      (2, 'beginner', 'loss'),
      (3, 'beginner', 'draw'),
      (4, 'intermediate', 'win'),
      (5, 'intermediate', 'loss'),
      (6, 'intermediate', 'draw'),
      (7, 'advanced', 'win'),
      (8, 'advanced', 'loss'),
      (9, 'advanced', 'draw'),
      (10, 'expert', 'win'),
      (11, 'expert', 'loss'),
      (12, 'expert', 'draw')
    ) as cases(position, difficulty, result)
    order by position
  $$,
  $$ values
    ('beginner'::text, 'win'::text, 50::integer),
    ('beginner', 'loss', 0),
    ('beginner', 'draw', 10),
    ('intermediate', 'win', 60),
    ('intermediate', 'loss', 0),
    ('intermediate', 'draw', 12),
    ('advanced', 'win', 75),
    ('advanced', 'loss', 0),
    ('advanced', 'draw', 15),
    ('expert', 'win', 100),
    ('expert', 'loss', 0),
    ('expert', 'draw', 20)
  $$,
  'les 12 combinaisons résultat-difficulté donnent les bonnes pièces'
);

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
  '11000000-0000-4000-8000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated',
  'authenticated',
  'reward-v2-test@mysticartes.invalid',
  '',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

select set_config(
  'request.jwt.claim.sub',
  '11000000-0000-4000-8000-000000000001',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

create temporary table reward_test_context as
select
  (public.create_starter_deck_v2() ->> 'deck_id')::uuid as deck_id,
  '11000000-0000-4000-8000-000000000011'::uuid as client_match_id;

create temporary table reward_rpc_results (
  call_number integer primary key,
  payload jsonb not null
);

insert into reward_rpc_results
select 1, public.complete_solo_match_v2(
  context.client_match_id,
  context.deck_id,
  'reward-test-ai',
  'expert',
  'win',
  'life_points',
  'player',
  1,
  'end',
  now() - interval '5 minutes',
  now(),
  1,
  jsonb_build_object(
    'schemaVersion', 1,
    'rulesetVersion', 'v2-gdd-1.1',
    'winner', 'player',
    'turn', jsonb_build_object('number', 1, 'phase', 'end'),
    'players', jsonb_build_object(
      'player', jsonb_build_object('lifePoints', 8000),
      'ai', jsonb_build_object('lifePoints', 0)
    )
  )
)
from reward_test_context context;

insert into reward_rpc_results
select 2, public.complete_solo_match_v2(
  context.client_match_id,
  context.deck_id,
  'reward-test-ai',
  'expert',
  'win',
  'life_points',
  'player',
  1,
  'end',
  now() - interval '5 minutes',
  now(),
  1,
  jsonb_build_object(
    'schemaVersion', 1,
    'rulesetVersion', 'v2-gdd-1.1',
    'winner', 'player',
    'turn', jsonb_build_object('number', 1, 'phase', 'end'),
    'players', jsonb_build_object(
      'player', jsonb_build_object('lifePoints', 8000),
      'ai', jsonb_build_object('lifePoints', 0)
    )
  )
)
from reward_test_context context;

select is(
  (select (payload ->> 'already_completed')::boolean
   from reward_rpc_results where call_number = 1),
  false,
  'le premier appel clôture le match'
);
select is(
  (select (payload ->> 'already_completed')::boolean
   from reward_rpc_results where call_number = 2),
  true,
  'le second appel est reconnu comme déjà traité'
);
select is(
  (select payload ->> 'match_id' from reward_rpc_results where call_number = 1),
  (select payload ->> 'match_id' from reward_rpc_results where call_number = 2),
  'les deux appels renvoient le même match'
);
select is(
  (select (payload ->> 'xp')::integer
   from reward_rpc_results where call_number = 1),
  240,
  'une victoire Expert attribue 240 XP'
);
select is(
  (select (payload ->> 'gold')::integer
   from reward_rpc_results where call_number = 1),
  100,
  'une victoire Expert attribue 100 pièces'
);
select is(
  (select count(*)::integer
   from public.matches
   where client_match_id =
     '11000000-0000-4000-8000-000000000011'::uuid),
  1,
  'un seul match est créé pour le client_match_id'
);
select is(
  (select count(*)::integer
   from public.rewards r
   join public.matches m on m.id = r.match_id
   where m.client_match_id =
     '11000000-0000-4000-8000-000000000011'::uuid),
  3,
  'XP, pièces et carte ne sont enregistrés qu’une fois'
);
select is(
  (select total_xp::integer from public.currencies
   where user_id = '11000000-0000-4000-8000-000000000001'::uuid),
  240,
  'le second appel ne double pas le total XP'
);
select is(
  (select gold::integer from public.currencies
   where user_id = '11000000-0000-4000-8000-000000000001'::uuid),
  100,
  'le second appel ne double pas les pièces'
);
select is(
  (select sum(quantity)::integer from public.player_cards
   where user_id = '11000000-0000-4000-8000-000000000001'::uuid),
  44,
  'le second appel ne donne pas une deuxième carte'
);

select * from finish();
rollback;
