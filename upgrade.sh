#!/usr/bin/env bash

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
function ask_confirmation_or_exit() {
  while true; do
    read -r -p "$1" response
    if [[ "$response" =~ ^(yes|y)$ ]]; then
      break
    else
      error "Process aborted by user...";
      exit 1
    fi
  done
}

function notify_webhook() {
  curl -X POST --user $WEBHOOK_USER:$WEBHOOK_PASSWORD -H "Content-Type: application/json" -H "X-DECIDIM-EVENT: upgrade" -d "{\"namespace\": \"$NAMESPACE\", \"image\": \"$IMAGE_NAME\", \"app\": \"$APP_NAME\", \"owner\": \"$USER\", \"host\": \"https://$1\" }" $WEBHOOK_ENDPOINT
}

APP_NAME=$2;
NAMESPACE=$1;
IMAGE_NAME=$3;

GREEN='\033[0;32m'
NC='\033[0m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

if [ -f ".env" ]; then
  source .env
else
  error "error: Missing .env file";
  warning "Copy from .env.example"
  warning "> cp .env.example .env";
  exit 1
fi

warning "Steps :"
warning "1. Exporting Decidim object from $NAMESPACE/$APP_NAME to  ./dist/$NAMESPACE/$APP_NAME"
warning "2. Upgrading image version in the Decidim object to $IMAGE_NAME"
warning "3. Apply the new Decidim object to the cluster"
warning "4. Wait for Decidim to be running with the new image"
warning "5. Call app endpoint to ensure it is running"
warning "6. Notify the webhook with the new image version"

ask_confirmation_or_exit "Are you sure you want to continue ? (y/n) ";

success "[*][1/6] Exporting Decidim object from $NAMESPACE/$APP_NAME to  ./dist/$NAMESPACE/$APP_NAME-decidim.yaml";

mkdir -p ./dist/$NAMESPACE/$APP_NAME
cd ./dist/$NAMESPACE/$APP_NAME
kubectl get decidim $APP_NAME -n $NAMESPACE -o yaml > $APP_NAME-decidim.yaml

success "[*][2/6] Upgrading image version in the Decidim object to $IMAGE_NAME";
echo "Original image version :"
echo $(cat $APP_NAME-decidim.yaml | grep -E "image: $DOCKER_REGISTRY")
sed -i "" "s/^  image: $DOCKER_REGISTRY.*/  image: $DOCKER_REGISTRY\/$IMAGE_NAME/g" $APP_NAME-decidim.yaml;

echo "New image version :"
echo $(cat $APP_NAME-decidim.yaml | grep -E "image: $DOCKER_REGISTRY")

warning "Please check the diff before applying the new configuration: ";
echo -en $(KUBECTL_EXTERNAL_DIFF='colordiff -N -u' kubectl diff -f $APP_NAME-decidim.yaml -n $NAMESPACE)

echo ""
success "[*][3/6] Apply the new Decidim object to the cluster";

HOST="$(kubectl get decidim -n $NAMESPACE $APP_NAME -o jsonpath='{.spec.host}')"
if [ -z "$HOST" ]; then
  error "error: Missing host in $APP_NAME-decidim.yaml";
  exit 1
fi

success "[*] Host: $HOST";

ask_confirmation_or_exit "Are you sure you want to apply configuration on $NAMESPACE/$APP_NAME ? (y/n) ";
warning "> kubectl apply -f $APP_NAME-decidim.yaml -n $NAMESPACE"

#
#kubectl apply -f $APP_NAME-decidim.yaml -n $NAMESPACE

success "[*][4/6] Waiting for Decidim $APP_NAME to be running with the new image $DOCKER_REGISTRY/$IMAGE_NAME"

LIMIT_ATTEMPTS=0
while true; do
  kubectl get decidim $APP_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[*].message}' | grep "running" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    success "[*] Decidim $APP_NAME is now running with the new image $DOCKER_REGISTRY/$IMAGE_NAME"
    warning "Waiting 10 seconds for the pod to be ready..."
    for i in {1..10}; do
      echo -n "."
      sleep 1
    done

    break
  fi
  if [ $LIMIT_ATTEMPTS -ge 24 ]; then
    error "error: Decidim $APP_NAME is not running with the new image $DOCKER_REGISTRY/$IMAGE_NAME"
    exit 1
  fi
  echo -n "."
  sleep 5
  LIMIT_ATTEMPTS=$((LIMIT_ATTEMPTS + 1))
done

success "[*][5/6] Call app endpoint to ensure it is running"
warning "Testing connection on $HOST..."

HOME_PAGE="$(curl -s -o /dev/null -w "%{http_code}" https://$HOST/)"
if [ "$HOME_PAGE" -ne 200 ]; then
  error "Endpoint https://$HOST/ is not running as expected"
fi
SIGNIN_PAGE="$( curl -s -o /dev/null -w "%{http_code}" https://$HOST/users/sign_in)"
if [ "$HOME_PAGE" -ne 200 ]; then
  error "Endpoint https://$HOST/users/sign_in is not running as expected"
fi

if [ "$HOME_PAGE" -eq 200 ] && [ "$SIGNIN_PAGE" -eq 200 ]; then
  success "[>] Endpoint https://$HOST/ is running as expected"
  success "[>] Endpoint https://$HOST/users/sign_in is running as expected"
  success "[*] Decidim $APP_NAME is running with the new image $DOCKER_REGISTRY/$IMAGE_NAME"
else
  error "error: Decidim $APP_NAME is not running with the new image $DOCKER_REGISTRY/$IMAGE_NAME"
  exit 1
fi

notify_webhook $HOST

exit 0
