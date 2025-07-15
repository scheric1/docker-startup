# Docker Startup Bootstrap Script

This repository provides **`bootstrap-docker.sh`**, a one-shot script that prepares an Ubuntu or other Debian-based host for Docker development and deploys [Portainer CE](https://www.portainer.io/).

## What the script does

1. **Install baseline packages** – uses apt to install any packages listed in the `EXTRA_PKGS` array (defaults to `vim`).
2. **Verify Docker Engine** – installs Docker if needed and ensures it is running.
3. **Install Docker Compose v2 plugin** – installs the `docker-compose-plugin` if missing.
4. **Create a dedicated `docker` user** – sets up a system user and adds the first logged-in user to the `docker` group.
5. **Run a functional test** – executes `hello-world` using the `docker` user.
6. **Deploy Portainer CE** – starts the container with the UI on port `9443` and agent on port `8000` by default.

When complete, Portainer will be reachable at `https://<server_ip>:9443`.

## Customising the script

### Adding additional apt packages
Edit the `EXTRA_PKGS` array near the top of the script to include any packages you want installed:

```bash
EXTRA_PKGS=(vim git htop curl)
```

The script installs each package via `apt-get install` at runtime.

### Configuring Portainer
Two variables control the Portainer ports:

```bash
PORTAINER_UI_PORT=9443    # HTTPS web UI
PORTAINER_AGENT_PORT=8000 # Agent port
```

Change these before running the script if you need different ports. The script recreates the Portainer container each time so changes are applied on the next execution.

## Running the script remotely
Execute the script directly via `curl` and `bash` (run as root or with sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/scheric1/docker-startup/main/boostrap-docker.sh | sudo bash
```

This will download the latest version and run it in one step.

## Requirements
* Ubuntu 22.04 or newer (or any compatible Debian-based distribution)
* Docker will be installed automatically if missing

## License
MIT
