# Contributing to dsh-helm

Thanks for helping improve dsh-helm. This repository contains a container image (`Dockerfile`) and a Helm chart (`helm/dsh/`) for running the DeepSeek Harness Web UI on Kubernetes.

## Report a bug or request a feature

Open an issue with the matching template. For a bug, include the chart version, the dsh version (`appVersion` or `image.tag`), your Kubernetes distribution and version, the values you changed, and the pod logs (`kubectl logs deploy/<release>-dsh`). Remove login URLs and tokens from the logs first.

Report security problems privately as described in [SECURITY.md](SECURITY.md), not in a public issue.

## Change the chart

1. Edit the files under `helm/dsh/`.
2. If you add or change a value, update `values.yaml`, `values.schema.json`, and the table in `helm/dsh/README.md`.
3. Raise `version` in `helm/dsh/Chart.yaml`. CI fails a pull request that changes the chart without a higher version, because the push on `main` must never overwrite a published chart. Use a minor bump for new values or behavior and a patch bump for fixes.
4. Add or update a test in `helm/dsh/tests/` for the behavior you changed.
5. Check the chart locally:

   ```sh
   helm lint --strict helm/dsh
   helm unittest helm/dsh   # https://github.com/helm-unittest/helm-unittest
   helm template dsh helm/dsh | kubeconform -strict -summary
   ```

## Change the image

To build the image locally, run `docker build -t dsh:dev .`. To release a new dsh version, change `appVersion` in `helm/dsh/Chart.yaml`. CI passes it to the build as `DSH_VERSION`, and the chart uses it as the default image tag. Because the chart changes, also raise the chart `version`.

## Pull requests

- Keep each pull request to one topic.
- Use a [Conventional Commits](https://www.conventionalcommits.org/) title, such as `feat(chart): add a NetworkPolicy` or `fix(image): pin uv`.
- Describe how you verified the change.
