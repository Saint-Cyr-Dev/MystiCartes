import random

class JeuCartes:
    def __init__(self):
        self.j1_nom = ""
        self.j2_nom = ""
        self.pv_j1 = 100
        self.pv_j2 = 100
        self.tour_j1 = True
        self.main_j1 = []
        self.main_j2 = []
        self.paquet = list(range(1, 16)) * 4

        # États spéciaux
        self.saut_j1 = False
        self.saut_j2 = False
        self.combo_j1 = 0
        self.combo_j2 = 0
        self.bouclier_j1 = False
        self.bouclier_j2 = False
        self.poison_j1 = 0
        self.poison_j2 = 0

    def init_joueurs(self, j1, j2):
        self.__init__()
        self.j1_nom = j1
        self.j2_nom = j2
        random.shuffle(self.paquet)

    def piocher_carte(self, main):
        if not self.paquet or len(main) >= 4:
            return False
        carte = self.paquet.pop()
        main.append(carte)
        return True

    def peut_piocher(self):
        main = self.main_j1 if self.tour_j1 else self.main_j2
        return len(main) < 4 and bool(self.paquet)

    def jouer_carte(self, main, carte):
        if carte in main:
            main.remove(carte)

    def appliquer_poison(self):
        if self.poison_j1 > 0:
            self.pv_j1 -= 5
            self.poison_j1 -= 1
        if self.poison_j2 > 0:
            self.pv_j2 -= 5
            self.poison_j2 -= 1

    def effet_carte(self, joueur, carte):
        self.appliquer_poison()

        adv = 2 if joueur == 1 else 1
        nom = self.j1_nom if joueur == 1 else self.j2_nom
        adv_nom = self.j2_nom if joueur == 1 else self.j1_nom

        adv_pv = lambda: self.pv_j2 if joueur == 1 else self.pv_j1
        set_adv_pv = lambda v: setattr(self, 'pv_j2' if joueur == 1 else 'pv_j1', v)
        get_bouclier = lambda: self.bouclier_j2 if joueur == 1 else self.bouclier_j1
        set_bouclier = lambda v: setattr(self, 'bouclier_j2' if joueur == 1 else 'bouclier_j1', v)
        get_self_bouclier = lambda: self.bouclier_j1 if joueur == 1 else self.bouclier_j2
        set_self_bouclier = lambda v: setattr(self, 'bouclier_j1' if joueur == 1 else 'bouclier_j2', v)
        adv_main = self.main_j2 if joueur == 1 else self.main_j1
        self_main = self.main_j1 if joueur == 1 else self.main_j2

        texte = ""

        if carte == 1:
            if get_bouclier():
                texte = f"{adv_nom} bloque l'attaque avec un bouclier !"
                set_bouclier(False)
            else:
                set_adv_pv(adv_pv() - 10)
                texte = f"{nom} attaque {adv_nom} (-10 PV)"

        elif carte == 2:
            if (joueur == 1 and self.saut_j1) or (joueur == 2 and self.saut_j2):
                texte = f"{nom} ne peut pas se soigner ce tour !"
            else:
                if joueur == 1:
                    self.pv_j1 += 10
                else:
                    self.pv_j2 += 10
                texte = f"{nom} se soigne (+10 PV)"

        elif carte == 3:
            if joueur == 1:
                self.saut_j2 = True
            else:
                self.saut_j1 = True
            texte = f"{nom} interdit le soin à {adv_nom} au prochain tour !"

        elif carte == 4:
            if joueur == 1:
                self.saut_j2 = "tour"
            else:
                self.saut_j1 = "tour"
            texte = f"{nom} fait sauter un tour à {adv_nom} !"

        elif carte == 5:
            texte = f"{nom} rejoue immédiatement !"

        elif carte == 6:
            self.pv_j1 -= 10
            self.pv_j2 -= 10
            texte = "Bombe surprise ! -10 PV pour tout le monde"

        elif carte == 7:
            self.pv_j1, self.pv_j2 = self.pv_j2, self.pv_j1
            texte = f"{nom} échange les points de vie avec {adv_nom} !"

        elif carte == 8:
            if joueur == 1:
                self.combo_j1 = 2
            else:
                self.combo_j2 = 2
            texte = f"{nom} prépare un combo pour jouer 2 cartes au prochain tour !"

        elif carte == 9:
            if get_bouclier():
                texte = f"{adv_nom} bloque le vol de vie avec un bouclier !"
                set_bouclier(False)
            else:
                if joueur == 1:
                    self.pv_j1 += 15
                    self.pv_j2 -= 15
                else:
                    self.pv_j2 += 15
                    self.pv_j1 -= 15
                texte = f"{nom} vole 15 PV à {adv_nom} !"

        elif carte == 10:
            if adv_main:
                supprimée = adv_main.pop(random.randint(0, len(adv_main) - 1))
                texte = f"{nom} supprime une carte ({supprimée}) de {adv_nom} !"
            else:
                texte = f"{adv_nom} n’a aucune carte à supprimer."

        elif carte == 11:
            set_self_bouclier(True)
            texte = f"{nom} se protège avec un bouclier !"

        elif carte == 12:
            if get_bouclier():
                texte = f"{adv_nom} bloque le coup critique avec un bouclier !"
                set_bouclier(False)
            else:
                set_adv_pv(adv_pv() - 30)
                texte = f"{nom} inflige un coup critique à {adv_nom} (-30 PV)"

        elif carte == 13:
            if joueur == 1:
                self.poison_j2 = 3
            else:
                self.poison_j1 = 3
            texte = f"{nom} empoisonne {adv_nom} (5 PV/tour pendant 3 tours)"

        elif carte == 14:
            if adv_main:
                carte_copiee = random.choice(adv_main)
                texte = f"{nom} copie la carte {carte_copiee} de {adv_nom}.\n"
                texte += self.effet_carte(joueur, carte_copiee)
            else:
                texte = f"{adv_nom} n’a aucune carte à copier."

        elif carte == 15:
            if joueur == 1:
                self.poison_j1 = 0
                self.saut_j1 = False
            else:
                self.poison_j2 = 0
                self.saut_j2 = False
            texte = f"{nom} se purifie : tous les malus sont supprimés."

        # Vérifie défaite
        if self.pv_j1 <= 0 and self.pv_j2 <= 0:
            return texte + "\nMatch nul !"
        elif self.pv_j1 <= 0:
            return texte + f"\n{self.j2_nom} remporte la partie !"
        elif self.pv_j2 <= 0:
            return texte + f"\n{self.j1_nom} remporte la partie !"

        return texte

    def doit_sauter_tour(self):
        if self.tour_j1 and self.saut_j1 == "tour":
            self.saut_j1 = False
            return True
        elif not self.tour_j1 and self.saut_j2 == "tour":
            self.saut_j2 = False
            return True
        return False

    def nombre_cartes_a_jouer(self):
        if self.tour_j1 and self.combo_j1 > 0:
            self.combo_j1 -= 1
            return 2
        elif not self.tour_j1 and self.combo_j2 > 0:
            self.combo_j2 -= 1
            return 2
        return 1
