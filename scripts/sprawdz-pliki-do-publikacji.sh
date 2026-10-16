#!/usr/bin/env bash
# Porównuje pliki śledzone w git z listą dozwolonych wzorców.
# Kod 0 = OK; ≠0 = wypisuje pliki spoza listy.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LISTA="${ROOT}/scripts/dozwolone-pliki.txt"

if [[ ! -f "$LISTA" ]]; then
  echo "Brak listy dozwolonych: $LISTA" >&2
  exit 2
fi

# Wczytaj wzorce (pomiń puste i komentarze)
patterns=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  patterns+=("$line")
done < "$LISTA"

if [[ ${#patterns[@]} -eq 0 ]]; then
  echo "Lista dozwolonych jest pusta: $LISTA" >&2
  exit 2
fi

allowed() {
  local f="$1" p
  for p in "${patterns[@]}"; do
    # shell glob: dopasowanie całej ścieżki względem root repo
    # shellcheck disable=SC2254
    case "$f" in
      $p) return 0 ;;
    esac
  done
  return 1
}

spoza=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if ! allowed "$f"; then
    spoza+=("$f")
  fi
done < <(git -C "$ROOT" ls-files)

if [[ ${#spoza[@]} -gt 0 ]]; then
  echo "Pliki śledzone spoza listy dozwolonych do publikacji:" >&2
  printf '  %s\n' "${spoza[@]}" >&2
  echo "Dodaj wzorzec w scripts/dozwolone-pliki.txt albo usuń plik z indeksu (git rm --cached)." >&2
  exit 1
fi

echo "OK: wszystkie śledzone pliki są na liście dozwolonych (${#patterns[@]} wzorców)."
exit 0
