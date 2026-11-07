FROM alpine:3.22
LABEL org.opencontainers.image.source="https://github.com/axordotnet/wireguard-docker-alpine" \
      org.opencontainers.image.description="WireGuard tools and userspace fallback on Alpine Linux"
RUN apk add --no-cache wireguard-go wireguard-tools iproute2 bash iptables
COPY entrypoint.sh /usr/local/bin/wireguard-entrypoint
RUN chmod 755 /usr/local/bin/wireguard-entrypoint
ENTRYPOINT ["/usr/local/bin/wireguard-entrypoint"]
