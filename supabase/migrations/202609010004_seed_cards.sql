-- Catalogue initial des 15 cartes. art_url reste NULL pour activer le fallback
-- vers assets/images/cards/carteN.png dans le client Flutter.
insert into public.cards (
  code, name, description, lore_text, rarity, card_type,
  cost, effect_key, effect_data
) values
  ('CARD_01', 'Attaque', 'Inflige 10 PV de dégâts.', 'Un geste franc vaut parfois mieux qu’un long palabre.', 'common', 'attack', 1, 'attack', '{"damage":10}'),
  ('CARD_02', 'Soin', 'Récupère 10 PV.', 'Les anciens savent quelles feuilles réveillent la force.', 'common', 'heal', 1, 'heal', '{"healing":10}'),
  ('CARD_03', 'Interdiction de soin', 'Empêche le prochain soin adverse.', 'Le remède existe, mais le chemin qui y mène vient de se fermer.', 'uncommon', 'control', 1, 'healing_block', '{}'),
  ('CARD_04', 'Tour sauté', 'Fait perdre son prochain tour à l’adversaire.', 'Même le temps peut trébucher sur un bon piège.', 'uncommon', 'control', 1, 'skip_turn', '{}'),
  ('CARD_05', 'Rejouer', 'Permet de jouer immédiatement une autre carte.', 'Le rythme accélère et la foule réclame un second passage.', 'uncommon', 'utility', 1, 'replay', '{"extra_actions":1}'),
  ('CARD_06', 'Bombe surprise', 'Les deux joueurs perdent 10 PV.', 'Le paquet était beaucoup trop silencieux pour être honnête.', 'rare', 'attack', 2, 'bomb', '{"damage_each":10}'),
  ('CARD_07', 'Échange de vie', 'Échange les PV des deux joueurs.', 'Le masque inverse les fortunes avant que chacun comprenne son nouveau destin.', 'epic', 'utility', 2, 'swap_health', '{}'),
  ('CARD_08', 'Combo', 'Permet de jouer deux cartes au prochain tour.', 'Quand les tambours s’accordent, chaque mouvement en appelle un autre.', 'rare', 'utility', 2, 'combo', '{"next_turn_actions":2}'),
  ('CARD_09', 'Vol de vie', 'Vole 15 PV à l’adversaire.', 'L’ombre boit la vigueur de son rival et marche plus droite.', 'rare', 'attack', 2, 'life_steal', '{"amount":15}'),
  ('CARD_10', 'Destruction', 'Détruit une carte adverse aléatoire.', 'Un souffle traverse la main ennemie; une possibilité disparaît.', 'rare', 'control', 2, 'destroy_card', '{"count":1}'),
  ('CARD_11', 'Bouclier', 'Bloque une attaque compatible.', 'Le métal, le cuir et les prières ne forment plus qu’une seule garde.', 'common', 'defense', 1, 'shield', '{}'),
  ('CARD_12', 'Coup critique', 'Inflige 30 PV de dégâts.', 'Un éclair afrofuturiste fend l’arène au battement exact du tambour.', 'epic', 'attack', 3, 'critical_hit', '{"damage":30}'),
  ('CARD_13', 'Poison', 'Inflige 5 PV au début de trois tours.', 'Trois aubes, trois morsures, et pas une trace sur la calebasse.', 'rare', 'status', 2, 'poison', '{"damage":5,"triggers":3}'),
  ('CARD_14', 'Copie', 'Copie une carte adverse aléatoire, sauf Copie.', 'Le miroir emprunte tous les visages sauf le sien.', 'epic', 'utility', 2, 'copy', '{}'),
  ('CARD_15', 'Purification', 'Supprime les malus actifs.', 'L’eau, la fumée et la parole juste rendent à l’esprit sa clarté.', 'uncommon', 'heal', 1, 'purify', '{}')
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  lore_text = excluded.lore_text,
  rarity = excluded.rarity,
  card_type = excluded.card_type,
  cost = excluded.cost,
  effect_key = excluded.effect_key,
  effect_data = excluded.effect_data,
  is_active = true;
