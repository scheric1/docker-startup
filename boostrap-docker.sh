#!/usr/bin/env bash
###############################################################################
# bootstrap-docker.sh – One-shot bootstrap for Docker-ready Ubuntu VMs
# Works on Ubuntu 22.04/24.04 (and most Debian-based) – run as root
###############################################################################
set -euo pipefail

# ───────────── CONFIG SECTION ────────────────────────────────────────────────
# List any baseline packages you want on every host here.
EXTRA_PKGS=(vim)          # ← add more:  EXTRA_PKGS=(vim git htop)

# Portainer ports (change if you like)
PORTAINER_UI_PORT=9443
PORTAINER_AGENT_PORT=8000
# ─────────────────────────────────────────────────────────────────────────────

info()  { printf '\e[32m[INFO]\e[0m  %s\n' "$*"; }
warn()  { printf '\e[33m[WARN]\e[0m  %s\n' "$*"; }
fatal() { printf '\e[31m[FAIL]\e[0m  %s\n' "$*"; exit 1; }

###############################################################################
# 0. Refresh APT cache & install baseline tools
###############################################################################
info "Updating package index and installing baseline packages…"
apt-get update -qq
if ((${#EXTRA_PKGS[@]})); then
  apt-get install -y -qq "${EXTRA_PKGS[@]}"
  info "Installed/verified packages: ${EXTRA_PKGS[*]} ✔"
fi

###############################################################################
# 1. Verify Docker Engine is present & running
###############################################################################
command -v docker >/dev/null 2>&1 || fatal "Docker not found – aborting."
docker_version=$(docker --version | awk '{print $3}' | tr -d ,)
info "Docker detected (version $docker_version)"

systemctl start docker
systemctl enable docker
info "Docker service is active and enabled ✔"

###############################################################################
# 2. Ensure Docker Compose v2 (plugin)
###############################################################################
if docker compose version >/dev/null 2>&1; then
  info "Docker Compose plugin already installed ✔"
else
  info "Docker Compose plugin missing – installing…"
  apt-get install -y -qq docker-compose-plugin && \
    info "Installed docker-compose-plugin via apt ✔"
fi

###############################################################################
# 3. Ensure docker group & docker service user
###############################################################################
# Guarantee docker group exists (usually created by the package, but just in case)
groupadd -f docker

# Create a system user 'docker' with no login shell and no password if absent
if ! id -u docker >/dev/null 2>&1; then
  useradd --system --gid docker --shell /usr/sbin/nologin docker
  info "Created system user 'docker' (no shell) ✔"
fi

# Optionally add the first real login user to docker group for convenience
default_user=$(logname 2>/dev/null || true)
if [[ -n "$default_user" && "$default_user" != "root" ]]; then
  if id -nG "$default_user" | grep -qw docker; then
    info "User '$default_user' already in docker group ✔"
  else
    usermod -aG docker "$default_user"
    info "Added '$default_user' to docker group (re-login required)"
  fi
fi

###############################################################################
# 4. Functional test: run hello-world as the docker user
###############################################################################
info "Running Docker hello-world test as 'docker' user…"
if su -s /bin/sh -c "docker run --rm hello-world" docker >/dev/null; then
  info "Docker hello-world ran successfully ✔"
else
  fatal "Docker test failed – investigate installation/network."
fi

###############################################################################
# 5. Deploy Portainer CE for web management
###############################################################################
docker volume create portainer_data >/dev/null 2>&1 || true

# Remove any existing Portainer container to ensure a clean (re)deploy
docker rm -f portainer >/dev/null 2>&1 || true

info "Deploying Portainer CE (web UI on https://<host>:${PORTAINER_UI_PORT})…"
docker run -d \
  --name portainer \
  --restart=always \
  -p ${PORTAINER_AGENT_PORT}:8000 \
  -p ${PORTAINER_UI_PORT}:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

###############################################################################
info "Bootstrap complete! 🎉
- Installed baseline packages: ${EXTRA_PKGS[*]:-"(none)"} 
- Dedicated 'docker' user created (no password, no login shell)
- First non-root user added to docker group (if present)
- Docker & Compose verified
- Portainer running → https://<server_ip>:${PORTAINER_UI_PORT}

Remember:   usermod --append --groups docker <your_user>
to grant additional users Docker access.
"
