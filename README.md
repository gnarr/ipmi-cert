# Supermicro IPMI certificate updater

This is a modified version of `Supermicro IPMI certificate updater` with a docker to run as a daemon.

### Differences from Jari's original SICU
- `--quiet` flag has been removed in favor of a `--debug` flag
    - logs are are seperated into debug, info, warning and error levels
    - program always prints info, warning and error logs
- IPMI certificate expiry is checked against the supplied PEM certificate expiry, if same, certificate will not be updated
  - there has been added a `--skip-expiry-check` flag with a default value of false


### Running with docker

#### Configurable environment variables:
- `IPMI_URL` Supermicro IPMI 2.0 URL
- `USERNAME` IPMI username with admin access
- `USERNAME_FILE` A file containing the username. Overrides `USERNAME` when supplied.
- `PASSWORD` IPMI user password
- `PASSWORD_FILE` A file containing the password. Overrides `USERNAME` when supplied.
- `KEY_FILE` X.509 Private key filename (default: `"/cert/privkey.pem"`)
- `CERT_FILE` X.509 Certificate filename (default: `"/cert/cert.pem"`)
- `CRON_STRING` [cront string](https://crontab.guru/) running schedule (default: `"5 6 * * *"`)
- `SKIP_EXPIRY_CHECK` Ignore checking if the IPMI certificate and the supplied certificate have the same expiry date. (default: `"false"`)
- `NO_REBOOT` The default is to reboot the IPMI after upload for the change to take effect (default: `"false"`)
- `DEBUG` Run with debug logging (default: `"false"`)
- `RUN_IMMEDIATELY` One initial update is run as soon as the container starts, before starting the CRON schedule.

```sh
  docker run -d -e IPMI_URL="https://ipmi.example.com" -e USERNAME="admin" -e PASSWORD="P@$$w0rd" -e KEY_FILE=/cert/key.pem -e CERT_FILE=/cert/cert.pem -v /local/path/to/certs/:/cert:ro ipmi-cert
```

### Docker compose example
Example running AWS route53 [DNS-01 challenge](https://doc.traefik.io/traefik/https/acme/#dnschallenge) on Traefik, extracting the certificate from Traefik's acme.json file and then updating IPMI using the extracted certificate.

```yaml
version: "3.8"

secrets:
  username:
    file: username.txt
  password:
    file: password.txt

services:

  traefik:
    container_name: traefik
    image: traefik:latest
    hostname: traefik
    restart: always
    networks:
      - traefik
    ports:
      - 80:80
      - 443:443
    environment:
      - AWS_ACCESS_KEY_ID=your_AWS_access_key_id
      - AWS_SECRET_ACCESS_KEY=your_AWS_secret_access_key
      - AWS_HOSTED_ZONE_ID=your_hosted_zone_id
      - AWS_REGION=your_aws_region
    command:
      ## API Settings
      - --api.insecure=false
      - --api.dashboard=true
      - --api.debug=true
      ## Entrypoints
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      # Docker Provider
      - --providers.docker=true
      - --providers.docker.network=traefik
      - --providers.docker.exposedByDefault=false
      - --providers.docker.defaultRule=Host(`{{ normalize .Name }}.example.com`)
      ## Letsencrypt certificate resolver
      - --certificatesresolvers.letsencrypt.acme.tlsChallenge=false
      - --certificatesresolvers.letsencrypt.acme.httpChallenge=false
      - --certificatesresolvers.letsencrypt.acme.httpChallenge.entryPoint=web
      - --certificatesresolvers.letsencrypt.acme.dnschallenge=true
      - --certificatesresolvers.letsencrypt.acme.dnschallenge.provider=route53
      - --certificatesresolvers.letsencrypt.acme.dnschallenge.delayBeforeCheck=0
      - --certificatesresolvers.letsencrypt.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53
      - --certificatesresolvers.letsencrypt.acme.email=admin@example.com
      - --certificatesresolvers.letsencrypt.acme.storage=/certificates/acme.json
    labels:
      traefik.enable: true
      traefik.http.routers.dashboard.rule: Host(`traefik.example.com`)
      traefik.http.routers.dashboard.service: api@internal
      traefik.http.routers.dashboard.entrypoints: websecure
      traefik.http.routers.dashboard.tls.certresolver: letsencrypt
      traefik.http.routers.dashboard.tls.domains[0].main: "example.com"
      traefik.http.routers.dashboard.tls.domains[0].sans: "*.example.com"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /home/admin/traefik/certificates:/certificates

  certificate-exporter:
    container_name: certificate-exporter
    image: rafi0101/traefik-ssl-certificate-exporter:latest
    environment:
      CRON_TIME: "0 6 * * *"
      CERT_OWNER_ID: "0"
      CERT_GROUP_ID: "1000"
    volumes:
      - /home/admin/traefik/certificates/acme.json:/app/traefik/acme.json:ro
      - /home/admin/certificates:/app/certs
    restart: unless-stopped

  ipmi-cert:
    container_name: ipmi-cert
    image: gnarr/ipmi-cert:latest
    secrets:
      - username
      - password
    environment:
      IPMI_URL: https://ipmi.example.com
      # username and password can be supplied as strings, but using secrets is recommended, as is done in this example.
      # USERNAME: admin
      # PASSWORD: P@$$w0rd
      USERNAME_FILE: /run/secrets/username
      PASSWORD_FILE: /run/secrets/password
      KEY_FILE: /cert/privkey.pem
      CERT_FILE: /cert/cert.pem
      CRON_STRING: "5 6 * * *"
    volumes:
      - /home/admin/certificates/_.example.com/:/cert:ro
    restart: unless-stopped
```


Built on work by [Jari Turkia](https://gist.github.com/HQJaTu/963db9af49d789d074ab63f52061a951),
[Devon Merner](https://gist.github.com/dmerner/26b61d5d7cd67753110eb63b83d67e90),
[Bernhard Frauendienst](https://github.com/oxc) &
[Bjarne Saltbaek](https://gist.github.com/arnebjarne/54dbab54e5fb82043a4835c0250840b4)