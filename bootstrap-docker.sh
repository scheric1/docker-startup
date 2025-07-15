#!/usr/bin/env bash
###############################################################################
# bootstrap-docker.sh – One-shot bootstrap for Docker-ready Ubuntu VMs
# Works on Ubuntu 22.04/24.04 (and most Debian-based) – run as root
###############################################################################
set -euo pipefail

# ───────────── CONFIG SECTION ────────────────────────────────────────────────
# List any baseline packages you want on every host here.
# Baseline packages
EXTRA_PKGS=(vim jq)

# Git repo containing docker compose stacks (override in .env if desired)
COMPOSE_REPO_URL=${COMPOSE_REPO_URL:-"https://github.com/scheric1/docker-startup"}
COMPOSE_CLONE_DIR=${COMPOSE_CLONE_DIR:-"/opt/docker-stacks"}

# Portainer configuration
PORTAINER_VERSION=${PORTAINER_VERSION:-"2.19"}
PORTAINER_ADMIN_PWD=${PORTAINER_ADMIN_PWD:-"change-me"}
PORTAINER_DATA_VOL=${PORTAINER_DATA_VOL:-"portainer_data"}
PORTAINER_URL=${PORTAINER_URL:-"https://127.0.0.1:9443"}
# ─────────────────────────────────────────────────────────────────────────────

info()  { printf '\e[32m[INFO]\e[0m  %s\n' "$*"; }
warn()  { printf '\e[33m[WARN]\e[0m  %s\n' "$*"; }
fatal() { printf '\e[31m[FAIL]\e[0m  %s\n' "$*"; exit 1; }

# Load environment overrides if a .env file is present
if [[ -f .env ]]; then
  info "Loading variables from .env"
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

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
# 5. Pull compose repo
###############################################################################
if [[ ! -d "$COMPOSE_CLONE_DIR" ]]; then
  git clone "$COMPOSE_REPO_URL" "$COMPOSE_CLONE_DIR"
else
  git -C "$COMPOSE_CLONE_DIR" pull
fi

###############################################################################
# 6. Launch Portainer with admin password pre-seeded
###############################################################################
info "Launching Portainer $PORTAINER_VERSION…"
HASHED=$(docker run --rm httpd:2.4-alpine \
        htpasswd -nbB admin "$PORTAINER_ADMIN_PWD" | cut -d':' -f2)
docker volume create "$PORTAINER_DATA_VOL"
docker run -d --name portainer \
  -p 9443:9443 -p 8000:8000 \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PORTAINER_DATA_VOL":/data \
  portainer/portainer-ce:"$PORTAINER_VERSION" \
  --admin-password "$HASHED"

info "Waiting for Portainer API…"
until curl -skf "$PORTAINER_URL/api/status" >/dev/null; do sleep 2; done
info "Portainer is ready ✔"

###############################################################################
# 7. Deploy compose stacks through Portainer API
###############################################################################
JWT=$(curl -sk -X POST "$PORTAINER_URL/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"admin\",\"Password\":\"$PORTAINER_ADMIN_PWD\"}" | \
      jq -r .jwt)
ENDPOINT_ID=1

info "Deploying compose stacks via Portainer…"
find "$COMPOSE_CLONE_DIR/docker" -name '*.yml' | while read -r compose_file; do
  parent_dir=$(basename "$(dirname "$compose_file")")
  if [[ "$parent_dir" == "docker" ]]; then
    stack_name="$(basename "$compose_file" .yml)"
  else
    stack_name="$parent_dir"
  fi
  curl -sk -X POST \
    "$PORTAINER_URL/api/stacks?type=2&method=string&endpointId=$ENDPOINT_ID" \
    -H "Authorization: Bearer $JWT" -H "Content-Type: multipart/form-data" \
    -F "Name=$stack_name" \
    -F "StackFileContent=@$compose_file" \
    -F "EndpointID=$ENDPOINT_ID" >/dev/null
  info "Portainer deployed stack: $stack_name"
done

###############################################################################
info "Bootstrap complete! 🎉"
cat <<'EOM'
- Installed baseline packages (see EXTRA_PKGS)
- Dedicated 'docker' user created
- Docker & Compose verified
- Stacks deployed via Portainer

Remember:   usermod --append --groups docker <your_user>
to grant additional users Docker access.
EOM


