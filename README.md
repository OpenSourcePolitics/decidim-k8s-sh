# Decidim k8s scripts

This repository is destined to manage Decidim applications on Kubernetes for internal purposes.

⚠️ The scripts are intended for production use and should be used with caution.

# This repository contains scripts to manage Decidim on Kubernetes.

### Prerequisites
- Kubernetes cluster
- Kubectl

### Clone app
✅ Ready for production use.

Run clone script :
```bash
./clone.sh <namespace> <app> <clone_app>
```

Follow the instructions to create a new app in the same namespace.

### Suspend script
✅ Ready for production use.

Script `suspend.sh` is used to suspend an app in a namespace. It suspends the Decidim object, add a label `libre.sh/delete_date`to the Decidim object, removes the dedicated ingress and stops App, Sidekiq, Memcached Deployment objects.

```bash
./suspend.sh <namespace> <app>
```

### Upgrade app
Upgrade the Decidim version of the target Decidim

 ✅ Ready for production use.

 Run clone script :
 ```bash
 ./upgrade.sh <namespace> <app> <image_name:tag>
 ```

### Destroy app

WIP

### Upgrade app 0.29
✅ Ready for production use.

Script `upgrade_029.sh` is used to upgrade a Decidim app to version 0.29. It performs a simple upgrade of the app image to the specified version, and edit the secrets according to the expectations. Moreover, it gives some indications about next command to run. 

This script is only useful for the first upgrade in 0.29, then it is recommended to use the default ugprade script `upgrade.sh`.

```bash
  ./upgrade_029.sh <namespace> <app> <image_docker:tag>
```
