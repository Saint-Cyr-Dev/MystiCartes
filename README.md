# 🎴 MystiCartes

MystiCartes est un jeu de cartes stratégique en Python avec interface graphique, où deux joueurs s’affrontent à l’aide d’un paquet de 15 cartes uniques. Chaque carte possède un effet spécial qui peut influencer la partie : attaques, soins, malus, combos, vol de vie, boucliers, etc. Le premier joueur à faire tomber les PV de son adversaire à 0 remporte la partie !

---

## 📸 Capture d'écran

![MystiCartes screenshot](images/preview.png)  
_Interface réalisée en CustomTkinter (exemple fictif)_

---

## 🧩 Fonctionnalités

- 🔁 Jeu tour par tour entre deux joueurs humains
- 🃏 15 cartes différentes avec des effets stratégiques
- 👥 Choix des noms des joueurs en début de partie
- 🧠 Cartes spéciales : vision, combo, poison, échange de PV, vol de carte, etc.
- 🖼️ Affichage des cartes avec images (img1.png → img15.png)
- 🧪 Effets actifs persistants (poison sur plusieurs tours, combos, etc.)
- ❌ Fin automatique de la partie lorsqu’un joueur atteint 0 PV

---

## 🛠️ Technologies utilisées

- Python 3.10+
- [CustomTkinter](https://github.com/TomSchimansky/CustomTkinter) (interface moderne)
- Tkinter (boîtes de dialogue)
- POO (Programmation Orientée Objet)

---

## 📁 Structure du projet

MystiCartes/
├── main.py # Lancement de l'application
├── interface.py # Interface utilisateur (CustomTkinter)
├── jeu_cartes.py # Logique du jeu et des cartes
├── images/ # Images des cartes (img1.png à img15.png)
├── README.md # Ce fichier
└── requirements.txt # (Optionnel) Dépendances

yaml
Copier
Modifier

---

## ▶️ Lancer le jeu

1. **Cloner le dépôt** :

```bash
git clone https://github.com/ton-utilisateur/MystiCartes.git
cd MystiCartes
Installer les dépendances :

bash
Copier
Modifier
pip install customtkinter
Lancer le jeu :

bash
Copier
Modifier
python main.py
📜 Règles du jeu
Chaque joueur commence avec 100 points de vie

Les joueurs piochent et jouent des cartes à tour de rôle

La main est limitée à 4 cartes

Cartes spéciales :

Carte 5 : rejouer

Carte 6 : Bombe (‑10 PV à tous)

Carte 8 : combo (jouer 2 cartes au prochain tour)

Carte 10 : vision (voir + supprimer une carte de l'adversaire)

Carte 14 : copie et activation immédiate d’une carte adverse

Le premier joueur à réduire l’adversaire à 0 PV gagne

🧪 À venir
Mode solo (IA)

Effets visuels plus poussés

Sonorisation des actions

Meilleur équilibrage des cartes

🧑‍💻 Auteur
Développé par [Ton Prénom / Pseudo]
📧 Contact : [ton.email@example.com]
📅 Projet éducatif / personnel

```
