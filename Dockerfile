FROM golang:1.23-alpine

# Install git, curl, dan build-base (diperlukan jika library butuh CGO)
RUN apk add --no-cache git curl build-base

WORKDIR /app

# 1. Install Air (Live Reload)
RUN curl -sSfL https://raw.githubusercontent.com/air-verse/air/master/install.sh | sh -s -- -b /go/bin

# 2. Install Golang-Migrate
# Kita sertakan tags untuk database populer (Postgres, MySQL)
RUN go install -tags 'postgres,mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]
