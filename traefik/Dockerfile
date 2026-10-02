FROM traefik:v3.7

COPY traefik.yml /traefik.yml
COPY dynamic /dynamic

ENTRYPOINT ["traefik", "--configFile=/traefik.yml"]