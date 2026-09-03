-- Colonne attendue par CollectionRepository pour ordonner le catalogue.
alter table public.cards
  add column if not exists sort_order integer not null default 0;
