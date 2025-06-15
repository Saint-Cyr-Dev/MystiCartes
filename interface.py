import customtkinter as ctk
from tkinter import simpledialog, messagebox
from PIL import Image
from jeu_cartes import JeuCartes 

class InterfaceJeu(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.geometry("900x700")
        self.title("MystiCartes")
        self.jeu = JeuCartes()

        # Chargement des images
        self.images_cartes = {}
        for i in range(1, 16):
            try:
                img = Image.open(f"images/img{i}.png").resize((80, 120))
                self.images_cartes[i] = ctk.CTkImage(light_image=img, dark_image=img, size=(80, 120))
            except Exception as e:
                print(f"Erreur de chargement image {i} :", e)

        self.btn_noms = ctk.CTkButton(self, text="Entrer les noms des joueurs", command=self.demander_noms)
        self.btn_noms.pack(pady=10)

        self.btn_regles = ctk.CTkButton(self, text="Afficher les règles", command=self.show_rules)
        self.btn_regles.pack(pady=10)

        self.btn_piocher = ctk.CTkButton(self, text="Piocher une carte", command=self.piocher_carte, state="disabled")
        self.btn_piocher.pack(pady=10)

        self.label_pv = ctk.CTkLabel(self, text="")
        self.label_pv.pack(pady=10)

        self.frame_main_j1 = ctk.CTkFrame(self)
        self.frame_main_j1.pack(pady=10)

        self.frame_main_j2 = ctk.CTkFrame(self)
        self.frame_main_j2.pack(pady=10)

    def demander_noms(self):
        j1 = simpledialog.askstring("Nom du joueur 1", "Entrez le nom du joueur 1 :", parent=self)
        j2 = simpledialog.askstring("Nom du joueur 2", "Entrez le nom du joueur 2 :", parent=self)

        if j1 and j2:
            self.jeu.init_joueurs(j1, j2)
            self.btn_noms.pack_forget()
            self.btn_piocher.configure(state="normal")
            self.mettre_a_jour()
        else:
            messagebox.showwarning("Erreur", "Veuillez entrer les deux noms.")

    def show_rules(self):
        txt = "\n".join([
            "1: Attaque (-10 PV à l'adversaire)",
            "2: Soin (+10 PV à soi-même)",
            "3: Interdiction de soin (1 tour)",
            "4: Saut de tour pour l'adversaire",
            "5: Rejouer immédiatement",
            "6: Bombe surprise (-10 PV à tous)",
            "7: Échange de points de vie",
            "8: Combo (jouer 2 cartes au prochain tour)",
            "9: Vol de vie (+15 PV, -15 PV adversaire)",
            "10: Vision (voir la main adverse 1 tour)",
            "11: Bouclier (bloque le prochain dégât)",
            "12: Coup critique (-30 PV)",
            "13: Poison (5 PV/tour pendant 3 tours)",
            "14: Copier une carte de l'adversaire",
            "15: Purification (retire malus et poison)",
            "Main max 4 cartes. Tour par tour. Combos autorisés."
        ])
        messagebox.showinfo("Règles du jeu", txt)

    def piocher_carte(self):
        main = self.jeu.main_j1 if self.jeu.tour_j1 else self.jeu.main_j2
        if self.jeu.piocher_carte(main):
            self.mettre_a_jour()
        else:
            messagebox.showinfo("Info", "Impossible de piocher : main pleine ou paquet vide.")

    def jouer_carte(self, carte):
        joueur = 1 if self.jeu.tour_j1 else 2
        main = self.jeu.main_j1 if joueur == 1 else self.jeu.main_j2

        if carte in main:
            self.jeu.jouer_carte(main, carte)
            effet = self.jeu.effet_carte(joueur, carte)
            messagebox.showinfo("Effet de la carte", effet)

            # Vérifie si un joueur a perdu
            if self.jeu.pv_j1 <= 0 or self.jeu.pv_j2 <= 0:
                perdant = self.jeu.j1_nom if self.jeu.pv_j1 <= 0 else self.jeu.j2_nom
                gagnant = self.jeu.j2_nom if perdant == self.jeu.j1_nom else self.jeu.j1_nom
                messagebox.showinfo("Fin de partie", f"{perdant} a perdu ! {gagnant} remporte la partie 🎉")
                self.btn_piocher.configure(state="disabled")
                return  # Arrête ici

            if carte != 5:  # Si ce n'est pas une carte qui permet de rejouer
                self.jeu.tour_j1 = not self.jeu.tour_j1

            self.mettre_a_jour()


    def mettre_a_jour(self):
        self.label_pv.configure(
            text=f"{self.jeu.j1_nom}: {self.jeu.pv_j1} PV | {self.jeu.j2_nom}: {self.jeu.pv_j2} PV\n"
                 f"Tour de {'Joueur 1' if self.jeu.tour_j1 else 'Joueur 2'}")
        self.afficher_mains()

    def afficher_mains(self):
        for widget in self.frame_main_j1.winfo_children():
            widget.destroy()
        for widget in self.frame_main_j2.winfo_children():
            widget.destroy()

        # Afficher main joueur 1
        for idx, carte in enumerate(self.jeu.main_j1):
            image = self.images_cartes.get(carte)
            btn = ctk.CTkButton(self.frame_main_j1, image=image, text="", width=80, height=120,
                                state="normal" if self.jeu.tour_j1 else "disabled",
                                command=lambda c=carte: self.jouer_carte(c))
            btn.grid(row=0, column=idx, padx=5)

        # Afficher main joueur 2
        for idx, carte in enumerate(self.jeu.main_j2):
            image = self.images_cartes.get(carte)
            btn = ctk.CTkButton(self.frame_main_j2, image=image, text="", width=80, height=120,
                                state="normal" if not self.jeu.tour_j1 else "disabled",
                                command=lambda c=carte: self.jouer_carte(c))
            btn.grid(row=0, column=idx, padx=5)


if __name__ == "__main__":
    app = InterfaceJeu()
    app.mainloop()
