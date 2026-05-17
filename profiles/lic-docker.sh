chmod +x scripts/ci.sh scripts/build.sh scripts/checkout-ecosystem-siblings.sh scripts/resolve-lic.sh 2>/dev/null || true
export LLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
export CC=clang-18
export CXX=clang++-18
if [[ -x scripts/checkout-ecosystem-siblings.sh ]]; then
  ./scripts/checkout-ecosystem-siblings.sh || true
fi
./scripts/ci.sh
