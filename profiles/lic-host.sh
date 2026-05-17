# Host lic CI — requires LLVM/clang/cmake on the machine (brew install llvm@18 cmake ninja).
if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake not found — install LLVM toolchain or use lic-docker with LI_LOCAL_CI_BUILD_LIC=1" >&2
  exit 1
fi
chmod +x scripts/ci.sh scripts/build.sh scripts/resolve-lic.sh 2>/dev/null || true
if [[ "$(uname -s)" == "Darwin" ]] && [[ -d "$(brew --prefix llvm@18 2>/dev/null)/lib/cmake/llvm" ]]; then
  export LLVM_DIR="$(brew --prefix llvm@18)/lib/cmake/llvm"
  export CC=clang
  export CXX=clang++
fi
./scripts/ci.sh
