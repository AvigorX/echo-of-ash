#!/usr/bin/env bash
# Verifica riproducibile di Echoes of Ash (pacchetto di archivio).
#
# Uso:
#   GODOT=/percorso/Godot_v4.7.2-stable_win64_console.exe bash verify.sh
#   bash verify.sh                 # se `godot` è nel PATH
#
# Esegue, fermandosi al primo fallimento bloccante:
#   1. versione del motore
#   2. --check-only su OGNI file .gd
#   3. --import
#   4. avvio headless (--quit)
#   5. test_world.gd e test_gameplay.gd (exit code)
# Esce 0 solo se tutti i passi passano. Non tocca nessun file di salvataggio
# (il progetto non ha salvataggi su disco).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- motore -----------------------------------------------------------------
GD="${GODOT:-}"
if [ -z "$GD" ]; then
  if command -v godot >/dev/null 2>&1; then GD="$(command -v godot)"
  elif command -v godot4 >/dev/null 2>&1; then GD="$(command -v godot4)"
  else
    echo "ERRORE: imposta GODOT=/percorso/dell'eseguibile Godot 4.7.2 (variante _console)." >&2
    exit 1
  fi
fi
[ -x "$GD" ] || { echo "ERRORE: eseguibile non trovato o non eseguibile: $GD" >&2; exit 1; }

# Godot vuole path nativi su Windows: converti se cygpath è disponibile.
if command -v cygpath >/dev/null 2>&1; then PROJ="$(cygpath -m "$HERE")"; else PROJ="$HERE"; fi

fail() { echo "ERRORE: $*" >&2; echo "=== ESITO: FALLITO ===" >&2; exit 1; }
step() { echo; echo "=== $* ==="; }

[ -f "$PROJ/project.godot" ] || fail "project.godot assente in $PROJ"

step "1. motore"
VER="$("$GD" --version 2>&1 | head -1)"
echo "versione: $VER"
case "$VER" in 4.*) ;; *) fail "versione inattesa: $VER (serve Godot 4.7.x)" ;; esac

step "2. import (genera .godot/ e la cache dei class_name)"
# Va PRIMA del --check-only: senza .godot/global_script_class_cache.cfg ogni script che usa un
# class_name fallisce con "Could not find type" e la verifica sembra rotta.
"$GD" --headless --path "$PROJ" --import >/dev/null 2>&1
echo "  eseguito (--import)"

step "3. sintassi e tipi (--check-only) su ogni script"
n_ok=0; n_ko=0; ko_list=""
while IFS= read -r s; do
  [ -z "$s" ] && continue
  out="$("$GD" --headless --path "$PROJ" --check-only --script "res://$s" 2>&1)"
  if printf '%s' "$out" | grep -qE 'SCRIPT ERROR|Parse Error|Failed to load'; then
    n_ko=$((n_ko+1)); ko_list="$ko_list $s"
    echo "  FAIL  $s"
    printf '%s\n' "$out" | grep -E 'SCRIPT ERROR|Parse Error' | sed 's/^/        /' | head -3
  else
    n_ok=$((n_ok+1)); echo "  ok    $s"
  fi
done < <(cd "$HERE" && find . -name '*.gd' -not -path './.godot/*' | sed 's|^\./||' | sort)
echo "  -> $n_ok ok, $n_ko con errori"
[ "$n_ko" -eq 0 ] || fail "script con errori di parsing:$ko_list"

step "4. avvio headless"
out="$("$GD" --headless --path "$PROJ" --quit 2>&1)"; rc=$?
printf '%s\n' "$out" | tail -2 | sed 's/^/  /'
[ "$rc" -eq 0 ] || fail "avvio headless fallito (exit $rc)"
printf '%s' "$out" | grep -q 'SCRIPT ERROR' && fail "errori di script all'avvio"

step "5. suite headless"
for t in test_world test_gameplay; do
  out="$("$GD" --headless --path "$PROJ" --script "res://tests/$t.gd" 2>&1)"; rc=$?
  line="$(printf '%s\n' "$out" | grep -E '^--- [0-9]+ passati' | tail -1)"
  errs="$(printf '%s' "$out" | grep -c 'SCRIPT ERROR')"
  echo "  $t exit=$rc script_errors=$errs ${line:-'(nessun riepilogo: lo script non ha finito)'}"
  if [ "$rc" -ne 0 ] || [ "$errs" -ne 0 ] || [ -z "$line" ] || printf '%s' "$line" | grep -qv '0 falliti'; then
    printf '%s\n' "$out" | tail -20 | sed 's/^/      /'
    fail "$t fallito (exit $rc, script errors $errs, riepilogo: ${line:-assente})"
  fi
done

echo
echo "=== ESITO: TUTTO OK (exit 0) ==="
