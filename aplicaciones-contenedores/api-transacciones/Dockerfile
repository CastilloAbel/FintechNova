FROM golang:1.26-alpine3.22 AS build
WORKDIR /src

RUN apk upgrade --no-cache
COPY api-transacciones/go.mod api-transacciones/go.sum ./
RUN go mod download

COPY api-transacciones/* .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" \
    -o /out/api-transacciones .

FROM alpine:3.22
RUN apk upgrade --no-cache && apk add --no-cache ca-certificates
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=build --chown=appuser:appgroup /out/api-transacciones /api-transacciones

ENV PORT=8084
EXPOSE 8084

USER appuser

ENTRYPOINT ["/api-transacciones"]