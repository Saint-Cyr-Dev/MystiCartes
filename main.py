from jeu_cartes import JeuCartes
from interface import InterfaceJeu

if __name__ == "__main__":
    jeu = JeuCartes()
    # Tu peux initialiser les joueurs ici avec des noms par défaut si tu veux
    jeu.init_joueurs("Joueur 1", "Joueur 2")
    app = InterfaceJeu(jeu)  # Passe l'instance jeu à l'interface
    app.mainloop()
