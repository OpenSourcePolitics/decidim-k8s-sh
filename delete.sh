#!/usr/bin/env bash

NAMESPACE=$1;
APP_NAME=$2;

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

if [ -z "$NAMESPACE" ] || [ -z "$APP_NAME" ]; then
  error "error: Missing arguments";
  echo "Usage: $0 <namespace> <app_name> <image_name:tag>";
  exit 1
fi

error "DANGER: This script will delete the application $APP_NAME in namespace $NAMESPACE";
read -r -p "This script will drop the entire app $NAMESPACE/$APP_NAME, do you confirm? (y/n)" response
if [[ ! "$response" =~ ^(yes|y)$ ]]; then
  error "Aborting the script";
  exit 1
fi

success "[*] Deleting application $APP_NAME in namespace $NAMESPACE";
