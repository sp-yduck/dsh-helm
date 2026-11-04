# dsh-helm

Dockerfile and Helm chart for the [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`) Web UI.

```sh
docker build -t <registry>/dsh:0.2.1-rc.5 .
helm install dsh helm/dsh --set image.repository=<registry>/dsh \
  --set ingress.enabled=true --set ingress.hosts[0].host=dsh.example.com \
  --set publicUrl=https://dsh.example.com/
kubectl logs deploy/dsh | grep token=   # login URL; token changes on every restart
```

- dsh rejects wildcard binds, so it listens on the pod IP; `kubectl port-forward` does not work.
- Browser hostnames must be listed in `trustedHosts` (ingress hosts are added automatically).
- The listener is plain HTTP: terminate TLS at the ingress.
