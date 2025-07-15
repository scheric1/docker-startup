# Docker Startup Bootstrap Script

This repository provides **`bootstrap-docker.sh`**, a one-shot script that prepares an Ubuntu (or other Debian-based) host for Docker development and deploys container stacks managed by docker compose.

## What the script does

1. **Install baseline packages** listed in the `EXTRA_PKGS` array.
2. **Verify Docker Engine** is installed and running.
3. **Install Docker Compose v2 plugin** if missing.
4. **Create a dedicated `docker` user** and add the first logged-in user to the group.
5. **Run a functional test** using `hello-world`.
6. **Pull and deploy compose stacks** from a Git repository.

Example compose files for Portainer and Uptime Kuma are provided under
`docker/`, each in its own subfolder. Any compose files placed in their own
directory will be deployed as a separate stack, allowing you to isolate
services by folder.

When complete, Portainer will be reachable at `https://<server_ip>:9443`.

## Customising the script

### Adding additional apt packages
Edit the `EXTRA_PKGS` array near the top of the script to include any packages you want installed:

```bash
EXTRA_PKGS=(vim git htop curl)
```

### Configuring the compose repository
Two variables control where compose files are fetched and deployed:

```bash
COMPOSE_REPO_URL="https://github.com/youruser/your-repo.git"
COMPOSE_CLONE_DIR="/opt/docker-stacks"
```

Change these before running the script if you want to use a different repository or directory.

### Organizing compose stacks
Place each compose file inside its own subdirectory under `docker/` to create a
separate stack. The bootstrap script derives the stack name from the folder
name, so `docker/my-app/docker-compose.yml` will appear as stack `my-app` in
Portainer.

## Running the script remotely
Execute the script directly via `curl` and `bash` (run as root or with sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/scheric1/docker-startup/main/bootstrap-docker.sh | sudo bash
```

This will download the latest version and run it in one step.

## Requirements
* Ubuntu 22.04 or newer (or any compatible Debian-based distribution)
* Docker already installed on the host

## License
MIT
