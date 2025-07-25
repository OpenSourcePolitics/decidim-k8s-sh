#!/usr/bin/env bash

HOST=$1;

if [ -z "$HOST" ]; then
  error "error: Missing arguments";
  echo "Usage: $0 <host>";
  echo "Example: $0 club.decidim.opensourcepolitics.eu";
  exit 1
fi

#kubectl get decidim -A | grep $HOST | awk -F' ' '{print "Host: "$3 "\nnamespace: " $1 "\ndecidim: " $2}'

kubectl get decidim -A | while IFS=' ' read -r line; do
  if [[ "$line" == *"$HOST"* ]]; then
    Host=$(echo "$line" | awk '{print $3}')
    Namespace=$(echo "$line" | awk '{print $1}')
    Decidim=$(echo "$line" | awk '{print $2}')
    Image=$(kubectl get decidim $Decidim -n $Namespace -o jsonpath='{.spec.image}')
    echo "Host: $Host"
    echo "namespace: $Namespace"
    echo "decidim: $Decidim"
    echo "image: $Image"
  fi
done

