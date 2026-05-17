# Optional — large (~2GB). Build only with LI_LOCAL_CI_BUILD_LIC=1.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    cmake ninja-build clang-18 llvm-18-dev zlib1g-dev libzstd-dev \
    python3 git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
ENV LLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
ENV CC=clang-18
ENV CXX=clang++-18
ENV CI=true
