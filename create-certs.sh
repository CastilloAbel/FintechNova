mkdir -p certs
# Generate a self-signed certificate for the Traefik dashboard on localhost
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/local.key -out certs/local.crt \
  -subj "/CN=*.docker.localhost"

# Generate a self-signed certificate for the Traefik dashboard on AWS
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/local.key \
  -out certs/local.crt \
  -subj "/CN=ec2-54-227-65-13.compute-1.amazonaws.com" \
  -addext "subjectAltName=DNS:ec2-54-227-65-13.compute-1.amazonaws.com"


# Create a password for the Traefik dashboard
htpasswd -nb admin "P@ssw0rd" | sed -e 's/\$/\$\$/g'