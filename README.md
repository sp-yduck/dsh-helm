# dsh-helm

[![CI](https://github.com/sp-yduck/dsh-helm/actions/workflows/image.yaml/badge.svg?branch=main)](https://github.com/sp-yduck/dsh-helm/actions/workflows/image.yaml)
[![Chart](https://img.shields.io/badge/chart-oci%3A%2F%2Fghcr.io%2Fsp--yduck%2Fcharts%2Fdsh-0f1689?logo=helm)](https://github.com/sp-yduck/dsh-helm/pkgs/container/charts%2Fdsh)
[![Image](https://img.shields.io/badge/image-ghcr.io%2Fsp--yduck%2Fdsh-2496ed?logo=docker&logoColor=white)](https://github.com/sp-yduck/dsh-helm/pkgs/container/dsh)

Run the [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`) coding-agent Web UI on Kubernetes with one `helm install`.

- **Ready-made multi-arch image** (`linux/amd64`, `linux/arm64`) with `git`, `gh`, Python/`uv`, Go, Rust, Node/pnpm, `ripgrep`, and `jq`, so the agent can build and test real projects.
- **Persistent workspace**: settings, sessions, API keys, and cloned repositories live on a PersistentVolume and survive restarts and upgrades.
- **Ingress and TLS** support, with the Ingress hosts added to the hosts that dsh trusts.
- **Validated values**: a JSON schema catches typos such as `ingres:` before anything is deployed.

> [!WARNING]
> dsh runs shell commands inside the pod, and anyone who can log in to the UI can use it. Read the upstream [safety notice](https://github.com/deepseek-ai/deepseek-harness/blob/master/SAFETY.md) and [SECURITY.md](SECURITY.md) before you expose it.

## Quick start

```sh
helm install dsh oci://ghcr.io/sp-yduck/charts/dsh
kubectl logs deploy/dsh -f | grep -m1 token=
```

The log prints a login URL with the pod IP. dsh listens only on the pod IP, so `kubectl port-forward` does not work; open the UI through an Ingress (see [Install the chart](#install-the-chart)) or from inside the cluster network. Then add a model API key under **Settings → Models**.

To pin a version, add `--version <chart version>`. The [packages page](https://github.com/sp-yduck/dsh-helm/pkgs/container/charts%2Fdsh) lists the published versions.

## Requirements

- Kubernetes 1.23 or later and Helm 3.8 or later (for OCI charts).
- A default StorageClass, or `persistence.storageClass`, for the 10 GiB volume.
- An Ingress controller with TLS, if browsers outside the cluster network open the UI.
- To build your own image: Docker or another tool that builds a `Dockerfile`, and a registry that your cluster can pull from.

## Try the image locally

To run the UI on your machine without Kubernetes, run:

```sh
docker run --rm -p 3080:3080 ghcr.io/sp-yduck/dsh:0.2.1-rc.5
```

Within about 30 seconds, the log prints a line like this:

```text
dsh web: http://172.17.0.2:3080/?token=6lcl9cb0hW6MX680ToAWcBiTYY7JoU1zPVe9Et1qs3g
```

Replace the container address with `localhost` and open `http://localhost:3080/?token=<token>`.

The container keeps its data only until you remove it. To keep the data, mount a named volume at `/data`:

```sh
docker run --rm -p 3080:3080 -v dsh-data:/data ghcr.io/sp-yduck/dsh:0.2.1-rc.5
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

## Log in

dsh prints a login URL with a new token each time it starts. To get the URL, run:

```sh
kubectl logs deploy/dsh | grep token=
```

Open the URL in a browser. dsh exchanges the token for a signed session cookie and removes the token from the address bar. If `publicUrl` is empty, the URL shows the pod IP. In that case, replace the address with the one that your browser uses.

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

## Know the limits

dsh does not accept a wildcard bind address such as `0.0.0.0`. The chart therefore starts dsh on the pod IP. This choice has two effects:

- `kubectl port-forward` does not reach the UI. Port forwarding connects to the pod's loopback address, and dsh does not listen there. Use the Service or the Ingress.
- dsh rejects an `/api` request with 403 when the `Host` header is not loopback, the pod IP, or a host in `trustedHosts` or `ingress.hosts`. If you open the UI by any other name, such as a Service DNS name or a NodePort address, add that name to `trustedHosts`.

The pod serves plain HTTP. Terminate TLS at the Ingress, and allow traffic to port 3080 only from the Ingress controller or another network that you trust.

The chart runs one replica. dsh keeps its state in local files, and the volume uses `ReadWriteOnce`, so a second replica cannot share it.

The health probes only open a TCP connection to port 3080, because the root page returns 401 without a token or a session cookie.

## Build your own image

The chart uses `ghcr.io/sp-yduck/dsh` by default. Build your own image only to change the tools or the dsh version.


To build the image, run this command from the repository root:

```sh
docker build -t <registry>/dsh:0.2.1-rc.5 .
docker push <registry>/dsh:0.2.1-rc.5
```

The `DSH_VERSION` build argument selects the npm version. The default is `0.2.1-rc.5`, which is also the chart's `appVersion`. If you build another version, pass the same version to the chart as `image.tag`:

```sh
docker build --build-arg DSH_VERSION=0.2.2-rc.1 -t <registry>/dsh:0.2.2-rc.1 .
```

GitHub Actions (`.github/workflows/image.yaml`) builds the image on every pull request and, on each push to `main`, pushes `ghcr.io/<owner>/dsh:<appVersion>` and `ghcr.io/<owner>/dsh:latest`. The workflow passes the chart's `appVersion` as `DSH_VERSION`, so to release a new dsh version, change `appVersion` in `helm/dsh/Chart.yaml`.

The same workflow lints and packages the chart, and on each push to `main` pushes it to `oci://ghcr.io/<owner>/charts/dsh`, tagged with the chart's `version`. Bump `version` when you change the chart, because pushing the same version overwrites it. Each new chart version also gets a GitHub Release, tagged `dsh-<version>`, with generated release notes and the packaged chart attached. To install from GHCR, run:

```sh
helm install dsh oci://ghcr.io/<owner>/charts/dsh --version <version>
```

## Files

- `Dockerfile` builds the image from `node:24-bookworm-slim` and runs as the `node` user (UID 1000) with `HOME=/data`. For coding tasks it adds `git`, `gh`, `ripgrep`, `fd`, `jq`, `curl`, `build-essential`, Python 3 with `uv`, Go, Rust (with `clippy` and `rustfmt`), and pnpm/yarn through corepack. The `GO_VERSION` and `RUST_VERSION` build arguments set those versions. The image is about 3.4 GB.
- `helm/dsh/` is the chart. It creates a Deployment, a Service, a PersistentVolumeClaim, and an optional Ingress. An init container gives `/data/workspace` to the `node` user, because storage that ignores `fsGroup` would otherwise leave it owned by root.
