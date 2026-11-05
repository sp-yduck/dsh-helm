# dsh chart values

The chart deploys the DeepSeek Harness Web UI. The [repository README](../../README.md) explains how to build the image, install the chart, and log in.

## Values

| Value | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/sp-yduck/dsh` | Image repository. |
| `image.tag` | `""` | Image tag. An empty value uses the chart version; every chart version publishes its own immutable image, which contains the dsh version in `appVersion`. |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy. |
| `imagePullSecrets` | `[]` | Pull secrets for a private registry. |
| `trustedHosts` | `[]` | Hosts that the dsh `/api` host check accepts, as `host` or `host:port`. A host without a port matches any port. The chart adds every `ingress.hosts[].host` when `ingress.enabled` is true. Each entry becomes a `--trusted-host` argument. |
| `publicUrl` | `""` | Root URL that dsh prints in the login URL, such as `https://dsh.example.com/`. Becomes `--public-url`. It changes only the printed URL and does not admit a host. |
| `extraArgs` | `[]` | More arguments for `dsh --profile web`. Run `dsh web --help` for the list. |
| `env` | `[]` | Extra container environment variables, in Kubernetes `env` format. |
| `envFrom` | `[]` | Extra environment sources, in Kubernetes `envFrom` format. Use it to pass API keys from a Secret. |
| `service.type` | `ClusterIP` | Service type. |
| `service.port` | `3080` | Service port. The container always listens on 3080. |
| `ingress.enabled` | `false` | Creates an Ingress for the Service. |
| `ingress.className` | `""` | `ingressClassName` of the Ingress. |
| `ingress.annotations` | `{}` | Ingress annotations. |
| `ingress.hosts` | `[{host: dsh.example.com}]` | Ingress hosts. Each entry routes `/` to the Service; leave `host` out for a rule without a host. |
| `ingress.tls` | `[]` | Ingress `tls` entries. |
| `tailscale.enabled` | `false` | Creates an Ingress for the Tailscale Kubernetes operator. |
| `tailscale.hostname` | `dsh` | MagicDNS name of the Tailscale proxy. |
| `tailscale.tailnet` | `""` | Tailnet DNS name, such as `tail1234.ts.net`. Required when enabled. The chart trusts `<hostname>.<tailnet>` and uses it for the login URL. |
| `tailscale.funnel` | `false` | Also publishes the UI to the internet with Tailscale Funnel. |
| `tailscale.proxyGroup` | `""` | Serves through an existing Tailscale ProxyGroup. |
| `tailscale.annotations` | `{}` | More annotations on the Tailscale Ingress. |
| `cloudflared.enabled` | `false` | Deploys cloudflared for a remotely-managed Cloudflare Tunnel. |
| `cloudflared.hostnames` | `[]` | Public hostnames routed to dsh. The chart trusts them and uses the first for the login URL. |
| `cloudflared.tunnelToken.existingSecret` | `""` | Secret holding the tunnel token. Required when enabled. |
| `cloudflared.tunnelToken.key` | `token` | Key of the token in the Secret. |
| `cloudflared.replicas` | `1` | cloudflared replicas. |
| `cloudflared.image.repository` / `tag` | `cloudflare/cloudflared` / pinned | cloudflared image. |
| `cloudflared.resources` | `{}` | cloudflared resource requests and limits. |
| `persistence.enabled` | `true` | Mounts a PersistentVolumeClaim at `/data`. When false, the chart mounts an `emptyDir`, and data is lost when the pod is replaced, for example by `helm upgrade`. |
| `persistence.size` | `10Gi` | Size of the claim that the chart creates. |
| `persistence.storageClass` | `""` | Storage class of the claim that the chart creates. An empty value uses the cluster default. |
| `persistence.existingClaim` | `""` | Name of a claim to mount instead of creating one. `helm uninstall` does not delete it. |
| `resources` | `{}` | Container resource requests and limits. |
| `podAnnotations` | `{}` | Extra annotations on the pod. |
| `podLabels` | `{}` | Extra labels on the pod. |
| `extraVolumes` | `[]` | Extra pod volumes, in Kubernetes `volumes` format. |
| `extraVolumeMounts` | `[]` | Extra mounts for the dsh container, in Kubernetes `volumeMounts` format. |
| `serviceAccount.create` | `true` | Creates a ServiceAccount for the pod. |
| `serviceAccount.name` | `""` | ServiceAccount name. Defaults to the release full name, or `default` when `create` is false. |
| `serviceAccount.annotations` | `{}` | ServiceAccount annotations, such as a cloud workload identity. |
| `serviceAccount.automountServiceAccountToken` | `false` | Mounts a Kubernetes API token into the pod. The agent can read anything the pod can, so leave this off unless the agent must call the API. |
| `podSecurityContext` | non-root UID/GID 1000, `fsGroup` 1000, `RuntimeDefault` seccomp | Pod security context. |
| `securityContext` | no privilege escalation, all capabilities dropped | Container security context. The root filesystem stays writable because the agent installs toolchains under `/usr/local`. |
| `runtimeClassName` | `""` | RuntimeClass, such as `gvisor` or `kata`, to run the agent in a sandboxed runtime. |
| `priorityClassName` | `""` | PriorityClass of the pod. |
| `networkPolicy.enabled` | `true` | Creates a NetworkPolicy. It has no effect when the CNI does not enforce NetworkPolicy. |
| `networkPolicy.ingressFrom` | `[]` | Peers that may reach port 3080, in NetworkPolicy `from` format. Empty allows any source, so Ingress controllers, Tailscale proxies, and cloudflared work without changes. |
| `networkPolicy.egress.blockPrivateNetworks` | `true` | Allows egress to the internet and DNS only. Blocks private, CGNAT, link-local (cloud metadata), and loopback ranges, which include the cluster network and the Kubernetes API. |
| `networkPolicy.egress.privateIPv4` / `privateIPv6` | RFC 1918, `100.64.0.0/10`, `169.254.0.0/16`, ULA, link-local | Ranges that `blockPrivateNetworks` excludes. |
| `networkPolicy.egress.extra` | `[]` | More egress rules, such as an in-cluster model gateway. |
| `nodeSelector` | `{}` | Pod node selector. |
| `tolerations` | `[]` | Pod tolerations. |
| `affinity` | `{}` | Pod affinity. |

## Validation

`values.schema.json` validates the values on `helm install`, `helm upgrade`, `helm template`, and `helm lint`. A misspelled or unknown top-level key, such as `ingres`, fails instead of being ignored.

## Fixed settings

The chart sets these values and does not expose them:

- One replica with the `Recreate` update strategy.
- `DSH_HOST` set to the pod IP. The image serves dsh on `127.0.0.1` and relays the pod IP to it, because dsh rejects wildcard bind addresses. `kubectl port-forward` reaches dsh directly on loopback.
- `DSH_PORT` set to `3080`.
- `fsGroup: 1000`, so the `node` user in the image can write to the volume.
- `fsGroupChangePolicy: OnRootMismatch`. dsh exits when `.credentials.yaml` is readable by its group, and a recursive `fsGroup` change on each mount would make it so.
- TCP readiness and liveness probes on port 3080. The liveness probe starts after 30 seconds.

## Volume layout

| Path | Content |
| --- | --- |
| `/data/.dsh` | `DSH_HOME`. Settings, profiles, sessions, and `.credentials.yaml`. |
| `/data/workspace` | Working directory of the dsh process. |
