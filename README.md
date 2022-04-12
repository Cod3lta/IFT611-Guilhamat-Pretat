IFT611 - STR
Optimisation Multijoueur
Arnaud Guilhamat & Valentin Prétat

Notre projet pour le cours IFT 611 - Conception de systèmes temps réel pour ce trimestre d’hiver 2022 est un jeu vidéo fait en équipe avec certaines contraintes.
Il s’agit d’un jeu vidéo multijoueur en réseau de type plateforme en 2D. Le but étant d’arriver en premier au bout du niveau, il faut faire en sorte d’éviter les pièges de l’environnement, et surtout, tous les coups sont permis entre les joueurs. 🙂

L’aspect technique intéressant de ce projet est l’implémentation de la communication multijoueur en réseau entre les joueurs : une multitude de potentiels problèmes viennent s’ajouter avec l’aspect synchronisation entre plusieurs instances du jeu, entre les hôtes et le serveur.
Il faut garantir une expérience fluide pour tous les joueurs. Il faut que la latence perçue soit la plus faible possible et que le temps de réaction du jeu soit sous un certain seuil en tout temps. 
Nous avons également jugé nécessaire d’ajouter une contrainte temps réelle indépendante de l’aspect réseau qui est d’avoir un taux constant de 60 images par seconde (IPS), qui semble être essentielle pour un jeu vidéo pour assurer une bonne expérience à l’utilisateur.
