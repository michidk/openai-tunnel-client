# syntax=docker/dockerfile:1.26

ARG UV_PYTHON312_IMAGE=ghcr.io/astral-sh/uv:python3.12-bookworm-slim@sha256:e5b65587bce7de595f299855d7385fe7fca39b8a74baa261ba1b7147afa78e58
ARG UV_PYTHON313_IMAGE=ghcr.io/astral-sh/uv:python3.13-bookworm-slim@sha256:531f855bda2c73cd6ef67d56b733b357cea384185b3022bd09f05e002cd144ca

FROM --platform=$BUILDPLATFORM ${UV_PYTHON312_IMAGE} AS fetch
ARG TARGETARCH
ARG TUNNEL_CLIENT_VERSION
ARG TUNNEL_CLIENT_SHA256_AMD64
ARG TUNNEL_CLIENT_SHA256_ARM64
COPY scripts/fetch-release.py /usr/local/src/fetch-release.py
RUN python3 /usr/local/src/fetch-release.py \
      --version "${TUNNEL_CLIENT_VERSION}" \
      --arch "${TARGETARCH}" \
      --sha256-amd64 "${TUNNEL_CLIENT_SHA256_AMD64}" \
      --sha256-arm64 "${TUNNEL_CLIENT_SHA256_ARM64}" \
      --output /out

FROM scratch AS runtime
ARG TUNNEL_CLIENT_VERSION
LABEL org.opencontainers.image.title="OpenAI tunnel-client container" \
      org.opencontainers.image.description="Unofficial container packaging for OpenAI Secure MCP Tunnel" \
      org.opencontainers.image.source="https://github.com/michidk/tunnel-client-container" \
      org.opencontainers.image.url="https://github.com/michidk/tunnel-client-container" \
      org.opencontainers.image.documentation="https://developers.openai.com/api/docs/guides/secure-mcp-tunnels/" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${TUNNEL_CLIENT_VERSION}"
COPY --from=fetch /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=fetch /out/tunnel-client /usr/local/bin/tunnel-client
COPY --from=fetch /out/cloudflared /usr/local/bin/cloudflared
COPY --from=fetch /out/compliance/ /usr/share/licenses/tunnel-client/
ENV HOME=/tmp \
    PATH=/usr/local/bin \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/tunnel-client"]

FROM ${UV_PYTHON312_IMAGE} AS python312
ARG TUNNEL_CLIENT_VERSION
LABEL org.opencontainers.image.title="OpenAI tunnel-client container with uv and Python 3.12" \
      org.opencontainers.image.description="Unofficial container packaging for OpenAI Secure MCP Tunnel" \
      org.opencontainers.image.source="https://github.com/michidk/tunnel-client-container" \
      org.opencontainers.image.url="https://github.com/michidk/tunnel-client-container" \
      org.opencontainers.image.documentation="https://developers.openai.com/api/docs/guides/secure-mcp-tunnels/" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${TUNNEL_CLIENT_VERSION}"
COPY --from=fetch /out/tunnel-client /usr/local/bin/tunnel-client
COPY --from=fetch /out/cloudflared /usr/local/bin/cloudflared
COPY --from=fetch /out/compliance/ /usr/share/licenses/tunnel-client/
ENV HOME=/tmp \
    UV_CACHE_DIR=/tmp/uv-cache
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/tunnel-client"]

FROM ${UV_PYTHON313_IMAGE} AS python313
ARG TUNNEL_CLIENT_VERSION
LABEL org.opencontainers.image.title="OpenAI tunnel-client container with uv and Python 3.13" \
      org.opencontainers.image.description="Unofficial container packaging for OpenAI Secure MCP Tunnel" \
      org.opencontainers.image.source="https://github.com/michidk/tunnel-client-container" \
      org.opencontainers.image.url="https://github.com/michidk/tunnel-client-container" \
      org.opencontainers.image.documentation="https://developers.openai.com/api/docs/guides/secure-mcp-tunnels/" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${TUNNEL_CLIENT_VERSION}"
COPY --from=fetch /out/tunnel-client /usr/local/bin/tunnel-client
COPY --from=fetch /out/cloudflared /usr/local/bin/cloudflared
COPY --from=fetch /out/compliance/ /usr/share/licenses/tunnel-client/
ENV HOME=/tmp \
    UV_CACHE_DIR=/tmp/uv-cache
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/tunnel-client"]

