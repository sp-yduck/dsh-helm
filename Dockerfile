# Runs the published npm package; building the monorepo from source needs the
# full pnpm/native toolchain and is not required to serve the Web UI.
FROM node:24-bookworm-slim

# Toolchain for coding tasks. The agent runs as "node" and cannot apt-get at runtime.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git ca-certificates tini curl wget gnupg openssh-client \
      ripgrep fd-find jq less file tree unzip zip xz-utils patch diffutils procps \
      build-essential pkg-config python3 python3-venv python3-pip \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/* \
 && corepack enable

COPY --from=ghcr.io/astral-sh/uv:0.13.7 /uv /uvx /usr/local/bin/

ARG GO_VERSION=1.27.3
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" | tar -xz -C /usr/local

# Owned by node so the agent can add toolchains/targets and cargo install.
ARG RUST_VERSION=1.99.1
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal \
      --default-toolchain "${RUST_VERSION}" --component clippy,rustfmt \
 && chown -R node:node "$RUSTUP_HOME" "$CARGO_HOME"
ENV PATH=/usr/local/cargo/bin:/usr/local/go/bin:/data/go/bin:$PATH

ARG DSH_VERSION=0.2.1-rc.5
RUN npm install -g "@deepseek-ai/dsh@${DSH_VERSION}" \
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
