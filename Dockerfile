FROM alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
LABEL org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/axordotnet/wireguard-docker-alpine" \
      org.opencontainers.image.description="WireGuard tools and userspace fallback on Alpine Linux"
RUN apk upgrade --no-cache && apk add --no-cache wireguard-go wireguard-tools iproute2 bash iptables
COPY entrypoint.sh /usr/local/bin/wireguard-entrypoint
RUN chmod 755 /usr/local/bin/wireguard-entrypoint
ENTRYPOINT ["/usr/local/bin/wireguard-entrypoint"]
