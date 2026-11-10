FROM golang:1.26.10-alpine3.24 AS gosu-build

ARG GOSU_COMMIT=29b939aa5bd4dc588af765b8248f6e39150d2565
RUN mkdir -p /src/gosu \
	&& wget -qO- "https://codeload.github.com/tianon/gosu/tar.gz/${GOSU_COMMIT}" \
		| tar -xz --strip-components=1 -C /src/gosu \
	&& cd /src/gosu \
	&& CGO_ENABLED=0 GOTOOLCHAIN=local go build -mod=readonly -trimpath \
		-ldflags="-s -w" -o /gosu .

FROM mariadb:11.8

RUN apt-get update \
    && apt-get install -y --only-upgrade apt libapt-pkg6.0t64 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=gosu-build /gosu /usr/local/bin/gosu
COPY init-scripts/ /docker-entrypoint-initdb.d/
