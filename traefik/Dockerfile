FROM traefik:v3.7

COPY traefik.yml /traefik.yml
COPY dynamic /dynamic

USER 65532

ENTRYPOINT ["traefik", "--configFile=/traefik.yml"]