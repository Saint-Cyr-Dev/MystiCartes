-- MystiCartes: RLS stricte. Les données économiques et de progression sont
-- écrites par les fonctions serveur; le client authentifié les lit seulement.

alter table public.cards enable row level security;

alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.player_cards enable row level security;
alter table public.player_cards force row level security;
alter table public.decks enable row level security;
alter table public.decks force row level security;
alter table public.deck_cards enable row level security;
alter table public.deck_cards force row level security;
alter table public.campaign_progress enable row level security;
alter table public.campaign_progress force row level security;
alter table public.ai_progress enable row level security;
alter table public.ai_progress force row level security;
alter table public.matches enable row level security;
alter table public.matches force row level security;
alter table public.match_history enable row level security;
alter table public.match_history force row level security;
alter table public.currencies enable row level security;
alter table public.currencies force row level security;
alter table public.rewards enable row level security;
alter table public.rewards force row level security;

revoke all on table
  public.profiles,
  public.cards,
  public.player_cards,
  public.decks,
  public.deck_cards,
  public.campaign_progress,
  public.ai_progress,
  public.matches,
  public.match_history,
  public.currencies,
  public.rewards
from anon, authenticated;
grant select on public.cards to anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select on public.player_cards to authenticated;
grant select, insert, update, delete on public.decks to authenticated;
grant select, insert, update, delete on public.deck_cards to authenticated;
grant select on public.campaign_progress to authenticated;
grant select on public.ai_progress to authenticated;
grant select on public.matches to authenticated;
grant select on public.match_history to authenticated;
grant select on public.currencies to authenticated;
grant select on public.rewards to authenticated;
grant usage, select on sequence public.match_history_id_seq to authenticated;

create policy cards_public_read
  on public.cards for select
  to anon, authenticated
  using (is_active);

create policy profiles_read_own
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()));
create policy profiles_insert_own
  on public.profiles for insert
  to authenticated
  with check (id = (select auth.uid()));
create policy profiles_update_own
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy player_cards_read_own
  on public.player_cards for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy decks_read_own
  on public.decks for select
  to authenticated
  using (user_id = (select auth.uid()));
create policy decks_insert_own
  on public.decks for insert
  to authenticated
  with check (user_id = (select auth.uid()));
create policy decks_update_own
  on public.decks for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy decks_delete_own
  on public.decks for delete
  to authenticated
  using (user_id = (select auth.uid()));

create policy deck_cards_read_own
  on public.deck_cards for select
  to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.decks d
      where d.id = deck_id and d.user_id = (select auth.uid())
    )
  );
create policy deck_cards_insert_own
  on public.deck_cards for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.decks d
      where d.id = deck_id and d.user_id = (select auth.uid())
    )
  );
create policy deck_cards_update_own
  on public.deck_cards for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.decks d
      where d.id = deck_id and d.user_id = (select auth.uid())
    )
  );
create policy deck_cards_delete_own
  on public.deck_cards for delete
  to authenticated
  using (user_id = (select auth.uid()));

create policy campaign_progress_read_own
  on public.campaign_progress for select
  to authenticated
  using (user_id = (select auth.uid()));
create policy ai_progress_read_own
  on public.ai_progress for select
  to authenticated
  using (user_id = (select auth.uid()));
create policy matches_read_own
  on public.matches for select
  to authenticated
  using (user_id = (select auth.uid()));
create policy match_history_read_own
  on public.match_history for select
  to authenticated
  using (user_id = (select auth.uid()));
create policy currencies_read_own
  on public.currencies for select
  to authenticated
  using (user_id = (select auth.uid()));
create policy rewards_read_own
  on public.rewards for select
  to authenticated
  using (user_id = (select auth.uid()));
