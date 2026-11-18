#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Compile PostgreSQL 16 nativement dans Termux (PG18 natif deadlocke sur Android).
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PATH"
export TMPDIR="$PREFIX/tmp"
VERSION="${PG_VERSION:-16.16}"
SRC="postgresql-$VERSION"
DEST="$PREFIX/opt/pg16"

if [ -x "$DEST/bin/initdb" ]; then
  echo "PostgreSQL $VERSION déjà installé dans $DEST"
  exit 0
fi

echo "→ paquets de compilation"
pkg install -y build-essential bison flex bzip2 libandroid-execinfo >/dev/null 2>&1 || true

cd "$HOME"
if [ ! -f "pg$VERSION.tar.bz2" ]; then
  echo "→ téléchargement PostgreSQL $VERSION"
  curl -fsSL "https://ftp.postgresql.org/pub/source/v$VERSION/postgresql-$VERSION.tar.bz2" -o "pg$VERSION.tar.bz2"
fi

rm -rf "$SRC"
tar xjf "pg$VERSION.tar.bz2"
cd "$SRC"

echo "→ configure"
./configure --prefix="$DEST" \
  --without-readline --without-zlib --without-icu \
  --without-libxml --without-lz4 --without-zstd --disable-nls >configure.log 2>&1

# Android/bionic n'expose pas sync_file_range().
sed -i 's/#define HAVE_SYNC_FILE_RANGE 1/\/\* #undef HAVE_SYNC_FILE_RANGE \*\//' src/include/pg_config.h

echo "→ compilation (-j2, peut prendre 15-20 min)"
make -j2 >make.log 2>&1 || { echo "échec make : voir $HOME/$SRC/make.log" >&2; tail -30 make.log >&2; exit 1; }
make install >install.log 2>&1 || { echo "échec make install" >&2; exit 1; }

echo "✓ PostgreSQL $VERSION installé dans $DEST"
