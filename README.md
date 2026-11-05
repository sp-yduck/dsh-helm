# dsh-helm

[![CI](https://github.com/sp-yduck/dsh-helm/actions/workflows/image.yaml/badge.svg?branch=main)](https://github.com/sp-yduck/dsh-helm/actions/workflows/image.yaml)
[![Chart](https://img.shields.io/badge/chart-oci%3A%2F%2Fghcr.io%2Fsp--yduck%2Fcharts%2Fdsh-0f1689?logo=helm)](https://github.com/sp-yduck/dsh-helm/pkgs/container/charts%2Fdsh)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Image](https://img.shields.io/badge/image-ghcr.io%2Fsp--yduck%2Fdsh-2496ed?logo=docker&logoColor=white)](https://github.com/sp-yduck/dsh-helm/pkgs/container/dsh)

Run the [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`) coding agent as an **always-on workspace in your Kubernetes cluster**: install it with one `helm install`, try it with `kubectl port-forward`, and reach it from any device through your Ingress with TLS. Your sessions, API keys, and cloned repositories stay on a PersistentVolume.

- **Ready-made multi-arch image** (`linux/amd64`, `linux/arm64`) with `git`, `gh`, Python/`uv`, Go, Rust, Node/pnpm, `ripgrep`, and `jq`, so the agent can build and test real projects.
- **Persistent workspace**: settings, sessions, API keys, and cloned repositories live on a PersistentVolume and survive restarts and upgrades.
- **`kubectl port-forward` and Ingress both work.** dsh runs on loopback behind a byte-level relay, so its token, cookie, and Host checks stay in force (tested in CI).
- **Published chart**: install from `oci://ghcr.io/sp-yduck/charts/dsh` or `helm repo add`; every version has a GitHub Release.
- **Ingress and TLS** support, with the Ingress hosts added to the hosts that dsh trusts.
- **Validated values**: a JSON schema catches typos such as `ingres:` before anything is deployed.

**Use dsh-helm when** you want dsh on a server instead of your laptop: one instance per developer in a shared cluster, a homelab or tailnet you open from your phone, or a GitOps-managed setup with Argo CD or Flux. **Use a Docker Compose setup instead** for a single machine where dsh only needs to reach local files.

> [!WARNING]
> dsh runs shell commands inside the pod, and anyone who can log in to the UI can use it. Read the upstream [safety notice](https://github.com/deepseek-ai/deepseek-harness/blob/master/SAFETY.md) and [SECURITY.md](SECURITY.md) before you expose it.

## Quick start

```sh
helm install dsh oci://ghcr.io/sp-yduck/charts/dsh
kubectl port-forward deploy/dsh 3080:3080 &
kubectl logs deploy/dsh -f | grep -m1 token=
```

Open the printed `http://127.0.0.1:3080/?token=...` URL, then add a model API key under **Settings → Models**. To use the UI from other machines, put it behind an Ingress with TLS (see [Install the chart](#install-the-chart)).

If your tooling does not support OCI charts, use the classic Helm repository instead:

```sh
helm repo add dsh https://sp-yduck.github.io/dsh-helm
helm install dsh dsh/dsh
```

To pin a version, add `--version <chart version>`. The [packages page](https://github.com/sp-yduck/dsh-helm/pkgs/container/charts%2Fdsh) lists the published versions.

## Requirements

- Kubernetes 1.23 or later and Helm 3.8 or later (for OCI charts).
- A default StorageClass, or `persistence.storageClass`, for the 10 GiB volume.
- An Ingress controller with TLS, if browsers outside the cluster network open the UI.
- To build your own image: Docker or another tool that builds a `Dockerfile`, and a registry that your cluster can pull from.

## Try the image locally

To run the UI on your machine without Kubernetes, run:

```sh
docker run --rm -p 3080:3080 ghcr.io/sp-yduck/dsh:latest
```

Within about 30 seconds, the log prints a line like this:

```text
dsh web: http://127.0.0.1:3080/?token=6lcl9cb0hW6MX680ToAWcBiTYY7JoU1zPVe9Et1qs3g
```

Open that URL as printed. Docker forwards port 3080 to the container, and the relay passes it to dsh.

The container keeps its data only until you remove it. To keep the data, mount a named volume at `/data`:

```sh
docker run --rm -p 3080:3080 -v dsh-data:/data ghcr.io/sp-yduck/dsh:latest
```

## Install the chart

The Ingress in this example serves TLS from the Secret `dsh-tls`. To create that Secret from a certificate and key that you have, run:

```sh
kubectl create secret tls dsh-tls --cert=<cert.pem> --key=<key.pem>
```

If cert-manager issues your certificates, add its annotation to `ingress.annotations` instead. cert-manager then creates the Secret.

To install the chart behind an Ingress, run:

```sh
helm install dsh oci://ghcr.io/sp-yduck/charts/dsh \
	--set ingress.enabled=true \
	--set ingress.className=nginx \
	--set 'ingress.hosts[0].host=dsh.example.com' \
	--set 'ingress.tls[0].hosts[0]=dsh.example.com' \
	--set 'ingress.tls[0].secretName=dsh-tls' \
	--set publicUrl=https://dsh.example.com/
```

The chart adds each Ingress host to the hosts that dsh accepts, so you do not list it again in `trustedHosts`. The [values reference](helm/dsh/README.md) lists every value.

For a longer setup, put the values in a file and pass it with `-f`:

```yaml
publicUrl: https://dsh.example.com/
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: dsh.example.com
  tls:
    - hosts: [dsh.example.com]
      secretName: dsh-tls
```

```sh
helm install dsh oci://ghcr.io/sp-yduck/charts/dsh -f my-values.yaml
```

## Choose an access path

dsh needs HTTPS, or `localhost`, in the browser, and it must trust the `Host` header that the browser sends. The chart sets both for each path below.

| Path | Reach | Values |
| --- | --- | --- |
| `kubectl port-forward` | Your machine | None |
| [Tailscale](https://tailscale.com/kb/1236/kubernetes-operator) operator | Devices in your tailnet (optionally the internet with Funnel) | `tailscale.enabled`, `tailscale.tailnet` |
| [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | The internet, behind Cloudflare Access | `cloudflared.enabled`, `cloudflared.hostnames`, `cloudflared.tunnelToken.existingSecret` |
| Ingress controller (ingress-nginx, Traefik, …) with TLS | Your network or the internet | `ingress.*` |

### Tailscale

Install the [Tailscale Kubernetes operator](https://tailscale.com/kb/1236/kubernetes-operator), then:

```sh
helm install dsh oci://ghcr.io/sp-yduck/charts/dsh \
  --set tailscale.enabled=true --set tailscale.tailnet=tail1234.ts.net
```

dsh opens at `https://dsh.tail1234.ts.net/` from devices in your tailnet. `tailscale.tailnet` is your tailnet DNS name from the admin console; the chart uses it to trust the host and to print the right login URL. Set `tailscale.hostname` to change `dsh`, `tailscale.proxyGroup` to use a ProxyGroup, or `tailscale.funnel=true` to publish it to the internet (dsh still asks for its login token).

### Cloudflare Tunnel

Create a remotely-managed tunnel in the Cloudflare dashboard, store its token, and install:

```sh
kubectl create secret generic dsh-tunnel --from-literal=token=<tunnel token>
helm install dsh oci://ghcr.io/sp-yduck/charts/dsh \
  --set cloudflared.enabled=true \
  --set 'cloudflared.hostnames[0]=dsh.example.com' \
  --set cloudflared.tunnelToken.existingSecret=dsh-tunnel
```

In the tunnel's public hostname settings, route `dsh.example.com` to `http://dsh.<namespace>.svc:3080`. Put a [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/policies/access/) policy in front of it so that only you reach the login page.

### Ingress controller

See [Install the chart](#install-the-chart). Leave `host` out of an `ingress.hosts` entry when the controller does not route by host, and list the name that browsers use in `trustedHosts`.

### Paths that do not work

- **Plain HTTP on a non-local address**, such as a `NodePort`, a `LoadBalancer` Service, or a Tailscale `LoadBalancer` without HTTPS. Browsers do not treat these as secure contexts, and anyone on the path can read the login token. Use one of the HTTPS paths above.

## Log in

dsh prints a login URL with a new token each time it starts. To get the URL, run:

```sh
kubectl logs deploy/dsh | grep token=
```

Open the URL in a browser. dsh exchanges the token for a signed session cookie and removes the token from the address bar. If `publicUrl` is empty, the URL shows `127.0.0.1:3080`, which works as is through `kubectl port-forward deploy/dsh 3080:3080`. Through an Ingress, replace the address with your Ingress host, or set `publicUrl`.

The URL is a credential. Share it only with people who may use the agent.

## Add a model API key

You can give dsh an API key in one of two ways:

- In the UI, open **Settings → Models**, enter the key, and save. dsh stores the key in `/data/.dsh/.credentials.yaml` on the persistent volume.
- Put the key in a Kubernetes Secret and pass it as an environment variable. dsh uses the environment variable only when no key is saved in the UI.

To pass a DeepSeek key from a Secret, run:

```sh
kubectl create secret generic dsh-llm-keys --from-literal=DEEPSEEK_API_KEY=<key>
helm upgrade dsh oci://ghcr.io/sp-yduck/charts/dsh --reuse-values --set 'envFrom[0].secretRef.name=dsh-llm-keys'
```

Upstream [Configure models](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/providers.md) explains third-party providers and custom gateways.

## Upgrade and uninstall

To move to the latest chart and the dsh version it ships, run:

```sh
helm upgrade dsh oci://ghcr.io/sp-yduck/charts/dsh --reuse-values
```

To run another dsh version, build and push an image as described in [Build your own image](#build-your-own-image), then pass `--set image.repository=<registry>/dsh --set image.tag=<version>`.

The Deployment uses the `Recreate` strategy. The old pod stops before the new pod starts, so the UI is down for the length of one startup.

To remove the release, run:

```sh
helm uninstall dsh
```

Helm deletes the PersistentVolumeClaim that the chart created, and with it all settings, keys, and sessions. To keep the data, create a claim yourself and set `persistence.existingClaim` before you install.

## Security defaults

The chart assumes that whoever logs in can run any command in the pod, and limits what that command can reach:

- **No Kubernetes API token.** The pod uses its own ServiceAccount with `automountServiceAccountToken: false`.
- **Non-root, no capabilities.** dsh runs as UID 1000 with all capabilities dropped, no privilege escalation, and the `RuntimeDefault` seccomp profile. The only root step is an init container that may `chown` the workspace directory.
- **NetworkPolicy.** Only port 3080 accepts traffic. Egress reaches DNS and the internet, but not other pods, node addresses, or cloud metadata endpoints. Add exceptions in `networkPolicy.egress.extra`. Some CNIs (kindnet in CI is one) do not police traffic from a pod to the API server on its own node, so the missing token, not the NetworkPolicy, is what keeps the agent out of the Kubernetes API.
- **Sandboxed runtimes.** Set `runtimeClassName` to run the pod under gVisor or Kata Containers.

CI installs the chart in a kind cluster on every pull request and checks each of these, including that dsh's own Landlock sandbox still enforces under the seccomp profile.

## Know the limits

dsh does not accept a wildcard bind address such as `0.0.0.0`. The image therefore starts dsh on `127.0.0.1:3080`, which `kubectl port-forward` reaches, and a small TCP relay ([`scripts/dsh-relay.mjs`](scripts/dsh-relay.mjs)) publishes it on the pod IP for the Service and the Ingress. The relay copies bytes and does not parse HTTP, so dsh still checks the launch token, the session cookie, and the `Host` and `Origin` headers on every request.

dsh rejects an `/api` request with 403 when the `Host` header is not loopback or a host in `trustedHosts` or `ingress.hosts`. If you open the UI by any other name, such as a Service DNS name or a NodePort address, add that name to `trustedHosts`.

The pod serves plain HTTP. Terminate TLS at the Ingress, and allow traffic to port 3080 only from the Ingress controller or another network that you trust.

The chart runs one replica. dsh keeps its state in local files, and the volume uses `ReadWriteOnce`, so a second replica cannot share it.

The health probes only open a TCP connection to port 3080, because the root page returns 401 without a token or a session cookie.

## Build your own image

The chart uses `ghcr.io/sp-yduck/dsh` by default. Build your own image only to change the tools or the dsh version.


To build the image, run this command from the repository root:

```sh
docker build -t <registry>/dsh:dev .
docker push <registry>/dsh:dev
```

The `DSH_VERSION` build argument selects the dsh npm version; it defaults to the chart's `appVersion`. Pass your image to the chart with `--set image.repository=<registry>/dsh --set image.tag=dev`.

## Versions and releases

The chart and the image share one version number:

- `version` in `helm/dsh/Chart.yaml` is the release version. Each release publishes the image `ghcr.io/sp-yduck/dsh:<version>` and the chart `oci://ghcr.io/sp-yduck/charts/dsh:<version>`, and the chart uses that image tag by default. Published tags are never overwritten.
- `appVersion` is the dsh npm version inside the image.
- `latest` points to the newest image, for `docker run` only.

[Renovate](https://docs.renovatebot.com/) keeps dsh (npm `next` tag), Node 24, Go, Rust, uv, cloudflared, and the CI tools up to date. An update that changes the image or the chart also raises the patch version, so merging it publishes a new image, chart, and GitHub Release.

CI on `main` (`.github/workflows/image.yaml`) builds the multi-arch image, then pushes the chart to `oci://ghcr.io/<owner>/charts/dsh` and the GitHub Pages repository. Each new chart version also gets a GitHub Release, tagged `dsh-<version>`, with generated release notes and the packaged chart attached. To install from GHCR, run:

```sh
helm install dsh oci://ghcr.io/<owner>/charts/dsh --version <version>
```

## Files

- `Dockerfile` builds the image from `node:24-bookworm-slim` and runs as the `node` user (UID 1000) with `HOME=/data`. For coding tasks it adds `git`, `gh`, `ripgrep`, `fd`, `jq`, `curl`, `build-essential`, Python 3 with `uv`, Go, Rust (with `clippy` and `rustfmt`), and pnpm/yarn through corepack. The `GO_VERSION` and `RUST_VERSION` build arguments set those versions. The image is about 3.4 GB.
- `helm/dsh/` is the chart. It creates a Deployment, a Service, a PersistentVolumeClaim, and an optional Ingress. An init container gives `/data/workspace` to the `node` user, because storage that ignores `fsGroup` would otherwise leave it owned by root.

## License

[MIT](LICENSE). dsh itself is developed upstream by DeepSeek under its own license.
