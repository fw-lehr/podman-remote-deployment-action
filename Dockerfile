FROM mgoltzsche/podman:latest

RUN apk --no-cache add openssh-client

COPY podman-entrypoint.sh /podman-entrypoint.sh

ENTRYPOINT ["/podman-entrypoint.sh"]
