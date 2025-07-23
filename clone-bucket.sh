#!/usr/bin/env bash


NAMESPACE=$1;
APP_NAME=$2;
CLONE_NAME="$2-copy";
DOCKER_REGISTRY="rg.fr-par.scw.cloud\/decidim-app";
ALIAS_NAME="$NAMESPACE-$APP_NAME-alias";

GREEN='\033[0;32m'
NC='\033[0m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

function error() {
  echo -e "${RED}[-] $1${NC}"
}
function success() {
  echo -e "${GREEN}[+] $1${NC}"
}
function warning() {
  echo -e "${YELLOW}[!] $1${NC}"
}

function execute() {
  echo -e "${YELLOW}[!] $1${NC}"
  eval "$1"
}

function ask_confirmation() {
  while true; do
    read -r -p "$1" response
    if [[ "$response" =~ ^(yes|y)$ ]]; then
      break
    else
      warning "Please confirm the action";
    fi
  done
}

if [ -z "$NAMESPACE" ] || [ -z "$APP_NAME" ] || [ -z "$CLONE_NAME" ]; then
  error "error: Missing arguments";
  echo "Usage: $0 <namespace> <app_name> <name>";
  exit 1
fi

success "[*][1/6] Copy YAML from objects: Decidim, Assets Bucket, Postgres Bucket, Postgres, Custom Env Secret, RAILS_SECRET Secret";
warning "Exporting secrets and decidim configuration for $APP_NAME in namespace $NAMESPACE...";

mkdir -p ./dist/$NAMESPACE/$APP_NAME
success "[*] Creating directory ./dist/$NAMESPACE/$APP_NAME";
cd ./dist/$NAMESPACE/$APP_NAME
execute "kubectl get bucket $APP_NAME--de-pg -n $NAMESPACE -o yaml > $CLONE_NAME-bucket-pg.yaml";
success "[*] Processing $file";
execute "sed -i '' 's/$APP_NAME/$CLONE_NAME/g' $CLONE_NAME-bucket-pg.yaml";

ask_confirmation "Is the Bucket file ready ? (y/n)";

success "[*] Applying Buckets";
execute "kubectl create -n $NAMESPACE -f $CLONE_NAME-bucket-pg.yaml";

for i in $(seq 1 5); do
  echo -n "."
  sleep 1
done

PG_ENDPOINT_BUCKET=$(kubectl get secret $APP_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.endpoint} | base64 -D)
PG_USERNAME_BUCKET=$(kubectl get secret $APP_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.username} | base64 -D)
PG_PASSWORD_BUCKET=$(kubectl get secret $APP_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.password} | base64 -D)
PG_NAME_BUCKET=$(kubectl get secret $APP_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.bucket} | base64 -D)

PG_CLONE_ENDPOINT_BUCKET=$(kubectl get secret $CLONE_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.endpoint} | base64 -D)
PG_CLONE_USERNAME_BUCKET=$(kubectl get secret $CLONE_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.username} | base64 -D)
PG_CLONE_PASSWORD_BUCKET=$(kubectl get secret $CLONE_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.password} | base64 -D)
PG_CLONE_BUCKET=$(kubectl get secret $CLONE_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.bucket} | base64 -D)
warning "|
> mc alias set $ALIAS_NAME-pg https://$PG_ENDPOINT_BUCKET $PG_USERNAME_BUCKET $PG_PASSWORD_BUCKET
> mc alias set staging-$ALIAS_NAME-pg-copy https://$PG_CLONE_ENDPOINT_BUCKET $PG_CLONE_USERNAME_BUCKET $PG_CLONE_PASSWORD_BUCKET

> mc mirror $ALIAS_NAME-pg/$PG_NAME_BUCKET staging-$ALIAS_NAME-pg-copy/$PG_CLONE_BUCKET
"
