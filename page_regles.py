import customtkinter as ctk
from PIL import Image
import os

class PageRegles(ctk.CTkFrame):
    def __init__(self, parent, controller=None):
        super().__init__(parent)
        self.controller = controller

        # Scrollable frame pour les règles
        self.scroll_frame = ctk.CTkScrollableFrame(self)
        self.scroll_frame.pack(fill="both", expand=True, padx=20, pady=20)

        cartes = [
            ("Carte 1 : Inflige 1 point de dégâts.", "images/cartes/carte1.png"),
            ("Carte 2 : Récupère 1 point de vie.", "images/cartes/carte2.png"),
            ("Carte 3 : Permet de rejouer un tour.", "images/cartes/carte3.png"),
            ("Carte 4 : Annule la dernière action.", "images/cartes/carte4.png"),
            ("Carte 5 : Joue une carte supplémentaire.", "images/cartes/carte5.png"),
        ]

        for texte, chemin_img in cartes:
            frame = ctk.CTkFrame(self.scroll_frame)
            frame.pack(fill="x", pady=10)

            if os.path.exists(chemin_img):
                img_raw = Image.open(chemin_img).resize((80, 120))
                img = ctk.CTkImage(img_raw)
            else:
                img = None

            label_img = ctk.CTkLabel(frame, image=img, text="")
            label_img.image = img
            label_img.pack(side="left", padx=10)

            label_texte = ctk.CTkLabel(frame, text=texte, wraplength=500, justify="left")
            label_texte.pack(side="left", padx=10)

        btn_retour = ctk.CTkButton(self, text="Retour accueil", command=lambda: controller.show_frame("PageAccueil"))
        btn_retour.pack(pady=10)
