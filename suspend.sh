#!/usr/bin/env bash

NAMESPACE=$1;
APP_NAME=$2;
FILENAME_DECIDIM=$APP_NAME-decidim.yaml;
INGRESS_NAME="$APP_NAME--de";

GREEN='\033[0;32m'
NC='\033[0m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

function error() {
  echo -e "${RED}[–] [ 🚨 ] $1${NC}"
}
function success() {
  echo -e "${GREEN}[+] $1${NC}"
}
function warning() {
  echo -e "${YELLOW}[!] $1${NC}"
}

function execute() {
  warning "[ $> ] $1"
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

if ! command -v yq &> /dev/null; then
    error "yq could not be found. Please install yq to proceed."
    warning "| Install yq
> brew install yq
> sudo apt-get install yq"
    exit 1
fi

if [ -z "$NAMESPACE" ] || [ -z "$APP_NAME" ]; then
  error "error: Missing arguments";
  echo "Usage: $0 <namespace> <app_name>";
  exit 1
fi

error "DANGER: This script will suspend the application $APP_NAME in namespace $NAMESPACE";
read -r -p "Suspend Decidim and remove the ingress from $NAMESPACE/$APP_NAME ? (y/n) " response
if [[ ! "$response" =~ ^(yes|y)$ ]]; then
  error "Aborting the script";
  exit 1
fi

mkdir -p ./dist/$NAMESPACE/$APP_NAME
cd ./dist/$NAMESPACE/$APP_NAME
execute "kubectl get decidim $APP_NAME -n $NAMESPACE -o yaml > $FILENAME_DECIDIM"

yq eval '.spec.suspend = true' -i $FILENAME_DECIDIM

FUTURE_DATE=$(date -v+30d -u +"%d-%m-%Y")
DELETE_LABEL_KEY="libre.sh/delete_date"
yq eval ".metadata.labels.\"$DELETE_LABEL_KEY\" = \"$FUTURE_DATE\"" -i $FILENAME_DECIDIM

# Destroy object poddisruptionbudget
warning "[ * ] Suspending Decidim $NAMESPACE/$APP_NAME";
execute "kubectl apply -f $FILENAME_DECIDIM"
warning "[ * ] Removing ingress $NAMESPACE/$APP_NAME--de";
execute "kubectl delete ingress $INGRESS_NAME -n $NAMESPACE";
warning "[ * ] Removing App, Sidekiq, Memcached deployments $NAMESPACE/$APP_NAME";
execute "kubectl delete deploy $APP_NAME--de-app -n $NAMESPACE";
execute "kubectl delete deploy $APP_NAME--de-sidekiq -n $NAMESPACE";
execute "kubectl delete deploy $APP_NAME--de-memcached -n $NAMESPACE";

success "[ ✅  ] $NAMESPACE/$APP_NAME suspended successfully";
