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
`.bc` は LLVM IR のバイナリ表現なので、中身を見たいときは `llvm-dis` を使い可読性のある `.ll` へ変換する

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

以下からは、LLVM に RISC-V をベースとしたオリジナルのターゲット "MYRISCVX" を追加することを通して、ISA, LLVM の理解を深める。  
基本仕様:

- ターゲット名: NASCV
- ビット数: 32bit, 64bit をサポート
- マシンターゲット名: `myriscvx32`, `myriscvx64`。 `llc` の `--march` にこれらのターゲットを指定することで、各々のアセンブリを生成可能とする
- ABI: `lp32`, `lp64`。いずれも引数の最初8個は`a0`~`a7`のレジスタ経由で、それ以降はメモリを経由して渡す

### `llc`

LLVM-IR を受け取り、 アセンブリを出力するツール。(`tools/llc.cpp`)  
以下のような流れで変換を行う。(後でそれぞれ詳しく見る)

- LLVM IR -> SelectionDAG
  - Legalize
  - Instruction Selection
  - SelectionDAG -> MachineInstr
  - MachineInstr 表現で、レジスタの割付処理や関数のプロローグ、エピローグ処理の挿入を行う
- MachineInstr -> MCInst
- MCInst をアセンブリへ変換(オブジェクトファイルへの変換も可能)

#### LLVM IR -> SelectionDAG

`llvm/lib/CodeGen/SelectionDAG/SelectionDAGBuilder.h[cpp]`

SelectionDAG = Selection Directed Acyclic Graph  
IR の表現を命令やデータの依存関係に置き換えたデータフロー表現()  
この表現に置き換えることで、IR よりも最適化等がしやすくなり、命令やレジスタの依存関係を表現しているため、**レジスタ割り付け**(依存関係のある命令をどのようにレジスタで結びつけるか)にも使用される。

#### Legalize

LLVM IR は target によらない中間表現であり、そこから直接変換している SelectionDAG も同様。

- 型に対する Legalize
  - アーキテクチャによっては直接扱うことが出来ないデータ型などがある
    - i1(真偽値)
    - 64bit/32bit
    - ...
    - これらのデータ形式の変換をはさむ
- 操作に対する Legalize
  - target とするアーキテクチャがサポートしていない操作を変換する
  - 対応していない DAG を生成せず、別の DAG ノードに置き換えておく

#### Instruction Selection

LLVM IR 中の命令をターゲットアーキテクチャ向けの命令に置き換える

#### TODO


## オリジナルターゲット向けの `llc` の実装に向けて

### 基本

- `llc` 自体はマルチプラットフォームに対応したコンパイラで、RISC-V、ARMなど、多様なアーキテクチャ向けの命令生成に対応している
- アーキテクチャごとに実装は分かれているが、基底クラスは共通
  - `TargetMachine` <- `LLVMTargetMachine` <- `xxxTargetMachine`
- つまりやることは、`TargetMachine` から 派生している `LLVMTargetMachine` を継承して、 `NASCVTargetMachine` を作っていく

### ちょっと詳細に

## target description file

LLVMは、各ターゲットに共通して target description file という独自の DSL のファイルを記述することで、バックエンドの実装を手助けする C++ ソースコードを自動生成してくれる。  
tdファイルには以下のような情報を記述する。

- 基本情報
- 命令定義
- 命令の生成パターン
- レジスタ定義
- 呼び出し規約

## バックエンドを実装するぞ！

### NASCVをllcに認識させる

以下の作業を行う

- NASCVをビルドターゲットとして認識させる
  - `CMakeLists` をいじる
- NASCVをコード生成ターゲットとして認識させる
  - いろいろいじる
- `llvm/lib/Target/NASCV` に最低限のファイルを追加する

#### ビルドターゲットとして認識させる

`llvm-project`をビルドしたときの

```sh
cmake -S llvm -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DLLVM_TARGETS_TO_BUILD="X86;RISCV;AArch64" \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind"
```

DLLVM_TARGETS_TO_BUILD に当たるものとして認識させる。  

`./llvm/CMakeLists.txt` を以下のように

```txt
set(LLVM_ALL_TARGETS
  AArch64
  ...
  MSP430
  NASCV
  NVPTX
  ...
```

#### コード生成ターゲットとして認識させる

`llc`のオプションとして`--march=nascv32`や`--march=nascv64`のように指定できるようにする

`llvm/cmake/config-ix.cmake` に以下を追加

```cmake
elseif (LLVM_NATIVE_ARCH MATCHES "nascv32")
  set(LLVM_NATIVE_ARCH NASCV)
elseif (LLVM_NATIVE_ARCH MATCHES "nascv64")
  set(LLVM_NATIVE_ARCH NASCV)
```

Triple(GNUのビルドシステムにおいて使われるターゲットプラットフォームの表現方法) を定義する。  
Tripleは以下の4つのフィールドから構成される

- CPUファミリー/モデル
  - riscv32 など
- ベンダ名
  - サポートするマシンのベンダ
    - nvidia, apple, unknown, none など
- OS
  - linux, darwin, none など
- env
  - ABI、オブジェクト形式
  - gnu, elf など

LLVM 側で知っているベンダは `./llvm/include/llvm/TargetParser/Triple.h` の `VenderType` に並んでいるもののみ。  

```opus
ベンダが unknown や none ばかりなのはなぜか

ほとんどのターゲットでは、ベンダ欄が生成されるコードに影響しないからです。同じRV64GCなら、どこの会社のチップやボードでも出すべき命令は同じです。なので「指定なし」の値を入れておくのが普通になっています。

このリポジトリのソースでも確かめました。
- LLVMが知っているベンダは、Triple.h の VendorType に並んでいる15社（Apple, PC, SCEI, IBM, NVIDIA, AMD など）だけです。リストにない名前、たとえば riscv64-sifive-elf と書いても、内部では UnknownVendor として扱われます。
- llvm/lib/Target/ の中でベンダを見て処理を分けているのは、AArch64, AMDGPU, SPIRV, X86 だけでした。RISCVには1か所もありません。RISCVで "Vendor" と付くのは Xqccmp などのベンダ独自の命令拡張の話で、これはtripleではなく -march で指定します。

逆にベンダが意味を持つのは、ベンダがそのままABIやOSを決めている場合です。
- apple: macOS / iOS のABIとMach-O形式
- pc: x86のWindows（x86_64-pc-windows-msvc）
- nvidia, amd: GPU（nvptx64-nvidia-cuda, amdgcn-amd-amdhsa）
- scei: PlayStation

unknown と none の違い

どちらも「指定なし」という意味で、どちらを使うかはコミュニティの慣習によります。
- unknown: GNUの config.sub が、省略された欄に入れる値です。riscv-gnu-toolchain（riscv64-unknown-elf-gcc）やLinux向けはこちらを使います。
- none: ベアメタルARM向けの arm-none-eabi が有名で、「ベンダもOSもない」というニュアンスです。ただし上の結果のとおり、LLVMは none をOS欄に移し（OSなし＝ベアメタルという扱い）、ベンダ欄には unknown を入れ直します。
```

`./llvm/include/llvm/TargetParser/Triple.h` に以下のように追記

```cpp
enum ArchType {
  ...
  nascv32,
  nascv64,
  ...
}
```

`./llvm/lib/TargetParser/Triple.cpp` に以下のように追記
```cpp
StringRef Triple::getArchTypeName(ArchType Kind) {
  ...
  case nascv32:
    return "nascv32";
  case nascv64:
    return "nascv64";
  ...
}
```

#### `llvm/lib/Target/NASCV` に最低限のファイルを追加する




