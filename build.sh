#!/usr/bin/env bash
# Build machin-game-demo-solar. Uses a system raylib if one is installed; otherwise
# fetches raylib's prebuilt *static* release into vendor/ (no root needed) and
# links that. The committed source stays system-style; the vendored path is
# injected into a throwaway copy so solar.src is never rewritten.
# Requires machin v0.48.0+ (pointer/array FFI: alloc/poke + *Mesh param).
set -euo pipefail
cd "$(dirname "$0")"
MACHIN="${MACHIN:-machin}"
SRC=solar.src

have_system_raylib() {
    pkg-config --exists raylib 2>/dev/null && return 0
    [ -f /usr/include/raylib.h ] || [ -f /usr/local/include/raylib.h ]
}

if have_system_raylib; then
    "$MACHIN" encode "$SRC" > solar.mfl
else
    RL_VER=5.0
    RL_TAR="raylib-${RL_VER}_linux_amd64"
    RL_DIR="vendor/${RL_TAR}"
    if [ ! -f "${RL_DIR}/lib/libraylib.a" ]; then
        echo "raylib not found system-wide; vendoring the prebuilt static release..."
        mkdir -p vendor
        curl -fsSL "https://github.com/raysan5/raylib/releases/download/${RL_VER}/${RL_TAR}.tar.gz" \
            | tar xz -C vendor
    fi
    INC="$PWD/${RL_DIR}/include"
    LIB="$PWD/${RL_DIR}/lib"
    tmp="$(mktemp)"
    "$MACHIN" encode "$SRC" \
        | sed "s#header \"raylib.h\"#cflags \"-I${INC} -L${LIB}\" header \"raylib.h\"#; s#link \"raylib\"#link \":libraylib.a\"#" \
        > "$tmp"
    mv "$tmp" solar.mfl
fi

"$MACHIN" build solar.mfl -o machin-game-demo-solar
echo "built ./machin-game-demo-solar"
