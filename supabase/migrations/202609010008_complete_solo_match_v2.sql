-- MystiCartes V2: clôture transactionnelle et idempotente d'un duel solo.
-- Le moteur local fournit le snapshot final; le serveur valide sa structure
-- minimale, enregistre le résultat et attribue les récompenses.

create or replace function public.complete_solo_match_v2(
  p_client_match_id uuid,
  p_deck_id uuid,
  p_ai_key text,
  p_difficulty text,
  p_result text,
  p_win_reason text,
  p_starting_player text,
  p_turn_number integer,
  p_current_phase text,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_state_schema_version integer,
  p_state_snapshot jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_match_id uuid;
  v_difficulty text;
  v_xp integer;
  v_gold integer;
  v_reward_card_id uuid;
  v_total_xp bigint;
  v_total_gold bigint;
  v_account_level integer;
  v_main_count integer;
  v_mythic_count integer;
  v_expected_winner text;
begin
  if v_user_id is null then
    raise exception 'Authentification requise.' using errcode = '42501';
  end if;
  if p_client_match_id is null then
    raise exception 'client_match_id est obligatoire.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_user_id::text || ':' || p_client_match_id::text, 2)
  );

  select m.id, m.xp_awarded, m.gold_awarded
    into v_match_id, v_xp, v_gold
    from public.matches m
    where m.user_id = v_user_id
      and m.client_match_id = p_client_match_id;

  if found then
    select c.total_xp, c.gold, c.account_level
      into v_total_xp, v_total_gold, v_account_level
      from public.currencies c
      where c.user_id = v_user_id;

    select r.card_id
      into v_reward_card_id
      from public.rewards r
      where r.match_id = v_match_id and r.reward_type = 'card'
      limit 1;

    return jsonb_build_object(
      'match_id', v_match_id,
      'xp', v_xp,
      'gold', v_gold,
      'total_xp', v_total_xp,
      'total_gold', v_total_gold,
      'account_level', v_account_level,
      'card_id', v_reward_card_id,
      'already_completed', true
    );
  end if;

  if p_deck_id is null then
    raise exception 'Un deck V2 est obligatoire.' using errcode = '22023';
  end if;
  if nullif(btrim(p_ai_key), '') is null then
    raise exception 'ai_key est obligatoire.' using errcode = '22023';
  end if;

  v_difficulty := case lower(p_difficulty)
    when 'easy' then 'beginner'
    when 'beginner' then 'beginner'
    when 'intermediate' then 'intermediate'
    when 'advanced' then 'advanced'
    when 'expert' then 'expert'
    else null
  end;
  if v_difficulty is null then
    raise exception 'Difficulté invalide.' using errcode = '22023';
  end if;

  if p_result is null or p_result not in ('win', 'loss', 'draw') then
    raise exception 'Résultat invalide.' using errcode = '22023';
  end if;
  if p_win_reason is null
     or (p_result = 'draw' and p_win_reason <> 'simultaneous_zero')
     or (
       p_result in ('win', 'loss')
       and p_win_reason not in (
         'life_points', 'deck_out', 'alternative_effect', 'surrender'
       )
     ) then
    raise exception 'Raison de fin incompatible avec le résultat.'
      using errcode = '22023';
  end if;
  if p_starting_player is null or p_starting_player not in ('player', 'ai') then
    raise exception 'Premier joueur invalide.' using errcode = '22023';
  end if;
  if p_turn_number is null or p_turn_number < 1 then
    raise exception 'Le numéro de tour doit être positif.' using errcode = '22023';
  end if;
  if p_current_phase is null or p_current_phase not in (
    'draw', 'preparation', 'main_1', 'battle', 'main_2', 'end'
  ) then
    raise exception 'Phase invalide.' using errcode = '22023';
  end if;
  if p_started_at is null or p_completed_at is null
     or p_completed_at < p_started_at then
    raise exception 'Chronologie du duel invalide.' using errcode = '22023';
  end if;
  if p_state_schema_version is null
     or p_state_schema_version < 1
     or p_state_schema_version > 32767 then
    raise exception 'Version de snapshot invalide.' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.decks d
    where d.id = p_deck_id
      and d.user_id = v_user_id
      and d.status = 'ready'
      and d.ruleset_version = 'v2-gdd-1.1'
  ) then
    raise exception 'Deck V2 prêt inaccessible.' using errcode = '42501';
  end if;

  select
    coalesce(sum(dc.quantity) filter (where dc.zone = 'main'), 0)::integer,
    coalesce(sum(dc.quantity) filter (where dc.zone = 'mythic'), 0)::integer
    into v_main_count, v_mythic_count
    from public.deck_cards dc
    where dc.deck_id = p_deck_id and dc.user_id = v_user_id;

  if v_main_count <> 40 or v_mythic_count > 15 then
    raise exception 'Composition V2 du deck invalide.' using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.deck_cards dc
    join public.cards c on c.id = dc.card_id
    left join public.player_cards pc
      on pc.user_id = v_user_id and pc.card_id = dc.card_id
    where dc.deck_id = p_deck_id
      and (
        not c.is_active
        or coalesce(pc.quantity, 0) < dc.quantity
        or (dc.zone = 'mythic' and c.category <> 'mythique')
        or (dc.zone = 'main' and c.category = 'mythique')
      )
  ) then
    raise exception 'Le deck contient une carte indisponible ou mal placée.'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.deck_cards dc
    join public.cards c on c.id = dc.card_id
    where dc.deck_id = p_deck_id
    group by lower(btrim(c.name))
    having sum(dc.quantity) > 3
  ) then
    raise exception 'Le deck dépasse trois exemplaires pour un même nom.'
      using errcode = '23514';
  end if;

  if jsonb_typeof(p_state_snapshot) is distinct from 'object'
     or jsonb_typeof(p_state_snapshot -> 'turn') is distinct from 'object'
     or jsonb_typeof(p_state_snapshot -> 'players') is distinct from 'object'
     or jsonb_typeof(p_state_snapshot -> 'schemaVersion') is distinct from 'number'
     or jsonb_typeof(p_state_snapshot #> '{players,player}') is distinct from 'object'
     or jsonb_typeof(p_state_snapshot #> '{players,ai}') is distinct from 'object'
     or jsonb_typeof(p_state_snapshot #> '{players,player,lifePoints}') is distinct from 'number'
     or jsonb_typeof(p_state_snapshot #> '{players,ai,lifePoints}') is distinct from 'number'
     or jsonb_typeof(p_state_snapshot #> '{turn,number}') is distinct from 'number' then
    raise exception 'Structure minimale du snapshot V2 invalide.'
      using errcode = '22023';
  end if;

  if octet_length(p_state_snapshot::text) > 2097152 then
    raise exception 'Le snapshot V2 dépasse la taille maximale de 2 Mio.'
      using errcode = '22023';
  end if;

  if (p_state_snapshot ->> 'schemaVersion')::integer
       is distinct from p_state_schema_version
     or p_state_snapshot ->> 'rulesetVersion'
       is distinct from 'v2-gdd-1.1'
     or (p_state_snapshot #>> '{turn,number}')::integer
       is distinct from p_turn_number
     or p_state_snapshot #>> '{turn,phase}'
       is distinct from p_current_phase
     or (p_state_snapshot #>> '{players,player,lifePoints}')::numeric < 0
     or (p_state_snapshot #>> '{players,ai,lifePoints}')::numeric < 0
     or (p_state_snapshot #>> '{players,player,lifePoints}')::numeric
       <> trunc((p_state_snapshot #>> '{players,player,lifePoints}')::numeric)
     or (p_state_snapshot #>> '{players,ai,lifePoints}')::numeric
       <> trunc((p_state_snapshot #>> '{players,ai,lifePoints}')::numeric) then
    raise exception 'Le snapshot ne correspond pas aux paramètres du duel.'
      using errcode = '22023';
  end if;

  v_expected_winner := case p_result
    when 'win' then 'player'
    when 'loss' then 'ai'
    else 'draw'
  end;
  if p_state_snapshot ->> 'winner' is distinct from v_expected_winner then
    raise exception 'Le vainqueur du snapshot ne correspond pas au résultat.'
      using errcode = '22023';
  end if;

  v_xp := case p_result when 'win' then 120 when 'loss' then 30 else 50 end;
  v_gold := case p_result when 'win' then 50 when 'draw' then 10 else 0 end;

  insert into public.matches (
    client_match_id,
    user_id,
    deck_id,
    mode,
    ruleset_version,
    ai_key,
    difficulty,
    result,
    win_reason,
    starting_player,
    turn_number,
    current_phase,
    state_schema_version,
    state_snapshot,
    started_at,
    completed_at,
    xp_awarded,
    gold_awarded
  ) values (
    p_client_match_id,
    v_user_id,
    p_deck_id,
    'solo',
    'v2-gdd-1.1',
    btrim(p_ai_key),
    v_difficulty,
    p_result,
    p_win_reason,
    p_starting_player,
    p_turn_number,
    p_current_phase,
    p_state_schema_version::smallint,
    p_state_snapshot,
    p_started_at,
    p_completed_at,
    v_xp,
    v_gold
  ) returning id into v_match_id;

  insert into public.match_history (
    match_id, user_id, sequence_number, event_type, payload, occurred_at
  ) values (
    v_match_id,
    v_user_id,
    1,
    'match_completed_v2',
    jsonb_build_object(
      'result', p_result,
      'win_reason', p_win_reason,
      'turn_number', p_turn_number,
      'current_phase', p_current_phase,
      'state_schema_version', p_state_schema_version,
      'ruleset_version', 'v2-gdd-1.1'
    ),
    p_completed_at
  );

  insert into public.currencies (user_id, gold, total_xp)
  values (v_user_id, v_gold, v_xp)
  on conflict (user_id) do update set
    gold = public.currencies.gold + excluded.gold,
    total_xp = public.currencies.total_xp + excluded.total_xp;

  insert into public.ai_progress (
    user_id, ai_key, difficulty, matches_played, wins, losses, draws,
    current_streak, best_win_streak, recent_results, last_played_at
  ) values (
    v_user_id,
    btrim(p_ai_key),
    v_difficulty,
    1,
    case when p_result = 'win' then 1 else 0 end,
    case when p_result = 'loss' then 1 else 0 end,
    case when p_result = 'draw' then 1 else 0 end,
    case when p_result = 'win' then 1 else 0 end,
    case when p_result = 'win' then 1 else 0 end,
    array[p_result],
    p_completed_at
  )
  on conflict (user_id, ai_key, difficulty) do update set
    matches_played = public.ai_progress.matches_played + 1,
    wins = public.ai_progress.wins + case when p_result = 'win' then 1 else 0 end,
    losses = public.ai_progress.losses + case when p_result = 'loss' then 1 else 0 end,
    draws = public.ai_progress.draws + case when p_result = 'draw' then 1 else 0 end,
    current_streak = case
      when p_result = 'win' then greatest(public.ai_progress.current_streak, 0) + 1
      else 0
    end,
    best_win_streak = greatest(
      public.ai_progress.best_win_streak,
      case
        when p_result = 'win' then greatest(public.ai_progress.current_streak, 0) + 1
        else public.ai_progress.best_win_streak
      end
    ),
    recent_results = (array[p_result] || public.ai_progress.recent_results)[1:10],
    last_played_at = p_completed_at;

  insert into public.rewards (user_id, match_id, reward_type, amount)
  values (v_user_id, v_match_id, 'xp', v_xp);

  if v_gold > 0 then
    insert into public.rewards (user_id, match_id, reward_type, amount)
    values (v_user_id, v_match_id, 'gold', v_gold);
  end if;

  if p_result = 'win' then
    select c.id
      into v_reward_card_id
      from public.cards c
      where c.is_active
        and (
          c.set_id is null
          or exists (
            select 1 from public.card_sets cs
            where cs.id = c.set_id and cs.is_active
          )
        )
      order by random()
      limit 1;

    if v_reward_card_id is not null then
      insert into public.player_cards (user_id, card_id, quantity)
      values (v_user_id, v_reward_card_id, 1)
      on conflict (user_id, card_id) do update set
        quantity = public.player_cards.quantity + 1;

      insert into public.rewards (
        user_id, match_id, reward_type, amount, card_id
      ) values (
        v_user_id, v_match_id, 'card', 1, v_reward_card_id
      );
    end if;
  end if;

  select c.total_xp, c.gold, c.account_level
    into v_total_xp, v_total_gold, v_account_level
    from public.currencies c
    where c.user_id = v_user_id;

  return jsonb_build_object(
    'match_id', v_match_id,
    'xp', v_xp,
    'gold', v_gold,
    'total_xp', v_total_xp,
    'total_gold', v_total_gold,
    'account_level', v_account_level,
    'card_id', v_reward_card_id,
    'already_completed', false
  );
end;
$$;

revoke all on function public.complete_solo_match_v2(
  uuid, uuid, text, text, text, text, text, integer, text,
  timestamptz, timestamptz, integer, jsonb
) from public, anon;

grant execute on function public.complete_solo_match_v2(
  uuid, uuid, text, text, text, text, text, integer, text,
  timestamptz, timestamptz, integer, jsonb
) to authenticated;
