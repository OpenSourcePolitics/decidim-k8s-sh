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

if [ -z "$NAMESPACE" ] || [ -z "$APP_NAME" ] || [ -z "$IMAGE_NAME" ]; then
  error "error: Missing arguments";
  echo "Usage: $0 <namespace> <app_name> <image_name:tag>";
  exit 1
fi

warning "You about to CLONE $NAMESPACE/$APP_NAME: ";

warning "Here are the steps that will be performed:";
warning "1. Copy YAML from objects: Decidim, Assets Bucket, Postgres Bucket, Postgres, Custom Env Secret, RAILS_SECRET Secret"
warning "2. Rename all occurrences of $APP_NAME to clone-$APP_NAME in the YAML files"
warning "3. MANUALLY: Remove not needed informations in YAML remove 'creationTimestamp', 'resourceVersion', 'uid', 'status', 'generation', 'finalizers'";
warning "4. MANUALLY: Mirror the MinIO buckets (Assets and Postgres) to the new bucket";
warning "5. Create Postgres objects and Decidim";
warning "6. Edit the Organization host directly in database";

ask_confirmation "Are you sure you want to continue ? (y/n)";

success "[*][1/6] Copy YAML from objects: Decidim, Assets Bucket, Postgres Bucket, Postgres, Custom Env Secret, RAILS_SECRET Secret";
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

success "[*][2/6] Renaming all occurrences of $APP_NAME to clone-$APP_NAME in the YAML files";

for file in $(ls); do
  success "[*] Processing $file";
  execute "sed -i '' 's/$APP_NAME/clone-$APP_NAME/g' $file";
done

success "[*][3/6] MANUALLY: Remove not needed informations in YAML remove 'creationTimestamp', 'resourceVersion', 'uid', 'status', 'generation', 'finalizers'";
warning "You need to remove the following fields from the YAML files:";
warning "  - creationTimestamp";
warning "  - resourceVersion";
warning "  - uid";
warning "  - status";
warning "  - generation";
warning "  - finalizers";
warning "This list is not exhaustive, you need to check the YAML files and remove all the fields that are not needed";

error "Configuration will be applied directly to the cluster";
ask_confirmation "Are the files ready ? (y/n)";

success "[*] Applying Buckets";
exit 0
execute "kubectl create -n $NAMESPACE -f $APP_NAME-bucket.yaml";
execute "kubectl create -n $NAMESPACE -f $APP_NAME-bucket-pg.yaml";

success "[*][4/6] MANUALLY: Mirror the MinIO buckets (Assets and Postgres) to the new bucket";


warning "You need to mirror the MinIO buckets (Assets and Postgres) to the new bucket";
warning "|
> mc alias set $APP_NAME https://endpoint USERNAME PASSWORD
> mc alias set clone-$APP_NAME https://endpoint USERNAME PASSWORD

> mc mirror $APP_NAME/$APP_NAME--de clone-$APP_NAME/$APP_NAME--de
"

ask_confirmation "Are the buckets successfully mirrored ? (y/n)";

exit 0
success "[*][5/6] Create Postgres objects and Decidim";
execute "kubectl create -n $NAMESPACE -f $APP_NAME-postgres.yaml";
execute "kubectl create -n $NAMESPACE -f $APP_NAME-decidim.yaml";

success "[*][6/6] Edit the Organization host directly in database";
execute "kubectl exec -it $APP_NAME--de-0 -n $NAMESPACE -- bash -c 'psql -U postgres -d DATABASE_NAME -c \"UPDATE decidim_organizations SET host = 'clone-$APP_NAME.decidim.org' WHERE host = '$APP_NAME.decidim.org';\"'";

success "Done.";
# kubectl create -n $NAMESPACE -f FILE
# kubectl create -n $NAMESPACE -f FILE

