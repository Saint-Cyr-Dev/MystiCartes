import customtkinter as ctk
from PIL import Image
from tkinter import messagebox, simpledialog
from interface import InterfaceJeu
from jeu_cartes import JeuCartes

class PageAccueil(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.geometry("800x600")
        self.title("MystiCartes - Accueil")

        self.bg_image = ctk.CTkImage(Image.open("images/background.png"), size=(1920, 1080))
        self.bg_label = ctk.CTkLabel(self, image=self.bg_image, text="")
        self.bg_label.place(x=0, y=0, relwidth=1, relheight=1)

        self.frame_buttons = ctk.CTkFrame(self, fg_color="transparent")
        self.frame_buttons.place(relx=0.5, rely=0.5, anchor="center")

        self.label_title = ctk.CTkLabel(
            self.frame_buttons, text="MystiCartes",
            width=300, height=100,
            font=ctk.CTkFont(size=50, weight="bold")
        )
        self.label_title.pack(pady=40)

        self.btn_jouer_2 = ctk.CTkButton(
            self.frame_buttons, text="Jouer à deux", width=200, height=70,
            command=self.jouer_a_deux, font=ctk.CTkFont(size=20)
        )
        self.btn_jouer_2.pack(pady=5)

        self.btn_jouer_ia = ctk.CTkButton(
            self.frame_buttons, text="Joueur contre l'IA", width=200, height=70,
            command=self.jouer_contre_ia, font=ctk.CTkFont(size=20)
        )
        self.btn_jouer_ia.pack(pady=5)

        self.btn_regles = ctk.CTkButton(
            self.frame_buttons, text="Règle du jeu", width=200, height=70,
            command=self.afficher_regles, font=ctk.CTkFont(size=20)
        )
        self.btn_regles.pack(pady=5)

        self.btn_quitter = ctk.CTkButton(
            self.frame_buttons, text="Quitter", width=200, height=70,
            command=self.quit, font=ctk.CTkFont(size=20)
        )
        self.btn_quitter.pack(pady=5)

    def jouer_a_deux(self):
        # Demander le nom du joueur 1
        nom_j1 = simpledialog.askstring("Nom joueur 1", "Entrez le nom du joueur 1 :")
        if not nom_j1:
            messagebox.showwarning("Nom requis", "Le nom du joueur 1 est requis.")
            return
        # Demander le nom du joueur 2
        nom_j2 = simpledialog.askstring("Nom joueur 2", "Entrez le nom du joueur 2 :")
        if not nom_j2:
            messagebox.showwarning("Nom requis", "Le nom du joueur 2 est requis.")
            return

        jeu = JeuCartes()
        jeu.init_joueurs(nom_j1, nom_j2)
        self.destroy()
        InterfaceJeu(jeu).mainloop()

    def jouer_contre_ia(self):
        messagebox.showinfo("Joueur contre IA", "Mode IA non implémenté pour le moment.")

    def afficher_regles(self):
        regles = (
            "Règles du jeu MystiCartes :\n"
            "- Chaque joueur commence avec X points de vie.\n"
            "- À tour de rôle, piochez et jouez des cartes.\n"
            "- Certaines cartes ont des effets spéciaux...\n"
            "..."
        )
        messagebox.showinfo("Règle du jeu", regles)

if __name__ == "__main__":
    app = PageAccueil()
    app.mainloop()
