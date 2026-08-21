set shell := ["bash", "-euo", "pipefail", "-c"]

default:
  @just --list

verify:
  python3 -m compileall -q scripts/fetch-release.py
  shellcheck -x scripts/verify-release-metadata scripts/update-version
  scripts/verify-release-metadata
  helm lint charts/openai-tunnel-client --values charts/openai-tunnel-client/ci/test-values.yaml
  helm template test charts/openai-tunnel-client --values charts/openai-tunnel-client/ci/test-values.yaml >/dev/null

update version="":
  scripts/update-version {{version}}

build target="runtime":
  source versions.env; docker build --target {{target}} \
    --build-arg TUNNEL_CLIENT_VERSION="$TUNNEL_CLIENT_VERSION" \
    --build-arg TUNNEL_CLIENT_SHA256_AMD64="$TUNNEL_CLIENT_SHA256_AMD64" \
    --build-arg TUNNEL_CLIENT_SHA256_ARM64="$TUNNEL_CLIENT_SHA256_ARM64" \
    -t tunnel-client:{{target}} .
