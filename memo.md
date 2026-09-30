## RISC-V 用の環境構築

### パッケージ、risc-v toolchain の取得

```sh
# 依存パッケージ
sudo apt-get install autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev

# RISC-V 向けの toolchain の取得と展開
~/.local/bin/get-riscv-toolchain.sh
```

### `llc`

```sh
nas@nas-Z590-S01:~/work/llvm-project$ ./build/bin/llc --version
LLVM (http://llvm.org/):
  LLVM version 23.1.2
  DEBUG build with assertions.
  Default target: x86_64-unknown-linux-gnu
  Host CPU: rocketlake

  Registered Targets:
    aarch64    - AArch64 (little endian)
    aarch64_32 - AArch64 (little endian ILP32)
    aarch64_be - AArch64 (big endian)
    arm64      - ARM64 (little endian)
    arm64_32   - ARM64 (little endian ILP32)
    riscv32    - 32-bit RISC-V
    riscv32be  - 32-bit big endian RISC-V
    riscv64    - 64-bit RISC-V
    riscv64be  - 64-bit big endian RISC-V
    x86        - 32-bit X86: Pentium-Pro and above
    x86-64     - 64-bit X86: EM64T and AMD64
```

`Host CPU: rocketlake`:  
LLVM 内部で使用する Intel CPU の世代名

## ソースコードから実行ファイルまでを一個ずつ辿ると(x86)

### ソースコード -> LLVM IR

```sh
build/bin/clang -emit-llvm -c x86_test.c 
```

で、 `x86_test.bc` が出力される。(target とする ISA を変えたい場合はここで `--target=riscv64-unknown-elf` のようなオプションをつけておく。デフォルトは x86)  
`.bc` は LLVM IR のバイナリ表現なので、中身を見たいときは `llvm-dis` を使い可読性のある `.ll` jへ変換する

```sh
build/bin/llvm-dis x86_test.bc
```

### LLVM-IR -> アセンブリ

`llc` = LLVM static compiler   
中間コードを特定の target 向けのアセンブリ命令へ変換する(オブジェクトファイルも出力できるらしい)

```sh
build/bin/llc x86_test.bc -filetype=asm
```

### アセンブリ -> 実行ファイル

```sh
build/bin/clang x86_test.s -o x86_test
```

## riscvの場合

作業ディレクトリは `riscv-test/`。toolchain は `/opt/riscv` に入っていて、`/opt/riscv/bin` は PATH に追加済み(`riscv64-unknown-elf-gcc` と `qemu-riscv64` がそのまま使える)

### ソースコード -> LLVM IR

```sh
../build/bin/clang --target=riscv64-unknown-elf --gcc-toolchain=/opt/riscv \
    -march=rv64gc -mabi=lp64d -emit-llvm -c riscv_test.c
```

- `--target`: target は IR を作る時点で決める。x86 向けの IR を `llc -march=riscv64` に渡しても、関数属性に `"target-cpu"="x86-64"` などが残っているので `LLVM ERROR: RV64 target requires an RV64 CPU` で落ちる(C から作った IR はターゲット依存)
- `--gcc-toolchain`: `stdio.h` などのヘッダやライブラリの場所。clang は PATH からは探してくれないので毎回指定する
- `-march=rv64gc -mabi=lp64d`: toolchain のライブラリ(newlib)に合わせる。clang のデフォルト(rv64imac / lp64)のままだと、リンク時に `can't link soft-float modules with double-float modules` になる(アセンブリまでなら付けなくても通る)

中身を見たいときは x86 と同じく `llvm-dis` で `.ll` にする

```sh
../build/bin/llvm-dis riscv_test.bc
```

`target triple = "riscv64-unknown-unknown-elf"` になっていれば OK

### LLVM IR -> アセンブリ

```sh
../build/bin/llc riscv_test.bc -filetype=asm
```

target は IR の `target triple` を見て決まるので `-march` は不要

### アセンブリ -> 実行ファイル -> 実行

```sh
riscv64-unknown-elf-gcc riscv_test.s -o riscv_test
qemu-riscv64 ./riscv_test   # Total = 55
```

x86 の時と違い `.prefalign` は出ないので、GNU の as(gcc)でもそのまま通る

ソースから実行ファイルまで一発で作る場合:

```sh
../build/bin/clang --target=riscv64-unknown-elf --gcc-toolchain=/opt/riscv \
    -march=rv64gc -mabi=lp64d riscv_test.c -o riscv_test
```

## LLVM バックエンド

以下からは、LLVM に RISC-V をっベースとしたオリジナルのターゲット "MYRISCVX" を追加することを通して、ISA, LLVM の理解を深める。  
基本仕様:

- ターゲット名: MYRISCVX
- ビット数: 32bit, 64bit をサポート
- マシンターゲット名: `myriscvx32`, `myriscvx64`。 `llc` の `--march` にこれらのターゲットを指定することで、各々のアセンブリを生成可能とする
- ABI: `lp32`, `lp64`。いずれも引数の最初8個は`a0`~`a7`のレジスタ経由で、それ以降はメモリを経由して渡す



