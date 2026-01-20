# Shell shortcut Configuration

Shortcut to run the project. Below is the configuration used in `go`:

```shell

#!/bin/bash

# --- BAGIAN 1: FITUR CREATE PROJECT ---
if [ "$1" = "create" ]; then
    PROJECT_NAME=$2

    if [ -z "$PROJECT_NAME" ]; then
        echo "Error: Please enter a project name."
        echo "Usage: go create <project-name>"
        exit 1
    fi

    if [ -d "$PROJECT_NAME" ]; then
        echo "Error: Directory '$PROJECT_NAME' already exist."
        exit 1
    fi

    echo "🚀 Starting project creation: $PROJECT_NAME..."
    mkdir -p "$PROJECT_NAME"

    cp "$0" "$PROJECT_NAME/go"
    cd "$PROJECT_NAME" || exit

    # 1. Generate .env
    cat <<EOF > .env
APP_NAME=
APP_DOMAIN=
APP_PORT=8080
EOF

    # 2. Generate .air.toml (Fixed for v1.64.0+)
    cat <<EOF > .air.toml
root = "."
tmp_dir = "tmp"

[build]
  cmd = "go build -o ./tmp/main ."
  full_bin = "./tmp/main"
  include_ext = ["go", "tpl", "tmpl", "html"]
  exclude_dir = ["assets", "tmp", "vendor"]

[log]
  time = true

[misc]
  clean_on_exit = true
EOF

    # 3. Generate .gitignore
    cat <<EOF > .gitignore
# Binaries
/tmp
/bin
/main

# Environment
.env
.DS_Store
docker-compose.yml
EOF

    # 4. Generate docker-compose.yml (DENGAN CACHE VOLUME)
    cat <<EOF > docker-compose.yml
services:
  app:
    image: ghcr.io/dowlatalib/go-air-dev:latest
    container_name: \${APP_NAME}_app
    env_file: .env
    volumes:
      - .:/app
      - go_data:/go/pkg
      - go_build_cache:/root/.cache/go-build
    environment:
      - PORT=\${APP_PORT}
    networks:
      - default
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      - "traefik.http.routers.\${APP_NAME}.rule=Host(\`\${APP_DOMAIN}\`)"
      - "traefik.http.routers.\${APP_NAME}.entrypoints=web"
      - "traefik.http.services.\${APP_NAME}.loadbalancer.server.port=\${APP_PORT}"

networks:
  proxy:
    external: true

# Definisi Volume untuk Cache
volumes:
  go_data:
  go_build_cache:
EOF

    # 5. Generate main.go
    cat <<EOF > main.go
package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello from %s!", os.Getenv("APP_NAME"))
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	fmt.Printf("Server running on port %s\n", port)
	http.ListenAndServe(":"+port, nil)
}
EOF

    # 6. Inisiasi Go Module
    echo "📦 Initialize Go Module..."
    docker run --rm -v "$(pwd):/app" -w /app golang:1.23-alpine go mod init "$PROJECT_NAME"

    echo "✅ Project '$PROJECT_NAME' created!"
    echo "📂 Go to directory: cd $PROJECT_NAME"
    echo "🚀 Run server: go up"

    exit 0
fi

# --- BAGIAN 2: LOGIKA RUNNER ---

APP_SERVICE="app"

if [ ! -f "compose.yaml" ] && [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found."
    echo "Use: go create <project-name>"
    exit 1
fi

if [ -t 1 ]; then EXEC_FLAGS="-it"; else EXEC_FLAGS=""; fi

compose() { docker compose "$@"; }

execute() {
    if [ -z "$(docker compose ps -q $APP_SERVICE 2>/dev/null)" ]; then
        echo "🔄 Container not running. Run 'up -d'..."
        docker compose up -d
    fi
    docker compose exec $EXEC_FLAGS "$APP_SERVICE" "$@"
}

if [[ "$1" =~ ^(up|down|start|stop|restart|build|logs|ps|pull)$ ]]; then
    compose "$@"
    exit $?
fi

if [ "$1" = "shell" ] || [ "$1" = "sh" ]; then
    execute sh
    exit $?
fi

# 4. Shortcut: Extract SDK for IDE (GoLand/VSCode)
if [ "$1" = "sdk" ]; then
    SDK_DIR="$HOME/go-docker-sdk"
    
    # Ambil Base Image dari variable atau parse dari Dockerfile jika ada
    # Fallback ke image default kita jika tidak terdeteksi
    IMAGE_TO_PULL="ghcr.io/USERNAME/go-air-dev:latest" # GANTI DENGAN IMAGE ANDA
    
    # Cek apakah di folder project ada Dockerfile dan gunakan FROM-nya jika mungkin
    if [ -f "Dockerfile" ]; then
        DETECTED_IMAGE=$(grep "^FROM" Dockerfile | head -n 1 | awk '{print $2}')
        if [ ! -z "$DETECTED_IMAGE" ]; then
            IMAGE_TO_PULL=$DETECTED_IMAGE
        fi
    fi

    echo "📦 Menyiapkan SDK untuk IDE dari image: $IMAGE_TO_PULL"
    
    # Hapus SDK lama jika ada
    if [ -d "$SDK_DIR" ]; then
        echo "🗑️  Menghapus SDK lama..."
        rm -rf "$SDK_DIR"
    fi

    echo "⏳ Sedang mengekstrak /usr/local/go dari container..."
    
    # Buat container sementara, copy folder go, lalu hapus container
    CONTAINER_ID=$(docker create $IMAGE_TO_PULL)
    docker cp $CONTAINER_ID:/usr/local/go $SDK_DIR
    docker rm $CONTAINER_ID > /dev/null

    echo "✅ SDK berhasil diekstrak ke: $SDK_DIR"
    echo "ℹ️  Buka GoLand -> Settings -> Go -> GOROOT"
    echo "ℹ️  Pilih 'Add SDK' -> 'Local' -> Arahkan ke: $SDK_DIR"
    exit 0
fi

# 5. MIGRATE WRAPPER (Baru!)
# Jika perintah diawali 'migrate', jalankan binary migrate langsung, bukan 'go migrate'
if [ "$1" = "migrate" ]; then
    execute "$@"
    exit $?
fi

execute go "$@"

```
