FROM golang:1.26.10-alpine3.24 AS gosu-build

RUN CGO_ENABLED=0 GOTOOLCHAIN=local go install github.com/tianon/gosu@v1.19

FROM mariadb:11.8

COPY --from=gosu-build /go/bin/gosu /usr/local/bin/gosu
COPY init-scripts/ /docker-entrypoint-initdb.d/