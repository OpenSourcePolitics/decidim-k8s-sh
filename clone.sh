#!/usr/bin/env bash

NAMESPACE=$1;
APP_NAME=$2;
CLONE_NAME=$3;
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
  echo "Usage: $0 <namespace> <app_name> <clone_name>";
  exit 1
fi

warning "You about to CLONE $NAMESPACE/$APP_NAME: ";

warning "Here are the steps that will be performed:";
warning "1. Copy YAML from objects: Decidim, Assets Bucket, Postgres Bucket, Postgres, Custom Env Secret, RAILS_SECRET Secret"
warning "2. Rename all occurrences of $APP_NAME to $CLONE_NAME in the YAML files"
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
execute "kubectl get secret $APP_NAME--de -n $NAMESPACE -o yaml > $CLONE_NAME--de-secret.yaml";
execute "kubectl get secret $APP_NAME-custom-env -n $NAMESPACE -o yaml > $CLONE_NAME-custom-env-secret.yaml";
execute "kubectl get decidim $APP_NAME -n $NAMESPACE -o yaml > $CLONE_NAME-decidim.yaml";
execute "kubectl get bucket $APP_NAME--de -n $NAMESPACE -o yaml > $CLONE_NAME-bucket.yaml";
execute "kubectl get bucket $APP_NAME--de-pg -n $NAMESPACE -o yaml > $CLONE_NAME-bucket-pg.yaml";
execute "kubectl get postgres $APP_NAME--de -n $NAMESPACE -o yaml > $CLONE_NAME-postgres.yaml";

success "[*][2/6] Renaming all occurrences of $APP_NAME to $CLONE_NAME in the YAML files";

for file in $(ls); do
  success "[*] Processing $file";
  execute "sed -i '' 's/$APP_NAME/$CLONE_NAME/g' $file";
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
execute "kubectl create -n $NAMESPACE -f $CLONE_NAME-bucket.yaml";
execute "kubectl create -n $NAMESPACE -f $CLONE_NAME-bucket-pg.yaml";

success "[*][4/6] MANUALLY: Mirror the MinIO buckets (Assets and Postgres) to the new bucket";
warning "You need to mirror the MinIO buckets (Assets and Postgres) to the new bucket";
for i in $(seq 1 5); do
  echo -n "."
  sleep 1
done
APP_ENDPOINT_BUCKET=$(kubectl get secret $APP_NAME--de.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.endpoint} | base64 -D)
APP_USERNAME_BUCKET=$(kubectl get secret $APP_NAME--de.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.username} | base64 -D)
APP_PASSWORD_BUCKET=$(kubectl get secret $APP_NAME--de.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.password} | base64 -D)
APP_NAME_BUCKET=$(kubectl get secret $APP_NAME--de.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.bucket} | base64 -D)

CLONE_ENDPOINT_BUCKET=$(kubectl get secret $CLONE_NAME--de.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.endpoint} | base64 -D)
CLONE_USERNAME_BUCKET=$(kubectl get secret $CLONE_NAME--de.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.username} | base64 -D)
CLONE_PASSWORD_BUCKET=$(kubectl get secret $CLONE_NAME--de.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.password} | base64 -D)
CLONE_NAME_BUCKET=$(kubectl get secret $CLONE_NAME--de.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.bucket} | base64 -D)

PG_ENDPOINT_BUCKET=$(kubectl get secret $APP_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.endpoint} | base64 -D)
PG_USERNAME_BUCKET=$(kubectl get secret $APP_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.username} | base64 -D)
PG_PASSWORD_BUCKET=$(kubectl get secret $APP_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.password} | base64 -D)
PG_NAME_BUCKET=$(kubectl get secret $APP_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.bucket} | base64 -D)

PG_CLONE_ENDPOINT_BUCKET=$(kubectl get secret $CLONE_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.endpoint} | base64 -D)
PG_CLONE_USERNAME_BUCKET=$(kubectl get secret $CLONE_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.username} | base64 -D)
PG_CLONE_PASSWORD_BUCKET=$(kubectl get secret $CLONE_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.password} | base64 -D)
PG_CLONE_BUCKET=$(kubectl get secret $CLONE_NAME--de-pg.bucket.libre.sh -n $NAMESPACE -o jsonpath={.data.bucket} | base64 -D)
warning "|
APP_NAME: $APP_NAME | Endpoint:
> mc alias set $ALIAS_NAME https://$APP_ENDPOINT_BUCKET $APP_USERNAME_BUCKET $APP_PASSWORD_BUCKET
> mc alias set staging-$ALIAS_NAME https://$CLONE_ENDPOINT_BUCKET $CLONE_USERNAME_BUCKET $CLONE_PASSWORD_BUCKET

> mc alias set $ALIAS_NAME-pg https://$PG_ENDPOINT_BUCKET $PG_USERNAME_BUCKET $PG_PASSWORD_BUCKET
> mc alias set staging-$ALIAS_NAME-pg https://$PG_CLONE_ENDPOINT_BUCKET $PG_CLONE_USERNAME_BUCKET $PG_CLONE_PASSWORD_BUCKET

> mc mirror $ALIAS_NAME/$APP_NAME_BUCKET staging-$ALIAS_NAME/$CLONE_NAME_BUCKET
> mc mirror $ALIAS_NAME-pg/$PG_NAME_BUCKET staging-$ALIAS_NAME-pg/$PG_CLONE_BUCKET
> explanation: ALIAS_NAME/NAMESPACE-APP_NAME--de
"

ask_confirmation "Are the buckets successfully mirrored ? (y/n)";
success "[*] Buckets mirrored successfully";
success "[*][5/6] Create Postgres objects and Decidim";
# execute "kubectl create -n $NAMESPACE -f $CLONE_NAME-postgres.yaml";
warning "|
Create your Postgres:
kubectl create -n $NAMESPACE -f $CLONE_NAME-postgres.yaml";
warning "|
Create your Secrets:
kubectl create -n $NAMESPACE -f $CLONE_NAME--de-secret.yaml
kubectl create -n $NAMESPACE -f $CLONE_NAME-custom-env-secret.yaml";

warning "|
Create your Decidim:
kubectl create -n $NAMESPACE -f $CLONE_NAME-decidim.yaml";

success "[*][6/6] Edit the Organization host directly in database";
warning "You need to edit the Organization host directly in database";
warning "|
kubectl exec -it $APP_NAME--de-0 -n $NAMESPACE -- bash -c 'psql -U postgres -d DATABASE_NAME -c \"UPDATE decidim_organizations SET host = '$CLONE_NAME.k8s.osp.cat' WHERE host = '$APP_NAME.k8s.osp.cat';\"'";
warning "|
OR
kubectl annotate decidim -n $NAMESPACE $CLONE_NAME decidim.libre.sh/maintenance='40'";
warning "|
bundle exec rake decidim_app:k8s:configure &&
bundle exec rake decidim:upgrade:content_blocks:initialize_default_content_blocks &&
bundle exec rake decidim:upgrade:clean:clean_deleted_users &&
bundle exec rake decidim_proposals:upgrade:set_categories &&
bundle exec rake decidim:upgrade:attachments_cleanup";

success "Done."


