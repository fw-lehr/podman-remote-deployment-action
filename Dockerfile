FROM debian:13-slim

RUN apt-get update && \
    apt-get install -y openssh-client && \
    apt-get install -y podman && \
    apt-get install -y podman-compose && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY podman-entrypoint.sh /podman-entrypoint.sh

ENTRYPOINT ["/podman-entrypoint.sh"]
