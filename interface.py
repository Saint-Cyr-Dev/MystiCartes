import customtkinter as ctk
from tkinter import messagebox
from PIL import Image
import threading
import time
import os

class InterfaceJeu(ctk.CTk):
    def __init__(self, jeu):
        super().__init__()
        self.geometry("900x600")
        self.title("MystiCartes")

        self.jeu = jeu
        self.images_cartes = {}

        self.cartes_a_jouer = 1  # cartes à jouer ce tour
        self.dernier_rejoue = False

        self.bg_image = ctk.CTkImage(Image.open("images/background.png"), size=(1920, 1080))
        self.bg_label = ctk.CTkLabel(self, image=self.bg_image, text="")
        self.bg_label.place(x=0, y=0, relwidth=1, relheight=1)

        self.label_j1 = ctk.CTkLabel(self, text="", font=ctk.CTkFont(size=22, weight="bold"))
        self.label_j1.place(relx=0.5, y=30, anchor="n")

        self.label_j2 = ctk.CTkLabel(self, text="", font=ctk.CTkFont(size=22, weight="bold"))
        self.label_j2.place(relx=0.5, rely=1.0, y=-50, anchor="s")

        self.label_tour = ctk.CTkLabel(self, text="", font=ctk.CTkFont(size=24, weight="bold"))
        self.label_tour.place(relx=0.5, rely=0.5, anchor="center")

        self.frame_main_j1 = ctk.CTkFrame(self, fg_color="transparent")
        self.frame_main_j1.place(relx=0.5, y=80, anchor="n")

        self.frame_main_j2 = ctk.CTkFrame(self, fg_color="transparent")
        self.frame_main_j2.place(relx=0.5, rely=1.0, y=-100, anchor="s")

        # Dé agrandi
        dice_img_raw = Image.open("images/dice.png")
        self.dice_img = ctk.CTkImage(dice_img_raw, size=(160, 240))
        self.btn_dice = ctk.CTkButton(
            self,
            image=self.dice_img,
            text="",
            width=160,
            height=240,
            hover_color="gray",
            command=self.piocher_carte
        )

        self.btn_dice.place(relx=0.82, rely=0.5, anchor="center")
        self.btn_dice.configure(state="disabled")

        self.mettre_a_jour()

    def mettre_a_jour(self):
        self.label_j1.configure(text=f"{self.jeu.j1_nom} - PV : {self.jeu.pv_j1}")
        self.label_j2.configure(text=f"{self.jeu.j2_nom} - PV : {self.jeu.pv_j2}")

        if self.jeu.doit_sauter_tour():
            self.afficher_message("Tour sauté !")
            self.jeu.tour_j1 = not self.jeu.tour_j1

        joueur_actif = self.jeu.j1_nom if self.jeu.tour_j1 else self.jeu.j2_nom
        self.label_tour.configure(text=f"Tour de {joueur_actif}")

        self.afficher_main(self.frame_main_j1, self.jeu.main_j1, actif=self.jeu.tour_j1)
        self.afficher_main(self.frame_main_j2, self.jeu.main_j2, actif=not self.jeu.tour_j1)

        self.btn_dice.configure(state="normal" if self.jeu.peut_piocher() else "disabled")

        if not self.dernier_rejoue:
            self.cartes_a_jouer = self.jeu.nombre_cartes_a_jouer()
        self.dernier_rejoue = False

    def afficher_main(self, frame, main, actif):
        for widget in frame.winfo_children():
            widget.destroy()

        for idx, carte in enumerate(main):
            img = self.get_image_carte(carte)
            btn = ctk.CTkButton(
                frame,
                image=img,
                text=f"" if img else f"Carte {carte}",
                width=160,
                height=240,
                compound="top",
                fg_color="transparent",
                state="normal" if actif else "disabled",
                command=lambda c=carte: self.jouer_carte(c)
            )
            btn.grid(row=0, column=idx, padx=5)

    def get_image_carte(self, carte):
        if carte not in self.images_cartes:
            chemin = f"images/cartes/carte{carte}.png"
            if os.path.exists(chemin):
                img = Image.open(chemin)
                taille = (160, 240)
                # Crée une image CustomTkinter avec taille explicitement passée
                self.images_cartes[carte] = ctk.CTkImage(img, size=taille)
            else:
                self.images_cartes[carte] = None
        return self.images_cartes[carte]


    def jouer_carte(self, carte):
        main = self.jeu.main_j1 if self.jeu.tour_j1 else self.jeu.main_j2

        if carte in main:
            self.jeu.jouer_carte(main, carte)
            texte = self.jeu.effet_carte(1 if self.jeu.tour_j1 else 2, carte)
            self.afficher_message(texte)

            if carte == 5:
                self.dernier_rejoue = True
                self.cartes_a_jouer = 1
            else:
                self.cartes_a_jouer -= 1

            if self.cartes_a_jouer <= 0 and not self.dernier_rejoue:
                self.jeu.tour_j1 = not self.jeu.tour_j1
                self.cartes_a_jouer = 1

            self.mettre_a_jour()

    def piocher_carte(self):
        main = self.jeu.main_j1 if self.jeu.tour_j1 else self.jeu.main_j2
        if self.jeu.piocher_carte(main):
            self.vibrer_de()
            self.mettre_a_jour()
        else:
            self.afficher_message("Impossible de piocher.")

    def vibrer_de(self):
        def vib():
            for _ in range(4):
                self.btn_dice.place_configure(relx=0.945)
                time.sleep(0.05)
                self.btn_dice.place_configure(relx=0.955)
                time.sleep(0.05)
            self.btn_dice.place_configure(relx=0.95)

        threading.Thread(target=vib).start()

    def afficher_message(self, texte):
        messagebox.showinfo("Action", texte)


if __name__ == "__main__":
    from jeu_cartes import JeuCartes
    jeu = JeuCartes()
    jeu.init_joueurs("Alice", "Bob")
    app = InterfaceJeu(jeu)
    app.mainloop()
