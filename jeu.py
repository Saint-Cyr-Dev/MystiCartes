# jeu.py

class JeuCartes:
    def __init__(self):
        self.j1_nom = ""
        self.j2_nom = ""
        self.pv_j1 = 100
        self.pv_j2 = 100
        self.main_j1 = []
        self.main_j2 = []
        self.tour_j1 = True

        self.saut_j1 = False
        self.saut_j2 = False
        self.interdiction_soin_j1 = False
        self.interdiction_soin_j2 = False
        self.combo_j1 = False
        self.combo_j2 = False
        self.vision_j1 = False
        self.vision_j2 = False
        self.poison_j1 = 0
        self.poison_j2 = 0
        self.bouclier_j1 = False
        self.bouclier_j2 = False
        self.rejouer_j1 = False
        self.rejouer_j2 = False

    def init_joueurs(self, j1, j2):
        self.j1_nom = j1
        self.j2_nom = j2
        self.pv_j1 = 100
        self.pv_j2 = 100
        self.main_j1 = []
        self.main_j2 = []

    def get_main(self, joueur):
        return self.main_j1 if joueur == 1 else self.main_j2

    def piocher(self, joueur):
        main = self.get_main(joueur)
        if len(main) >= 4:
            return False
        import random
        carte = random.randint(1, 15)
        main.append(carte)
        return True
