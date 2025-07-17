#!/bin/bash

set -euo pipefail

# ------------------ LOAD CONFIG FROM .env ------------------

ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Error: $ENV_FILE not found. Please create one with required variables."
  exit 1
fi

# Load .env file
export $(grep -v '^#' "$ENV_FILE" | xargs -d '\n')

# ------------------ REQUIRED VARIABLES ---------------------

REQUIRED_VARS=(
  CONTAINER_NAME
  ARANGO_IMAGE
  DB_VOLUME
  LISTEN_IP
  LISTEN_PORT
  ARANGO_ROOT_PASSWORD
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "❌ Error: Environment variable $var is not set in $ENV_FILE"
    exit 1
  fi
done

# ------------------ FUNCTIONS ------------------

start_arango() {
  echo "🚀 Starting ArangoDB container: $CONTAINER_NAME..."

  if docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🔄 Container already exists. Starting..."
    docker start "$CONTAINER_NAME"
  else
    echo "📦 Creating and starting new ArangoDB container..."
    docker run -d \
      --name "$CONTAINER_NAME" \
      --restart=always \
      -p "${LISTEN_IP}:${LISTEN_PORT}:8529" \
      -v "${DB_VOLUME}:/var/lib/arangodb3" \
      -e ARANGO_ROOT_PASSWORD="${ARANGO_ROOT_PASSWORD}" \
      "$ARANGO_IMAGE"
  fi
  echo "✅ ArangoDB is running."
}

stop_arango() {
  echo "🛑 Stopping ArangoDB container..."
  if docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker stop "$CONTAINER_NAME"
    echo "✅ Container stopped."
  else
    echo "🤷 Container not running."
  fi
}

restart_arango() {
  echo "🔁 Restarting ArangoDB..."
  docker restart "$CONTAINER_NAME"
  echo "✅ Restarted."
}

status_arango() {
  echo "📊 Status of ArangoDB container ($CONTAINER_NAME):"
  docker ps -a --filter "name=^${CONTAINER_NAME}$"
}

# ------------------ CLI Interface ------------------

case "${1:-}" in
  start)
    start_arango
    ;;
  stop)
    stop_arango
    ;;
  restart)
    restart_arango
    ;;
  status)
    status_arango
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    echo "Make sure you have a .env file with all required variables."
    exit 1
    ;;
esac
