#!/usr/bin/env bash
# pki.sh : automatise les etapes 2 a 4 du TP2 (racine, intermediaire, serveur, client)
# Usage : bash pki.sh [dossier_de_travail]
# Par defaut, tout est construit dans ../work/pki-auto (exclu de Git)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONF_DIR="$REPO_DIR/etape1-configuration"
BUILD_DIR="${1:-$REPO_DIR/work/pki-auto}"

if [ -e "$BUILD_DIR" ]; then
    echo "Erreur : $BUILD_DIR existe deja. Supprimez-le ou indiquez un autre dossier." >&2
    exit 1
fi

for f in racine.cnf inter.cnf; do
    [ -f "$CONF_DIR/$f" ] || { echo "Erreur : $CONF_DIR/$f introuvable." >&2; exit 1; }
done

echo "==> Preparation de $BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
mkdir -p racine/newcerts racine/crl inter/newcerts inter/crl
touch racine/index.txt inter/index.txt
echo 1000 | tee racine/serial inter/serial racine/crlnumber inter/crlnumber > /dev/null
cp "$CONF_DIR/racine.cnf" "$CONF_DIR/inter.cnf" .

echo "==> Etape 2 : AC racine (P-384, 10 ans)"
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 -out racine/racine.key
chmod 600 racine/racine.key
openssl req -x509 -new -key racine/racine.key -sha384 -days 3650 \
  -subj "/C=BF/O=Universite TP/CN=Racine TP" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:1" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "subjectKeyIdentifier=hash" -out racine/racine.crt

echo "==> Etape 3 : AC intermediaire (P-256, 5 ans)"
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out inter/inter.key
chmod 600 inter/inter.key
openssl req -new -key inter/inter.key -sha256 \
  -subj "/C=BF/O=Universite TP/CN=Intermediaire TP" -out inter/inter.csr
openssl ca -batch -config racine.cnf -extensions ext_inter -days 1825 \
  -in inter/inter.csr -out inter/inter.crt

echo "==> Etape 4 : certificat du serveur www.tp.local"
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out serveur.key
chmod 600 serveur.key
openssl req -new -key serveur.key -subj "/CN=www.tp.local" \
  -addext "subjectAltName=DNS:www.tp.local,DNS:tp.local" -out serveur.csr
openssl ca -batch -config inter.cnf -extensions ext_serveur -days 90 \
  -in serveur.csr -out serveur.crt

echo "==> Etape 4 : certificat du client alice@tp.local"
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out alice.key
chmod 600 alice.key
openssl req -new -key alice.key -subj "/CN=alice@tp.local" \
  -addext "subjectAltName=email:alice@tp.local" -out alice.csr
openssl ca -batch -config inter.cnf -extensions ext_client -days 90 \
  -in alice.csr -out alice.crt

echo "==> Verification des chaines"
openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt \
  -verify_hostname www.tp.local serveur.crt
openssl verify -CAfile racine/racine.crt -untrusted inter/inter.crt \
  -purpose sslclient alice.crt

echo "==> PKI generee dans $BUILD_DIR"
