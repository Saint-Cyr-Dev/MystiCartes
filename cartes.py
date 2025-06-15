# cartes.py

def appliquer_effet(jeu, joueur, carte):
    nom = jeu.j1_nom if joueur == 1 else jeu.j2_nom
    adv = jeu.j2_nom if joueur == 1 else jeu.j1_nom
    adv_pv = jeu.pv_j2 if joueur == 1 else jeu.pv_j1

    effet = ""

    adv_attr = lambda attr: getattr(jeu, f"{attr}_j2") if joueur == 1 else getattr(jeu, f"{attr}_j1")
    set_adv_attr = lambda attr, val: setattr(jeu, f"{attr}_j2" if joueur == 1 else f"{attr}_j1", val)
    set_self_attr = lambda attr, val: setattr(jeu, f"{attr}_j1" if joueur == 1 else f"{attr}_j2", val)

    if carte == 1:
        if adv_attr("bouclier"):
            effet = f"{adv} est protégé par un bouclier !"
            set_adv_attr("bouclier", False)
        else:
            dmg = 10
            if joueur == 1:
                jeu.pv_j2 -= dmg
            else:
                jeu.pv_j1 -= dmg
            effet = f"{nom} inflige {dmg} dégâts à {adv}."

    elif carte == 2:
        interdit = jeu.interdiction_soin_j1 if joueur == 1 else jeu.interdiction_soin_j2
        if interdit:
            set_self_attr("interdiction_soin", False)
            effet = f"{nom} ne peut pas se soigner."
        else:
            soin = 10
            if joueur == 1:
                jeu.pv_j1 += soin
            else:
                jeu.pv_j2 += soin
            effet = f"{nom} récupère {soin} PV."

    elif carte == 3:
        set_adv_attr("interdiction_soin", True)
        effet = f"{adv} ne pourra pas se soigner au prochain tour."

    elif carte == 4:
        set_adv_attr("saut", True)
        effet = f"{adv} perdra son prochain tour."

    elif carte == 5:
        set_self_attr("rejouer", True)
        effet = f"{nom} rejoue immédiatement !"

    elif carte == 6:
        jeu.pv_j1 -= 10
        jeu.pv_j2 -= 10
        effet = "Explosion ! Les deux joueurs perdent 10 PV."

    elif carte == 7:
        jeu.pv_j1, jeu.pv_j2 = jeu.pv_j2, jeu.pv_j1
        effet = f"{nom} échange les PV avec {adv}."

    elif carte == 8:
        set_self_attr("combo", True)
        effet = f"{nom} pourra jouer 2 cartes au prochain tour."

    elif carte == 9:
        if joueur == 1:
            jeu.pv_j1 += 15
            jeu.pv_j2 -= 15
        else:
            jeu.pv_j2 += 15
            jeu.pv_j1 -= 15
        effet = f"{nom} vole 15 PV à {adv}."

    elif carte == 10:
        set_self_attr("vision", True)
        effet = f"{nom} voit la main de {adv}."

    elif carte == 11:
        set_self_attr("bouclier", True)
        effet = f"{nom} active un bouclier."

    elif carte == 12:
        if adv_attr("bouclier"):
            effet = f"{adv} bloque le coup critique !"
            set_adv_attr("bouclier", False)
        else:
            if joueur == 1:
                jeu.pv_j2 -= 30
            else:
                jeu.pv_j1 -= 30
            effet = f"{nom} inflige un coup critique de 30 PV."

    elif carte == 13:
        set_adv_attr("poison", 3)
        effet = f"{adv} est empoisonné pour 3 tours."

    elif carte == 14:
        main_adv = jeu.main_j2 if joueur == 1 else jeu.main_j1
        if main_adv:
            import random
            c = random.choice(main_adv)
            jeu.get_main(joueur).append(c)
            effet = f"{nom} copie une carte ({c}) de {adv}."
        else:
            effet = f"{adv} n’a pas de cartes à copier."

    elif carte == 15:
        set_self_attr("poison", 0)
        set_self_attr("interdiction_soin", False)
        effet = f"{nom} se purifie."

    # Poison effet
    if joueur == 1 and jeu.poison_j1 > 0:
        jeu.pv_j1 -= 5
        jeu.poison_j1 -= 1
    elif joueur == 2 and jeu.poison_j2 > 0:
        jeu.pv_j2 -= 5
        jeu.poison_j2 -= 1

    return effet
