#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "== Base system =="
uname -a
dpkg --print-architecture
ldd --version | head -n 1

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  build-essential \
  g++ \
  pkg-config \
  cmake \
  clang \
  file \
  binutils \
  patchelf \
  python3 \
  perl \
  default-jre-headless \
  libasound2-dev \
  libudev-dev \
  libfontconfig1-dev \
  libssl-dev \
  libxcb-shape0-dev \
  libxcb-xfixes0-dev \
  libx11-dev \
  libxkbcommon-dev \
  libdbus-1-dev

rm -rf /var/lib/apt/lists/*

echo "== Installing Rust =="
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- -y --profile minimal --default-toolchain stable
source /root/.cargo/env

rustc --version
cargo --version

echo "== Ruffle source =="
git config --global --add safe.directory /work/ruffle
git rev-parse HEAD
git describe --tags --always || true

# Build against Debian Bullseye (glibc 2.31), older than the TrimUI's
# reported glibc 2.33. Static OpenSSL avoids requiring libssl.so.1.1
# on the handheld.
export OPENSSL_STATIC=1
export OPENSSL_LIB_DIR=/usr/lib/aarch64-linux-gnu
export OPENSSL_INCLUDE_DIR=/usr/include
export PKG_CONFIG_ALLOW_CROSS=1
export RUSTFLAGS="-C target-cpu=generic -C link-arg=-Wl,--as-needed"

echo "== Building Ruffle desktop =="
cargo build \
  --locked \
  --release \
  --package ruffle_desktop \
  --no-default-features \
  --features software_video,lzma

BIN="${CARGO_TARGET_DIR}/release/ruffle_desktop"
if [[ ! -x "$BIN" ]]; then
  echo "Build finished without the expected executable: $BIN" >&2
  exit 1
fi

OUT=/work/out/package
rm -rf /work/out/package
mkdir -p "$OUT/lib"

cp "$BIN" "$OUT/ruffle.aarch64"
chmod +x "$OUT/ruffle.aarch64"
strip "$OUT/ruffle.aarch64" || true

echo "== Binary report =="
file "$OUT/ruffle.aarch64" | tee "$OUT/file.txt"
sha256sum "$OUT/ruffle.aarch64" | tee "$OUT/SHA256SUMS.txt"
ldd "$OUT/ruffle.aarch64" | tee "$OUT/ldd.txt"

{
  echo "Ruffle ref: ${RUFFLE_REF:-unknown}"
  echo "Commit: $(git rev-parse HEAD)"
  echo "Build base: Debian Bullseye ARM64"
  echo "Build glibc: $(ldd --version | head -n 1)"
  echo "Rust: $(rustc --version)"
  echo
  echo "Required GLIBC symbol versions:"
  objdump -T "$OUT/ruffle.aarch64" \
    | grep -oE 'GLIBC_[0-9]+\\.[0-9]+' \
    | sort -Vu || true
} | tee "$OUT/glibc-versions.txt"

echo "== Checking CLI startup =="
set +e
timeout 20 "$OUT/ruffle.aarch64" --version \
  >"$OUT/version-output.txt" 2>&1
CLI_STATUS=$?
set -e
echo "Exit status: $CLI_STATUS" >> "$OUT/version-output.txt"
cat "$OUT/version-output.txt"

echo "== Bundling selected non-core runtime libraries =="
# Package user-space libraries that may not exist on the TrimUI.
# Deliberately do not package glibc, the loader, graphics drivers,
# Mesa/GL libraries or kernel-facing DRM libraries. WestonPack and
# CrossMix must supply those.
mapfile -t LIBS < <(
  ldd "$OUT/ruffle.aarch64" \
    | awk '/=> \// {print $3} /^\// {print $1}' \
    | sort -u
)

for lib in "${LIBS[@]}"; do
  [[ -f "$lib" ]] || continue
  base="$(basename "$lib")"
  case "$base" in
    libc.so.*|libm.so.*|libpthread.so.*|libdl.so.*|librt.so.*|\
    libresolv.so.*|libnss_*|ld-linux*|libgcc_s.so.*|\
    libGL.so.*|libEGL.so.*|libGLES*.so.*|libvulkan.so.*|\
    libdrm.so.*|libgbm.so.*)
      echo "Skipping system/graphics library: $base"
      ;;
    *)
      cp -L "$lib" "$OUT/lib/$base"
      ;;
  esac
done

{
  echo "These libraries were copied from Debian Bullseye ARM64."
  echo "Use with: LD_LIBRARY_PATH=<game>/lib:${LD_LIBRARY_PATH:-}"
  echo
  find "$OUT/lib" -maxdepth 1 -type f -printf '%f\n' | sort
} > "$OUT/lib/README.txt"

cat > "$OUT/README-TRIMUI.txt" <<'EOF'
RUFFLE ARM64 PARA TRIMUI — BUILD EXPERIMENTAL

Objetivo:
- ARM64 nativo.
- Compilado no Debian Bullseye, usando glibc 2.31.
- Deve ser compatível com sistemas que tenham glibc 2.31 ou superior;
  o log do TrimUI informou glibc 2.33.
- Recursos de vídeo externo foram desativados para reduzir dependências.
- OpenSSL foi solicitado em modo estático.

Conteúdo:
- ruffle.aarch64: executável.
- lib/: bibliotecas de usuário selecionadas.
- glibc-versions.txt: versões GLIBC exigidas pelo binário.
- ldd.txt: dependências dinâmicas.
- file.txt e SHA256SUMS.txt: identificação e integridade.

Não copie diretamente para o aparelho ainda.
Envie o artefato completo ao ChatGPT para montar o Teste 3 do Dino Run
e do Dad 'n Me com o launcher Weston corrigido.
EOF

echo "== Creating archive =="
tar -czf /work/out/ruffle-trimui-bullseye-aarch64.tar.gz \
  -C /work/out/package .

ls -lh /work/out/ruffle-trimui-bullseye-aarch64.tar.gz
echo "Build completed."
