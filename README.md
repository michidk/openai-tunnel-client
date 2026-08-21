# openai-tunnel-client

Unofficial, reproducible container packaging for OpenAI's Secure MCP Tunnel client. The images contain unmodified binaries from the official `openai/tunnel-client` release, verified against pinned upstream SHA-256 checksums during the build.

This project is not an official OpenAI image and is not endorsed or supported by OpenAI.

## Images

| Image tag | Contents | Intended use |
| --- | --- | --- |
| `ghcr.io/michidk/openai-tunnel-client:<version>` | `tunnel-client`, bundled `cloudflared`, and CA certificates | HTTP MCP servers and deployments that provide their own profile |
| `ghcr.io/michidk/openai-tunnel-client:<version>-python3.12` | Runtime plus `uv` and Python 3.12 | Stdio MCP commands requiring Python 3.12 |
| `ghcr.io/michidk/openai-tunnel-client:<version>-python3.13` | Runtime plus `uv` and Python 3.13 | Stdio MCP commands requiring Python 3.13 |

Versioned tags mirror the upstream release. Floating `latest`, `python3.12`, and `python3.13` tags are published for discovery, but production deployments should use a versioned tag and immutable manifest digest.

All variants run as numeric user and group `65532`, set `HOME=/tmp`, and support read-only root filesystems when `/tmp` and any writable profile directory are mounted separately.

## Usage

```sh
docker run --rm ghcr.io/michidk/openai-tunnel-client:0.0.12 --version
```

Mount a profile and inject the runtime API key through the environment:

```sh
docker run --rm \
  -e CONTROL_PLANE_API_KEY \
  -v "$PWD/profiles:/profiles:ro" \
  ghcr.io/michidk/openai-tunnel-client:0.0.12 \
  run --profile example --profile-dir /profiles
```

See the official [Secure MCP Tunnel documentation](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels/) for supported configuration and deployment patterns.

## Deployment patterns

OpenAI documents two Kubernetes layouts. Choose based on how the MCP server is reached:

- **Dedicated deployment:** run the tunnel client separately when an HTTP MCP server is reachable through a private Kubernetes Service. This keeps tunnel lifecycle and credentials separate from the MCP server. The Helm chart in this repository targets this layout.
- **Sidecar or co-located container:** run the tunnel client in the MCP server's Pod and connect over `localhost`. Prefer this for stdio MCP servers because `tunnel-client` launches the configured command and therefore needs the command, runtime, and files in the same container or shared Pod.

The generic chart does not inject a sidecar and does not package an MCP server. Sidecar users should reference the appropriate image flavor directly in their workload manifest.

## Helm chart

The chart deploys a dedicated tunnel client for an existing HTTP MCP server. It expects a profile ConfigMap and an API-key Secret; it never creates or stores credentials.

```sh
helm upgrade --install example \
  oci://ghcr.io/michidk/charts/openai-tunnel-client \
  --version 0.1.0 \
  --set tunnel.profileName=example \
  --set tunnel.existingConfigMap=example-tunnel-profile \
  --set tunnel.apiKeySecret.name=example-tunnel-credentials
```

Production values should also set `image.digest` to the immutable manifest digest for the selected image tag. Chart releases use independent `chart-vX.Y.Z` tags; `appVersion` tracks the packaged upstream tunnel-client release.

## Updating upstream

The scheduled update workflow opens a pull request containing the new upstream version and both official Linux archive checksums. You can do the same locally:

```sh
scripts/update-version v0.0.12
just verify
```

After merging an update, push the matching `vX.Y.Z` tag. The release workflow builds AMD64 and ARM64 manifests, publishes all three flavors with BuildKit SBOM and provenance attestations, and creates a GitHub release.

Renovate maintains pinned base images and GitHub Actions. Upstream tunnel-client updates intentionally use the dedicated workflow because the version and two architecture-specific checksums must change atomically.

## Verification

```sh
just verify
just build runtime
```

CI additionally builds and smoke-tests every flavor. Trivy reports the complete image, including findings in the unmodified upstream binaries, and separately blocks fixed high or critical vulnerabilities in layers this repository controls.

## Licensing

The packaging code in this repository is MIT licensed. OpenAI's tunnel-client is Apache-2.0 licensed; each image includes the upstream `LICENSE`, `NOTICE`, license inventory, and SPDX SBOM from the corresponding release archive.
