-- MystiCartes: clôture transactionnelle d'un combat solo.
-- Barème: victoire 120 XP / 50 or, défaite 30 XP / 0 or,
-- match nul 50 XP / 10 or. Une victoire attribue aussi une carte aléatoire.

create or replace function public.complete_solo_match(
  p_deck_id uuid,
  p_ai_key text,
  p_difficulty text,
  p_result text,
  p_turn_count integer,
  p_player_health integer,
  p_ai_health integer,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_deck_snapshot jsonb
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
begin
  if v_user_id is null then
    raise exception 'Authentification requise.' using errcode = '42501';
  end if;

  -- Sérialise les clôtures d'un même joueur et rend les nouvelles tentatives
  -- avec le même started_at idempotentes.
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select m.id, m.xp_awarded, m.gold_awarded
    into v_match_id, v_xp, v_gold
    from public.matches m
    where m.user_id = v_user_id and m.started_at = p_started_at;

  if found then
    select c.total_xp, c.gold, c.account_level
      into v_total_xp, v_total_gold, v_account_level
      from public.currencies c where c.user_id = v_user_id;
    select r.card_id into v_reward_card_id
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
      'card_id', v_reward_card_id
    );
  end if;

  if p_result not in ('win', 'loss', 'draw') then
    raise exception 'Résultat invalide.' using errcode = '22023';
  end if;
  if p_turn_count < 0 or p_completed_at < p_started_at then
    raise exception 'Chronologie du combat invalide.' using errcode = '22023';
  end if;
  if jsonb_typeof(p_deck_snapshot) <> 'array'
     or jsonb_array_length(p_deck_snapshot) <> 50 then
    raise exception 'Le snapshot du deck doit contenir exactement 50 cartes.'
      using errcode = '22023';
  end if;
  if p_deck_id is not null and not exists (
    select 1 from public.decks d
    where d.id = p_deck_id and d.user_id = v_user_id
  ) then
    raise exception 'Deck inaccessible.' using errcode = '42501';
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

  v_xp := case p_result when 'win' then 120 when 'loss' then 30 else 50 end;
  v_gold := case p_result when 'win' then 50 when 'draw' then 10 else 0 end;

  insert into public.matches (
    user_id, deck_id, ai_key, difficulty, result, turn_count,
    player_health, ai_health, started_at, completed_at, deck_snapshot,
    xp_awarded, gold_awarded
  ) values (
    v_user_id, p_deck_id, p_ai_key, v_difficulty, p_result, p_turn_count,
    p_player_health, p_ai_health, p_started_at, p_completed_at,
    p_deck_snapshot, v_xp, v_gold
  ) returning id into v_match_id;

  insert into public.match_history (
    match_id, user_id, sequence_number, event_type, payload, occurred_at
  ) values (
    v_match_id,
    v_user_id,
    1,
    'match_completed',
    jsonb_build_object(
      'result', p_result,
      'turn_count', p_turn_count,
      'player_health', p_player_health,
      'ai_health', p_ai_health
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
    p_ai_key,
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
    select c.id into v_reward_card_id
      from public.cards c
      where c.is_active
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
    from public.currencies c where c.user_id = v_user_id;

  return jsonb_build_object(
    'match_id', v_match_id,
    'xp', v_xp,
    'gold', v_gold,
    'total_xp', v_total_xp,
    'total_gold', v_total_gold,
    'account_level', v_account_level,
    'card_id', v_reward_card_id
  );
end;
$$;

revoke all on function public.complete_solo_match(
  uuid, text, text, text, integer, integer, integer,
  timestamptz, timestamptz, jsonb
) from public, anon;
grant execute on function public.complete_solo_match(
  uuid, text, text, text, integer, integer, integer,
  timestamptz, timestamptz, jsonb
) to authenticated;
