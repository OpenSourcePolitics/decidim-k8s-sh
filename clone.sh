#!/usr/bin/env bash

NAMESPACE=$1;
APP_NAME=$2;
IMAGE_NAME=$3;
DOCKER_REGISTRY="rg.fr-par.scw.cloud\/decidim-app";

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

if [ -z "$NAMESPACE" ] || [ -z "$APP_NAME" ] || [ -z "$IMAGE_NAME" ]; then
  error "error: Missing arguments";
  echo "Usage: $0 <namespace> <app_name> <image_name:tag>";
  exit 1
fi

warning "You about to CLONE $NAMESPACE/$APP_NAME: ";
read -r -p "Continue? (y/n) " response

if [[ "$response" =~ ^(yes|y)$ ]]; then
  success "Cloning $NAMESPACE/$APP_NAME: ";
else
  error "Aborting...";
  exit 1
fi

warning "Exporting secrets and decidim configuration for $APP_NAME in namespace $NAMESPACE...";

mkdir -p ./dist/$NAMESPACE/$APP_NAME
success "[*] Creating directory ./dist/$NAMESPACE/$APP_NAME";
cd ./dist/$NAMESPACE/$APP_NAME

execute "kubectl get secret $APP_NAME--de -n $NAMESPACE -o yaml > $APP_NAME--de-secret.yaml";
execute "kubectl get secret $APP_NAME-custom-env -n $NAMESPACE -o yaml > $APP_NAME-custom-env-secret.yaml";
execute "kubectl get decidim $APP_NAME -n $NAMESPACE -o yaml > $APP_NAME-decidim.yaml";
execute "kubectl get bucket $APP_NAME--de -n $NAMESPACE -o yaml > $APP_NAME-bucket.yaml";
execute "kubectl get bucket $APP_NAME--de-pg -n $NAMESPACE -o yaml > $APP_NAME-bucket-pg.yaml";
execute "kubectl get postgres $APP_NAME--de -n $NAMESPACE -o yaml > $APP_NAME-postgres.yaml";
execute "kubectl get secret $APP_NAME--de -n $NAMESPACE -o jsonpath='{.data}' | base64 -d > $APP_NAME--de-secret.txt";

success "[x] Renaming '$APP_NAME' to 'clone-$APP_NAME' in all files...";

for file in $(ls); do
  success "[*] Processing $file";
  execute "sed -i '' 's/$APP_NAME/clone-$APP_NAME/g' $file";
done

success "Done.";
# kubectl create -n $NAMESPACE -f FILE
# kubectl create -n $NAMESPACE -f FILE

