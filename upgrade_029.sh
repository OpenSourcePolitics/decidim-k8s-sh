#!/usr/bin/env bash


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

APP_NAME=$2;
NAMESPACE=$1;
IMAGE_NAME=$3;
FILENAME_SECRETS=$APP_NAME-custom-env.yaml;
FILENAME_DECIDIM=$APP_NAME-decidim.yaml;

if [ -z "$NAMESPACE" ] || [ -z "$APP_NAME" ] || [ -z "$IMAGE_NAME"  ]; then
  error "error: Missing arguments";
  echo "Usage: $0 <namespace> <app_name> <image_name>";
  echo "Example: $0 decidim-opensourcepolitics-eu club decidim-app:v3.3.1";
  exit 1
fi

DOCKER_REGISTRY="rg.fr-par.scw.cloud\/decidim-app";

echo "[x] Exporting secrets and decidim configuration for $APP_NAME in namespace $NAMESPACE..."

mkdir -p ./dist/$NAMESPACE/$APP_NAME
cd ./dist/$NAMESPACE/$APP_NAME
kubectl get secret $APP_NAME-custom-env -n $NAMESPACE -o yaml > $FILENAME_SECRETS
kubectl get decidim $APP_NAME -n $NAMESPACE -o yaml > $FILENAME_DECIDIM
sed -i -r "s/^data:$/data:\n  STORAGE_PROVIDER: bWluaW8=/g" $FILENAME_SECRETS
echo "[x] Add STORAGE_PROVIDER to custom-env secret";
sed -i -r "s/GEOCODER_LOOKUP_API_KEY/MAPS_API_KEY/g" $FILENAME_SECRETS
echo "[x] Rename GEOCODER_LOOKUP_API_KEY to MAPS_API_KEY";

ask_confirmation "Is the platform multi-lang ? If so add the var DECIDIM_AVAILABLE_LOCALES before migrations. (y/n) ";

echo -n "New image version :"
echo $(cat $APP_NAME-decidim.yaml | grep -E "image: $DOCKER_REGISTRY")
sed -i '' "s/^  image: $DOCKER_REGISTRY.*/  image: $DOCKER_REGISTRY\/$IMAGE_NAME/g" $APP_NAME-decidim.yaml;

warning "Please check the diff before applying the new configuration: ";
echo -en $(KUBECTL_EXTERNAL_DIFF='colordiff -N -u' kubectl diff -f $APP_NAME-decidim.yaml -n $NAMESPACE)

echo ""
success "[*][3/6] Apply the new Decidim object to the cluster";

HOST="$(kubectl get decidim -n $NAMESPACE $APP_NAME -o jsonpath='{.spec.host}')"
if [ -z "$HOST" ]; then
  error "error: Missing host in $APP_NAME-decidim.yaml";
  exit 1
fi

ask_confirmation "Are you sure you want to apply configuration on $NAMESPACE/$APP_NAME ? (y/n) ";
echo "[-] Apply the new secrets and decidim configuration to the cluster"

echo "> kubectl apply -f $FILENAME_SECRETS -n $NAMESPACE"
echo "..."
kubectl apply -f $FILENAME_SECRETS -n $NAMESPACE

echo "> kubectl apply -f $FILENAME_DECIDIM -n $NAMESPACE"
echo "..."
kubectl apply -f $FILENAME_DECIDIM -n $NAMESPACE

echo "[x] Waiting for Decidim $APP_NAME to be running with the new image $DOCKER_REGISTRY/$IMAGE_NAME"

echo -e "${YELLOW}[!] .${NC}\c"
while true; do
    if kubectl get decidim "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[*].message}' | grep "running" > /dev/null 2>&1; then
        success "[x] Decidim $APP_NAME is now running with the new image $DOCKER_REGISTRY/$IMAGE_NAME"
        success "[x] Cleaning up..."

        warning "|
        kubectl annotate decidim -n $NAMESPACE $APP_NAME decidim.libre.sh/maintenance='30'";
        warning "|
        bundle exec rake decidim_app:k8s:configure;
        bundle exec rake decidim:upgrade:content_blocks:initialize_default_content_blocks;
        bundle exec rake decidim:upgrade:clean:clean_deleted_users;
        bundle exec rake decidim_proposals:upgrade:set_categories;
        bundle exec rake decidim:upgrade:attachments_cleanup;
        bundle exec rake decidim:upgrade:fix_nickname_casing;
        bundle exec rake decidim:upgrade:clean:hidden_resources";
        break;
    else
        echo -e "${YELLOW}.${NC}\c"
    fi

    sleep 10
done
