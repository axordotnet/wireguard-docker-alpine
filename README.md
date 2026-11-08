# WireGuard Docker Alpine

Image Docker légère basée sur Alpine, avec **wireguard-tools** et **wireguard-go**.
Elle utilise WireGuard natif quand le noyau le permet, et le mode logiciel en repli.
Ce n'est pas une interface d'administration ni un service VPN hébergé.

Image cible : `ghcr.io/axordotnet/wireguard-docker-alpine`.
Architecture publiée : **linux/amd64**, notamment les NAS Synology x86-64.
Le fonctionnement sur une version précise de DSM doit être validé sur cette cible ;
un test CI Linux ne certifie pas DSM.

## Prérequis

- Docker Engine Linux et Docker Compose.
- Accès à `/dev/net/tun`, capacité `NET_ADMIN`.
- UDP entre les pairs sur le port choisi ; routes et pare-feu adaptés.
- Une paire de clés distincte par pair, configuration privée hors Git.
- Aucun conflit d'adresse, de port ou d'interface `wg-proxy`.

Sur Synology, charger TUN au démarrage si nécessaire. Le conteneur n'installe
aucun module noyau et n'exige ni `privileged` ni `SYS_MODULE`.
Un compte administrateur reste nécessaire pour préparer les fichiers et Docker.

## Démarrage

Choisir une version disponible ou, de préférence en exploitation, un digest vérifié.
Le tag `edge` suit les constructions de main et n'est pas une version stable.

~~~sh
git clone https://github.com/axordotnet/wireguard-docker-alpine.git
cd wireguard-docker-alpine
docker compose build
umask 077
test ! -e private.key && test ! -e wg-proxy.conf || exit 1
docker run --rm --entrypoint wg ghcr.io/axordotnet/wireguard-docker-alpine:edge genkey > private.key
docker run --rm -i --entrypoint wg ghcr.io/axordotnet/wireguard-docker-alpine:edge pubkey < private.key > public.key
cp wg-proxy.conf.example wg-proxy.conf
chmod 600 private.key wg-proxy.conf
~~~

Renseigner la clé privée locale, la clé publique du pair, les adresses et Endpoint
dans `wg-proxy.conf`. L'exemple utilise des adresses illustratives.
Ne jamais publier ce fichier. Pour utiliser GHCR plutôt qu'une construction locale,
retirer `build` du Compose, choisir la référence `image`, puis faire `docker compose pull`.

~~~sh
docker compose config --quiet
docker compose up -d
docker compose exec wireguard wg show wg-proxy
~~~

Le healthcheck confirme seulement que l'interface existe. Vérifier un handshake
récent, les compteurs de transfert et l'accès au service distant.
`wg-quick` traite le fichier : DNS nécessite des outils supplémentaires absents
de cette image. Préférer des routes précises plutôt qu'une route par défaut.
Ne pas activer SaveConfig avec le montage en lecture seule.
Les hooks PreUp/PostUp/etc. exécutent du code privilégié : ne charger que votre configuration.

## Reverse proxy et Synology

Le Compose fourni utilise le réseau de l'hôte. Pour un reverse proxy déjà
conteneurisé, remplacer `network_mode: host` par `network_mode: container:NOM_DU_PROXY`
afin de créer le tunnel dans son espace réseau. L'Endpoint des autres pairs doit
alors viser une adresse joignable de ce conteneur, notamment son IP macvlan.

Le proxy doit démarrer en premier. Arrêter WireGuard avant de recréer le proxy,
puis recréer WireGuard ; des projets distincts ne garantissent pas cet ordre.
Dans un projet commun, utiliser `network_mode: service:proxy` et une dépendance adaptée.
Ne pas déclarer ports ou networks sur le service partageant cet espace réseau.

WireGuard n'est pas un réseau Docker overlay. Les applications distantes doivent
publier leurs ports sur une adresse accessible par le tunnel. La découverte de
services (par exemple kop/Redis) reste un mécanisme séparé.

## Construction, publication et maintenance

Le workflow valide le Compose et les scripts, construit l'image puis teste un tunnel
bidirectionnel sur un runner Linux avant publication. Le mode noyau ou logiciel
utilisé par ce test dépend du runner ; le repli logiciel sur DSM reste à tester.

- Pull request : validation uniquement, aucun accès de publication.
- Main, lancement manuel sur main et reconstruction hebdomadaire : tag edge.
- Tag Git `vX.Y.Z` ou `X.Y.Z` : image `X.Y.Z`, avec métadonnées, SBOM et provenance.
  Le titre d’une release (par exemple « V1 ») n’est pas son tag Git : la release
  « V1 » utilise le tag `1.0.0` et l’image `:1.0.0`.
- Les runners sont fixés à Ubuntu 24.04 ; Docker Login v4 utilise Node.js 24.
- GHCR reçoit l'image via le GITHUB_TOKEN temporaire ; aucun PAT à stocker.
- Après la première publication, vérifier la visibilité **publique du package GHCR** :
  elle peut être privée indépendamment du dépôt public.
- Ne pas déplacer un tag de version ; publier une nouvelle version pour une correction.
  Conserver le digest précédent pour revenir en arrière.
- Dependabot propose les mises à jour de la base Docker et des Actions.

Alpine reste fixé à la branche 3.22 ; les paquets installés sont ceux disponibles
à la construction. Les reconstruire régulièrement et examiner les changements
avant déploiement. La cadence CI ne met à jour aucun hôte automatiquement.

Test local (machine Linux de test, réseau 172.30.90.0/24 disponible) :

~~~sh
docker build -t wireguard-test .
bash tests/tunnel.sh wireguard-test
~~~

Les logiciels embarqués conservent leurs licences amont.
Sources : [WireGuard](https://www.wireguard.com/),
[wireguard-go](https://github.com/WireGuard/wireguard-go),
[Alpine](https://pkgs.alpinelinux.org/package/v3.22/community/x86_64/wireguard-go),
[publication GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).
