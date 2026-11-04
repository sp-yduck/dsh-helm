# dsh-helm

This repository builds a container image for the [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`) Web UI and deploys it to Kubernetes with Helm.

The image installs the published npm package `@deepseek-ai/dsh` and runs `dsh --profile web`. The chart runs one replica, keeps settings, sessions, and the workspace on a persistent volume, and can expose the UI through an Ingress.

Read the upstream [safety notice](https://github.com/deepseek-ai/deepseek-harness/blob/master/SAFETY.md) before you deploy. The agent runs shell commands inside the pod, and anyone who logs in to the UI can use it.

## Requirements

- Docker, or another tool that builds images from a `Dockerfile`.
- A container registry that your cluster can pull from.
- Kubernetes and Helm 3.
- An Ingress controller with TLS, if browsers outside the cluster network open the UI.

## Build the image

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

The same workflow lints and packages the chart, and on each push to `main` pushes it to `oci://ghcr.io/<owner>/charts/dsh`, tagged with the chart's `version`. Bump `version` when you change the chart, because pushing the same version overwrites it. To install from GHCR, run:

```sh
helm install dsh oci://ghcr.io/<owner>/charts/dsh --version <version>
```

## Try the image locally

To run the UI on your machine without Kubernetes, run:

```sh
docker run --rm -p 3080:3080 <registry>/dsh:0.2.1-rc.5
```

Within about 30 seconds, the log prints a line like this:

```text
dsh web: http://172.17.0.2:3080/?token=6lcl9cb0hW6MX680ToAWcBiTYY7JoU1zPVe9Et1qs3g
```

Replace the container address with `localhost` and open `http://localhost:3080/?token=<token>`.

The container keeps its data only until you remove it. To keep the data, mount a named volume at `/data`:

```sh
docker run --rm -p 3080:3080 -v dsh-data:/data <registry>/dsh:0.2.1-rc.5
```

## Install the chart

The Ingress in this example serves TLS from the Secret `dsh-tls`. To create that Secret from a certificate and key that you have, run:

```sh
kubectl create secret tls dsh-tls --cert=<cert.pem> --key=<key.pem>
```

If cert-manager issues your certificates, add its annotation to `ingress.annotations` instead. cert-manager then creates the Secret.

To install the chart behind an Ingress, run:

```sh
helm install dsh helm/dsh \
	--set image.repository=<registry>/dsh \
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
image:
  repository: <registry>/dsh
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
helm install dsh helm/dsh -f my-values.yaml
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
helm upgrade dsh helm/dsh --reuse-values --set 'envFrom[0].secretRef.name=dsh-llm-keys'
```

Upstream [Configure models](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/providers.md) explains third-party providers and custom gateways.

## Upgrade and uninstall

To change the dsh version, build and push a new image, then run:

```sh
helm upgrade dsh helm/dsh --reuse-values --set image.tag=<version>
```

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

## Files

- `Dockerfile` builds the image from `node:24-bookworm-slim`. It adds `git`, `ca-certificates`, and `tini`, and runs as the `node` user (UID 1000) with `HOME=/data`.
- `helm/dsh/` is the chart. It creates a Deployment, a Service, a PersistentVolumeClaim, and an optional Ingress.
