# dsh chart values

The chart deploys the DeepSeek Harness Web UI. The [repository README](../../README.md) explains how to build the image, install the chart, and log in.

## Values

| Value | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/sp-yduck/dsh` | Image repository. |
| `image.tag` | `""` | Image tag. An empty value uses the chart `appVersion`, `0.2.1-rc.5`. |
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
| `ingress.hosts` | `[{host: dsh.example.com}]` | Ingress hosts. Each host routes `/` to the Service. |
| `ingress.tls` | `[]` | Ingress `tls` entries. |
| `persistence.enabled` | `true` | Mounts a PersistentVolumeClaim at `/data`. When false, the chart mounts an `emptyDir`, and data is lost when the pod is replaced, for example by `helm upgrade`. |
| `persistence.size` | `10Gi` | Size of the claim that the chart creates. |
| `persistence.storageClass` | `""` | Storage class of the claim that the chart creates. An empty value uses the cluster default. |
| `persistence.existingClaim` | `""` | Name of a claim to mount instead of creating one. `helm uninstall` does not delete it. |
| `resources` | `{}` | Container resource requests and limits. |
| `podAnnotations` | `{}` | Extra annotations on the pod. |
| `podLabels` | `{}` | Extra labels on the pod. |
| `extraVolumes` | `[]` | Extra pod volumes, in Kubernetes `volumes` format. |
| `extraVolumeMounts` | `[]` | Extra mounts for the dsh container, in Kubernetes `volumeMounts` format. |
| `nodeSelector` | `{}` | Pod node selector. |
| `tolerations` | `[]` | Pod tolerations. |
| `affinity` | `{}` | Pod affinity. |

## Validation

`values.schema.json` validates the values on `helm install`, `helm upgrade`, `helm template`, and `helm lint`. A misspelled or unknown top-level key, such as `ingres`, fails instead of being ignored.

## Fixed settings

The chart sets these values and does not expose them:

- One replica with the `Recreate` update strategy.
- `DSH_HOST` set to the pod IP, because dsh rejects wildcard bind addresses.
- `DSH_PORT` set to `3080`.
- `fsGroup: 1000`, so the `node` user in the image can write to the volume.
- `fsGroupChangePolicy: OnRootMismatch`. dsh exits when `.credentials.yaml` is readable by its group, and a recursive `fsGroup` change on each mount would make it so.
- TCP readiness and liveness probes on port 3080. The liveness probe starts after 30 seconds.

## Volume layout

| Path | Content |
| --- | --- |
| `/data/.dsh` | `DSH_HOME`. Settings, profiles, sessions, and `.credentials.yaml`. |
| `/data/workspace` | Working directory of the dsh process. |
