mkdir -p certs
# Generate a self-signed certificate for the Traefik dashboard
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/local.key -out certs/local.crt \
  -subj "/CN=*.docker.localhost"


# Create a password for the Traefik dashboard
htpasswd -nb admin "P@ssw0rd" | sed -e 's/\$/\$\$/g'