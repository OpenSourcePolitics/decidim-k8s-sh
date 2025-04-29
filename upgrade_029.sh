#!/usr/bin/env bash


APP_NAME=$2;
NAMESPACE=$1;
IMAGE_NAME=$3;
FILENAME_SECRETS=$APP_NAME-custom-env.yaml;
FILENAME_DECIDIM=$APP_NAME-decidim.yaml;

DOCKER_REGISTRY="rg.fr-par.scw.cloud\/decidim-app";

echo "[x] Exporting secrets and decidim configuration for $APP_NAME in namespace $NAMESPACE..."

mkdir -p ./dist/$NAMESPACE/$APP_NAME
cd ./dist/$NAMESPACE/$APP_NAME
kubectl get secret $APP_NAME-custom-env -n $NAMESPACE -o yaml > $FILENAME_SECRETS
kubectl get decidim $APP_NAME -n $NAMESPACE -o yaml > $FILENAME_DECIDIM
sed -i -r "s/^data:$/data:\n  STORAGE_PROVIDER: bWluaW8=/g" $FILENAME_SECRETS
echo "[x] Add STORAGE_PROVIDER to custom-env secret";

echo "[x] Using image $DOCKER_REGISTRY/$IMAGE_NAME";
sed -i -r "s/^  image: $DOCKER_REGISTRY.*/  image: $DOCKER_REGISTRY\/$IMAGE_NAME/g" $FILENAME_DECIDIM;

echo "[x] Adding MinIO credentials to custom-env secret";
echo "Key: AWS_ACCESS_KEY_ID"
echo "Key: AWS_BUCKET"
  echo "Key: AWS_ENDPOINT"
echo "Key: AWS_REGION"
echo "Key: AWS_SECRET_ACCESS_KEY"

echo "[-] Apply the new secrets and decidim configuration to the cluster"

echo -n "> kubectl apply -f $FILENAME_SECRETS -n $NAMESPACE"
echo -n "..."
#kubectl apply -f $FILENAME_SECRETS -n $NAMESPACE

echo -n "> kubectl apply -f $FILENAME_DECIDIM -n $NAMESPACE"
echo -n "..."
#kubectl apply -f $FILENAME_DECIDIM -n $NAMESPACE

echo "[x] Waiting for Decidim $APP_NAME to be running with the new image $DOCKER_REGISTRY/$IMAGE_NAME"

exit 0
watch -n 3 "kubectl get decidim $APP_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[*].message}'"
kubectl get decidim $APP_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[*].message}' | grep "Running" > /dev/null 2>&1


echo "[x] Decidim $APP_NAME is now running with the new image $DOCKER_REGISTRY/$IMAGE_NAME"
echo "[x] Cleaning up..."
