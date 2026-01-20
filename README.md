# Shell shortcut Configuration

Shortcut to run the project. Below is the configuration used in `go`:

```shell
#!/bin/bash

# --- BAGIAN 1: FITUR CREATE PROJECT ---
if [ "$1" = "create" ]; then
    PROJECT_NAME=$2
    # Pastikan ini image GHCR Anda
    BASE_IMAGE="ghcr.io/dowlatalib/go-air-dev:latest" 

    if [ -z "$PROJECT_NAME" ]; then
        echo "Error: Harap masukkan nama project."
        echo "Usage: go create <nama-project>"
        exit 1
    fi

    if [ -d "$PROJECT_NAME" ]; then
        echo "Error: Directory '$PROJECT_NAME' sudah ada."
        exit 1
    fi

    echo "🚀 Memulai pembuatan project: $PROJECT_NAME..."
    mkdir -p "$PROJECT_NAME"
    
    cp "$0" "$PROJECT_NAME/go"
    cd "$PROJECT_NAME" || exit

    # [UPDATE] Ambil UID dan GID host saat ini
    CURRENT_UID=$(id -u)
    CURRENT_GID=$(id -g)

    # 1. Generate .env (Menyimpan UID/GID)
    cat <<EOF > .env
APP_NAME=${PROJECT_NAME}
APP_DOMAIN=${PROJECT_NAME}.localhost
APP_PORT=8080
# User ID mapping agar file permissions aman
APP_UID=${CURRENT_UID}
APP_GID=${CURRENT_GID}
# Database Config
DB_URL=postgres://user:pass@db:5432/${PROJECT_NAME}?sslmode=disable
EOF

    # 2. Generate Dockerfile
    cat <<EOF > Dockerfile
FROM ${BASE_IMAGE}
WORKDIR /app
EXPOSE 8080
CMD ["air", "-c", ".air.toml"]
EOF

    # 3. Generate .air.toml
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

    # 4. Generate .gitignore
    cat <<EOF > .gitignore
# Binaries
/tmp
/bin
/main

# Environment
docker-compose.yml
.env
.DS_Store

# Dependencies
vendor/
EOF

    # 5. Generate docker-compose.yml (MENGGUNAKAN USER DARI ENV)
    cat <<EOF > docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    container_name: \${APP_NAME}_app
    env_file: .env
    
    # [PENTING] Menjalankan container sebagai user Host
    user: "\${APP_UID}:\${APP_GID}"
    
    volumes:
      - .:/app
      - go_data:/go/pkg
      - go_build_cache:/root/.cache/go-build
    environment:
      - PORT=\${APP_PORT}
      # Set HOME ke /tmp agar tool yang butuh write ke home tidak error
      # (Karena user host mungkin tidak punya home di dalam container)
      - HOME=/tmp
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
	  - "traefik.docker.network=proxy"
      - "traefik.http.routers.${PROJECT_NAME}.rule=Host(\`\${APP_DOMAIN}\`)"
      - "traefik.http.routers.${PROJECT_NAME}.entrypoints=web"
      - "traefik.http.services.${PROJECT_NAME}.loadbalancer.server.port=\${APP_PORT}"

networks:
  proxy:
    external: true

volumes:
  go_data:
  go_build_cache:
EOF

    # 6. Generate main.go
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
    if port == "" { port = "8080" }
	fmt.Printf("Server running on port %s\n", port)
	http.ListenAndServe(":"+port, nil)
}
EOF

    echo "📦 Menginisialisasi Go Module..."
    # Kita jalankan init dengan user host juga
    docker run --rm --user "${CURRENT_UID}:${CURRENT_GID}" -v "$(pwd):/app" -w /app ${BASE_IMAGE} go mod init "$PROJECT_NAME"

    echo "✅ Project '$PROJECT_NAME' berhasil dibuat!"
    echo "🚀 Jalankan server: go up"
    
    exit 0
fi

# --- BAGIAN 2: LOGIKA RUNNER ---

APP_SERVICE="app"

if [ ! -f "compose.yaml" ] && [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml tidak ditemukan."
    exit 1
fi

if [ -t 1 ]; then EXEC_FLAGS="-it"; else EXEC_FLAGS=""; fi

compose() { docker compose "$@"; }

execute() {
    # Cek apakah container jalan
    if [ -z "$(docker-compose ps -q $APP_SERVICE 2>/dev/null)" ]; then
        echo "🔄 Container belum jalan. Menjalankan 'up -d'..."
        # Kita nyalakan container (pastikan compose.yml sudah terkonfigurasi user-nya dengan benar)
        docker compose up -d
    fi

    # Ambil UID dan GID user host saat ini
    HOST_UID=$(id -u)
    HOST_GID=$(id -g)

    # Penjelasan Flag Tambahan:
    # -u "$HOST_UID:$HOST_GID" : Memaksa perintah berjalan sebagai user host.
    # -e HOME=/tmp             : Mengatur home directory ke /tmp (karena user ID host 
    #                            mungkin tidak punya folder home di /etc/passwd container).
    
    docker compose exec $EXEC_FLAGS \
        -u "$HOST_UID:$HOST_GID" \
        -e HOME=/tmp \
        "$APP_SERVICE" "$@"
}

# 1. Command Docker
if [[ "$1" =~ ^(up|down|start|stop|restart|build|logs|ps|pull)$ ]]; then
    compose "$@"
    exit $?
fi

# 2. Shell Shortcut
if [ "$1" = "shell" ] || [ "$1" = "sh" ]; then
    execute sh
    exit $?
fi

# 3. SDK Helper (Updated for Permission)
if [ "$1" = "sdk" ]; then
    SDK_DIR="$HOME/go-docker-sdk"
    IMAGE_TO_PULL="ghcr.io/dowlatalib/go-air-dev:latest"
    
    if [ -f "Dockerfile" ]; then
        DETECTED_IMAGE=$(grep "^FROM" Dockerfile | head -n 1 | awk '{print $2}')
        if [ ! -z "$DETECTED_IMAGE" ]; then IMAGE_TO_PULL=$DETECTED_IMAGE; fi
    fi

    echo "📦 Extracting SDK from: $IMAGE_TO_PULL"
    if [ -d "$SDK_DIR" ]; then rm -rf "$SDK_DIR"; fi
    
    CONTAINER_ID=$(docker create $IMAGE_TO_PULL)
    docker cp $CONTAINER_ID:/usr/local/go $SDK_DIR
    docker rm $CONTAINER_ID > /dev/null
    
    echo "✅ SDK extracted to: $SDK_DIR"
    exit 0
fi

# 4. Fallback Command (Go, Migrate, dll)
# Karena container sudah berjalan dengan USER host (via docker-compose user:),
# kita tidak perlu lagi melakukan 'chown' manual atau trik permission lainnya.
# Semua command (migrate create, go build, dll) otomatis aman!

if [ "$1" = "migrate" ]; then
    # Khusus migrate, kita pastikan argumen dipass dengan benar
    execute "$@"
    exit $?
fi

# Default Go Wrapper
execute go "$@"
```
