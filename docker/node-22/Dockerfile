# Slim Node 22 for li-cursor-agents / TS repos (~150MB compressed).
FROM node:22-bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
ENV CI=true
