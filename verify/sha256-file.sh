#!/bin/sh
# Reviewer check for recipes/hash/sha256-file.md.
# Users do not need this file. It runs the recipe's hash commands against
# frozen vectors and a second implementation (Python hashlib, same SHA-256
# as Windows Get-FileHash / .NET SHA256).
#
# Windows PowerShell is not executed here. Windows PowerShell 5.1.26100.9444
# Get-FileHash was checked by hand against $hello, $empty, and $abc, and
# .Hash without .ToLower() was the uppercase form of $hello. The recipe's
# .ToLower() exists so that uppercase hex matches these lowercase vectors.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
recipe=$root/recipes/hash/sha256-file.md
cd "$root"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing %s\n' "$1" >&2
    exit 1
  }
}
need cut
need python3
need sha256sum
need shasum

hello='c4ad2c6f007b94e68d0b0422712ab02a820ff4c0a6aea03808cd864cdf985bc4'
empty='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
nonew='84629f9a7125f5b50e9767df4fea1e93b34462b57bd35a12ebca2b52520f5c84'
abc='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
binary='3a100994c4e38751871e6e8eef9adad2b20177fdeaf650daacdcd74f4c9421e3'

grep -q "$hello" "$recipe" || {
  printf 'recipe is missing the hello epiphyte vector\n' >&2
  exit 1
}
grep -q "$empty" "$recipe" || {
  printf 'recipe is missing the empty-file vector\n' >&2
  exit 1
}

# The paste blocks must be the commands this script runs.
grep -q "sha256sum -- \"\$FILE\" | cut -d ' ' -f 1" "$recipe"
grep -q "shasum -a 256 -- \"\$FILE\" | cut -d ' ' -f 1" "$recipe"
grep -q '(Get-FileHash -Algorithm SHA256 -Path $File).Hash.ToLower()' "$recipe"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf 'hello epiphyte\n' > "$tmp/hello.txt"
printf '' > "$tmp/empty.bin"
printf 'no newline' > "$tmp/nonewline.txt"
printf 'abc' > "$tmp/spaced name.txt"
printf 'a\0b\n' > "$tmp/binary.bin"

pyhex() {
  python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
}

# Same pipelines as the recipe, both branches, so Linux (sha256sum) and
# macOS (shasum) are checked even when both tools exist.
hash_sha256sum() {
  FILE=$1
  sha256sum -- "$FILE" | cut -d ' ' -f 1
}
hash_shasum() {
  FILE=$1
  shasum -a 256 -- "$FILE" | cut -d ' ' -f 1
}

check() {
  file=$1
  want=$2
  a=$(hash_sha256sum "$file")
  b=$(hash_shasum "$file")
  c=$(pyhex "$file")
  printf '%s\n' "$file"
  printf '  sha256sum %s\n' "$a"
  printf '  shasum    %s\n' "$b"
  printf '  python    %s\n' "$c"
  [ "$a" = "$want" ] && [ "$b" = "$want" ] && [ "$c" = "$want" ] || {
    printf 'mismatch for %s (want %s)\n' "$file" "$want" >&2
    exit 1
  }
  # Frozen output is lowercase hex only, no filename.
  printf '%s\n' "$a" | grep -q '^[0-9a-f]\{64\}$' || {
    printf 'output is not 64 lowercase hex: %s\n' "$a" >&2
    exit 1
  }
}

check "$tmp/hello.txt" "$hello"
# One changed byte must not reuse the hello vector.
printf 'hello epiphyte\n' | python3 -c 'import sys; d=sys.stdin.buffer.read(); sys.stdout.buffer.write(d[:-1]+bytes([d[-1]^1]))' > "$tmp/hello-flip.bin"
flipped=$(hash_sha256sum "$tmp/hello-flip.bin")
[ "$flipped" != "$hello" ] || {
  printf 'one-byte change did not change the hash\n' >&2
  exit 1
}
check "$tmp/empty.bin" "$empty"
check "$tmp/nonewline.txt" "$nonew"
check "$tmp/spaced name.txt" "$abc"
check "$tmp/binary.bin" "$binary"

if command -v openssl >/dev/null 2>&1; then
  o=$(openssl dgst -sha256 "$tmp/hello.txt" | awk '{print $NF}')
  [ "$o" = "$hello" ] || {
    printf 'openssl dgst mismatch: %s\n' "$o" >&2
    exit 1
  }
  printf 'openssl dgst matches hello vector\n'
fi

# Optional: real Get-FileHash if the image is already local. Do not pull.
if command -v docker >/dev/null 2>&1 && docker image inspect mcr.microsoft.com/powershell:lts-ubuntu-22.04 >/dev/null 2>&1; then
  docker run --rm -v "$tmp:/data:ro" mcr.microsoft.com/powershell:lts-ubuntu-22.04 \
    pwsh -NoProfile -Command "\$ErrorActionPreference='Stop'; \$got=(Get-FileHash -Algorithm SHA256 -Path '/data/hello.txt').Hash.ToLower(); if (\$got -ne '$hello') { Write-Error \"pwsh mismatch \$got\"; exit 1 }; Write-Output \"pwsh Get-FileHash matches hello vector\""
fi

printf 'sha256-file: ok\n'
