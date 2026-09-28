FROM golang:1.22-alpine AS build
WORKDIR /src

COPY api-transacciones/go.mod api-transacciones/go.sum ./
RUN go mod download

COPY api-transacciones/* .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" \
    -o /out/api-transacciones .

FROM alpine:3.21
RUN apk add --no-cache ca-certificates

COPY --from=build /out/api-transacciones /api-transacciones

ENV PORT=8084
EXPOSE 8084

ENTRYPOINT ["/api-transacciones"]