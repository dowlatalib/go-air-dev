FROM golang:1.23-alpine

# Install git dan curl
RUN apk add --no-cache git curl
WORKDIR /app

# Install Air (Metode Binary)
RUN curl -sSfL https://raw.githubusercontent.com/air-verse/air/master/install.sh | sh -s -- -b /go/bin

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]