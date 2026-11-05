# Example values

Each file configures one access path with the chart's generic values (`ingress.*`, `trustedHosts`, `publicUrl`, `networkPolicy.*`). Copy one, replace the example names, and pass it with `-f`. CI renders and validates every file here.

| File | Path |
| --- | --- |
| [tailscale.yaml](tailscale.yaml) | Tailscale Kubernetes operator Ingress (tailnet only, optional Funnel or ProxyGroup) |
| [cloudflare-tunnel.yaml](cloudflare-tunnel.yaml) | Cloudflare Tunnel with cloudflared that you run yourself |
| [ingress-nginx-cert-manager.yaml](ingress-nginx-cert-manager.yaml) | ingress-nginx with a cert-manager certificate |

Whatever the path, two things must hold:

- The browser uses HTTPS, or `localhost` through `kubectl port-forward`.
- dsh trusts the `Host` header that reaches it. Ingress hosts are trusted automatically; list any other name in `trustedHosts`. A wrong or missing name shows up as `403` responses on `/api`.
