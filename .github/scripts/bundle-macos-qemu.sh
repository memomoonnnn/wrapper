#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 /path/to/qemu-system-x86_64 /path/to/dist/qemu" >&2
  exit 2
fi

SOURCE_QEMU="$1"
QEMU_DIR="$2"
BIN_DIR="$QEMU_DIR/bin"
LIB_DIR="$QEMU_DIR/lib"
QEMU_PREFIX="$(brew --prefix qemu)"

mkdir -p "$BIN_DIR" "$LIB_DIR"
cp -L "$SOURCE_QEMU" "$BIN_DIR/qemu-system-x86_64"

# QEMU loads accelerator and device modules dynamically. Keep them beside the
# executable so the launcher can select this directory through QEMU_MODULE_DIR.
if [[ -d "$QEMU_PREFIX/lib/qemu" ]]; then
  find "$QEMU_PREFIX/lib/qemu" -type f \( -name '*.dylib' -o -name '*.so' \) -print0 |
    while IFS= read -r -d '' module; do
      cp -L "$module" "$BIN_DIR/$(basename "$module")"
    done
fi

declare -a queue
queue=("$BIN_DIR/qemu-system-x86_64")
while IFS= read -r -d '' module; do
  queue+=("$module")
done < <(find "$BIN_DIR" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)

declare -a scanned
for ((index = 0; index < ${#queue[@]}; index++)); do
  binary="${queue[$index]}"
  already_scanned=false
  for existing in "${scanned[@]:-}"; do
    [[ "$existing" == "$binary" ]] && already_scanned=true && break
  done
  if [[ "$already_scanned" == true ]]; then
    continue
  fi
  scanned+=("$binary")

  while IFS= read -r dependency; do
    case "$dependency" in
      /System/Library/*|/usr/lib/*|@*) continue ;;
      /*) ;;
      *) continue ;;
    esac
    [[ -f "$dependency" ]] || {
      echo "missing QEMU dependency: $dependency (required by $binary)" >&2
      exit 1
    }
    destination="$LIB_DIR/$(basename "$dependency")"
    if [[ -e "$destination" ]]; then
      cmp -s "$dependency" "$destination" || {
        echo "dependency basename collision: $dependency and $destination" >&2
        exit 1
      }
    else
      cp -L "$dependency" "$destination"
      queue+=("$destination")
    fi
  done < <(otool -L "$binary" | tail -n +2 | awk '{print $1}')
done

while IFS= read -r -d '' binary; do
  file "$binary" | grep -q 'Mach-O' || continue
  case "$binary" in
    "$BIN_DIR"/*) loader_prefix='@loader_path/../lib' ;;
    "$LIB_DIR"/*) loader_prefix='@loader_path' ;;
    *) echo "unexpected Mach-O location: $binary" >&2; exit 1 ;;
  esac

  while IFS= read -r dependency; do
    case "$dependency" in
      /System/Library/*|/usr/lib/*|@*) continue ;;
      /*)
        bundled="$LIB_DIR/$(basename "$dependency")"
        [[ -f "$bundled" ]] || {
          echo "dependency was not bundled: $dependency (required by $binary)" >&2
          exit 1
        }
        install_name_tool -change "$dependency" "$loader_prefix/$(basename "$dependency")" "$binary"
        ;;
    esac
  done < <(otool -L "$binary" | tail -n +2 | awk '{print $1}')

  if [[ "$binary" == "$LIB_DIR"/* ]]; then
    install_name_tool -id "@loader_path/$(basename "$binary")" "$binary"
  fi
done < <(find "$BIN_DIR" "$LIB_DIR" -type f -print0)

# Rewriting load commands invalidates Homebrew signatures. Ad-hoc signing keeps
# every nested Mach-O valid until the consuming application applies its release
# signature to the final bundle.
while IFS= read -r -d '' binary; do
  file "$binary" | grep -q 'Mach-O' || continue
  codesign --force --sign - "$binary"
done < <(find "$LIB_DIR" "$BIN_DIR" -type f -print0)

chmod +x "$BIN_DIR/qemu-system-x86_64"

bad_dependency="$({
  while IFS= read -r -d '' binary; do
    file "$binary" | grep -q 'Mach-O' || continue
    otool -L "$binary" | tail -n +2 | awk '{print $1}'
  done < <(find "$BIN_DIR" "$LIB_DIR" -type f -print0)
} | grep -Ev '^(@|/System/Library/|/usr/lib/)' | head -1 || true)"
if [[ -n "$bad_dependency" ]]; then
  echo "unbundled absolute dependency remains: $bad_dependency" >&2
  exit 1
fi
