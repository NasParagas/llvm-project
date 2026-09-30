configure:
    cmake -S llvm -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Debug \
      -DLLVM_TARGETS_TO_BUILD="X86;RISCV;AArch64" \
      -DLLVM_ENABLE_PROJECTS="clang" \
      -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind"
build:
    cmake --build build -j4
allocate-swap:
    sudo fallocate -l 32G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile



