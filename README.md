# ReHabNL

Le modèle ReHab a été développé dans [Cormas](http://cormas.cirad.fr/). Ce modèle de simulation participative a par la suite été également porté en jeu physique.

La version M0 du modèle Netlogo a été développée par Anne Dray de (ETH Zurik). Une version M1 est en cours de développement pour essayer de coller aux règles d'initialisation que nous avons normalisées autour du jeu physique.

## exostivité des règles et orientation du M1

Une discussion avec Erwan Sachet, Nicolas Paget et Raphaël Duboz lors de la semaine du 13 au 17 février 2023 nous a amenés à préciser la manière dont on va orienter les prochains développements. En effet Rehab a été utilisé dans le cadre de la formation Living labs du projet [Santé et Territoire](https://santes-territoires.org/), mais l'implémentation originale ne permettait pas une exploration. 

1. passer à des stratégies en machine à état fini pour pouvoir travailler sur les enchainements de stratégie sous forme de stack du genre `[S1 S3 S4 S1 S5]`. 
2. identifier la diversité des stratégies possibles pour pouvoir les explorer sous forme d'un arbre des possibles. 

Les stratégies que nous avons identifiées pour le moment sont : 

- S0 : déplacement random
- S1 : Max biomasse
- S2 : min biomasse
- S3 : distance des oiseaux
- S4 : je vais dans le parc
- S5 : je fais comme la majorité
- S6 : je fais le contraire de la majorité

