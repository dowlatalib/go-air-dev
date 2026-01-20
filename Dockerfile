# Ubah versi di sini
FROM golang:1.25-alpine

RUN apk add --no-cache git curl build-base

WORKDIR /app

# Install Air
RUN curl -sSfL https://raw.githubusercontent.com/air-verse/air/master/install.sh | sh -s -- -b /go/bin

# Install Migrate (Sekarang Anda BISA menggunakan @latest lagi karena Go 1.25 support library terbaru)
RUN go install -tags 'postgres,mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]
