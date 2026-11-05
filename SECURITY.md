# Security policy

## Report a vulnerability

Report a vulnerability in the chart or the image through [GitHub private vulnerability reporting](https://github.com/sp-yduck/dsh-helm/security/advisories/new). Do not open a public issue.

Report a vulnerability in dsh itself to the upstream [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) project.

## Supported versions

Only the latest chart version receives fixes.

## Deployment model

dsh is a coding agent that runs shell commands inside its pod. Anyone who can log in to the UI can run commands with the pod's permissions and read the files and API keys on its volume. Before you deploy, read the upstream [safety notice](https://github.com/deepseek-ai/deepseek-harness/blob/master/SAFETY.md) and:

- Expose the UI only through TLS, and only to people who may use the agent.
- Treat the login URL that dsh prints as a credential.
- Do not mount cluster credentials or broad cloud credentials into the pod.
