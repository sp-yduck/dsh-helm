# Runs the published npm package; building the monorepo from source needs the
# full pnpm/native toolchain and is not required to serve the Web UI.
FROM node:24-bookworm-slim

ARG DSH_VERSION=0.2.1-rc.5

# git/bash/ca-certificates: tools the agent's shell commands expect to find.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates tini \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g "@deepseek-ai/dsh@${DSH_VERSION}" \
 && npm cache clean --force

ENV DSH_HOME=/data/.dsh \
    HOME=/data
RUN mkdir -p /data/workspace && chown -R node:node /data
USER node
WORKDIR /data/workspace
EXPOSE 3080

# dsh rejects wildcard bind addresses, so bind the pod/container IP (DSH_HOST),
# falling back to the container's first address.
ENTRYPOINT ["tini", "--", "sh", "-c", "exec dsh --profile web --no-open --host \"${DSH_HOST:-$(hostname -i | cut -d' ' -f1)}\" --port \"${DSH_PORT:-3080}\" \"$@\"", "dsh"]
