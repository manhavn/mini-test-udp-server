# Containerfile
# Light runtime image that copies pre-built static binaries from the host
# Compatible with linux/amd64 and linux/arm64 without emulation requirements

FROM docker.io/library/alpine:latest

# TARGETARCH is automatically set by podman build --platform (amd64, arm64, etc.)
ARG TARGETARCH

# Metadata
LABEL org.opencontainers.image.source="https://github.com/user/mini-test-udp-server"
LABEL org.opencontainers.image.description="Mini Test UDP Server running on Alpine Musl"
LABEL org.opencontainers.image.licenses="MIT"

WORKDIR /app

# Copy the statically linked binary compiled by cargo-zigbuild on host
COPY target/bin/${TARGETARCH}/mini-test-udp-server /usr/local/bin/mini-test-udp-server

# Expose UDP port
EXPOSE 9999/udp

# Set execution command
ENTRYPOINT ["/usr/local/bin/mini-test-udp-server"]
CMD ["-p", "9999"]
