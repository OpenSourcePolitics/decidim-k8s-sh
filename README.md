# Decidim k8s scripts

This repository is destined to manage Decidim applications on Kubernetes for internal purposes.

⚠️ The scripts are intended for production use and should be used with caution.

# This repository contains scripts to manage Decidim on Kubernetes.

### Prerequisites
- Kubernetes cluster
- Kubectl

### Clone app

Run clone script :
```bash
./clone.sh <namespace> <app> <clone_app>
```

Follow the instructions to create a new app in the same namespace.

### Suspend script

Script `suspend.sh` is used to suspend an app in a namespace. It suspends the Decidim object, add a label `libre.sh/delete_date`to the Decidim object, removes the dedicated ingress and stops App, Sidekiq, Memcached Deployment objects.

```bash
./suspend.sh <namespace> <app>
```

### Upgrade app

WIP

### Destroy app

WIP

### Upgrade app 0.29

WIP