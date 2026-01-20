# Gunakan versi terbaru
FROM golang:1.25-alpine

# Install dependencies
RUN apk add --no-cache git curl build-base

WORKDIR /app

# 1. Install Air
RUN curl -sSfL https://raw.githubusercontent.com/air-verse/air/master/install.sh | sh -s -- -b /go/bin

# 2. Install Migrate
RUN go install -tags 'postgres,mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# 3. [BARU] Fix Permission untuk Multi-User
# Kita ubah folder /go agar bisa ditulis oleh user ID berapapun (chmod 777).
# Ini aman untuk dev environment dan krusial agar user host bisa download library.
RUN mkdir -p /go/pkg && chmod -R 777 /go

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]
