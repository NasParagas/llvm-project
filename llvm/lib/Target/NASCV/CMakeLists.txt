# このファイルは llvm/lib/Target/CMakeLists.txt から、LLVM_TARGETS_TO_BUILD に
# NASCV が含まれているときだけ add_subdirectory(NASCV) で読み込まれる。

# "NASCV" という名前のコンポーネントグループを定義する(ソースを持たない空のターゲット)。
# このターゲットのライブラリ(NASCVCodeGen, NASCVDesc, NASCVInfo)を ADD_TO_COMPONENT NASCV で
# ここに登録しておくと、ツール側は LLVM_LINK_COMPONENTS に "NASCV" と書くだけで一式をリンクできる。
add_llvm_component_group(NASCV)

# 以降の tablegen() が入力として読む .td ファイルを指定する。
# NASCV.td がターゲット記述(レジスタ、命令、CPU 等)のトップレベルのファイルになる。
set(LLVM_TARGET_DEFINITIONS NASCV.td)

# llvm-tblgen を -gen-register-info バックエンドで NASCV.td に対して実行し、
# ビルドディレクトリ(build/lib/Target/NASCV/)に NASCVGENRegisterInfo.inc を生成する。
# 中身はレジスタの enum、レジスタクラス、MCRegisterInfo/TargetRegisterInfo の初期化コードなど。
# 生成ファイル名は TABLEGEN_OUTPUT に追加され、次の add_public_tablegen_target が使う。
tablegen(LLVM NASCVGENRegisterInfo.inc -gen-register-info)

# ここまでの tablegen() の出力(TABLEGEN_OUTPUT)すべてに依存するカスタムターゲットを作る。
# これが LLVM_COMMON_DEPENDS に追加されるので、この後に定義するライブラリ(下の CodeGen や
# サブディレクトリの MCTargetDesc 等)は .inc の生成が終わってからコンパイルされる。
# そのため tablegen() の後、add_llvm_target()/add_subdirectory() の前に書く必要がある。
add_public_tablegen_target(NASCVCommonTableGen)

# コード生成本体のライブラリ LLVMNASCVCodeGen (libLLVMNASCVCodeGen.a) を作る。
# 生成された .inc を #include できるよう、ビルドディレクトリとソースディレクトリを
# インクルードパスにも追加する。TargetMachine に加え、後で ISel やフレーム処理などを足していく。
add_llvm_target(NASCVCodeGen
    NASCVTargetMachine.cpp
)

# TargetInfo: Target オブジェクトを TargetRegistry に登録するライブラリ(慣例で LLVMNASCVInfo)。
# ここで登録されると llc --version の Registered Targets に表示され、-march で選べるようになる。
add_subdirectory(TargetInfo)
# MCTargetDesc: MC 層(MCRegisterInfo, MCInstrInfo, MCSubtargetInfo, MCAsmInfo 等)の
# 情報を作って登録するライブラリ(慣例で LLVMNASCVDesc)。
add_subdirectory(MCTargetDesc)
