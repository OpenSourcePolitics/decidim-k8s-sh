#!/usr/bin/env bash


APP_NAME=$2;
NAMESPACE=$1;
FILENAME_SECRETS=$APP_NAME-custom-env.yaml;
FILENAME_DECIDIM=$APP_NAME-decidim.yaml;

echo "Exporting secrets and decidim configuration for $APP_NAME in namespace $NAMESPACE..."

mkdir -p ./dist/$NAMESPACE/$APP_NAME
cd ./dist/$NAMESPACE/$APP_NAME
kubectl get secret $APP_NAME-custom-env -n $NAMESPACE -o yaml > $FILENAME_SECRETS
kubectl get decidim $APP_NAME -n $NAMESPACE -o yaml > $FILENAME_DECIDIM

