#!/usr/bin/env bash
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$HOME/.claude"
dry=0
[ "${1:-}" = "--dry-run" ] && dry=1

for kind in skills agents; do
    [ -d "$src/$kind" ] || continue
    [ "$dry" -eq 1 ] || mkdir -p "$target/$kind"

    for item in "$src/$kind"/*; do
        [ -e "$item" ] || continue
        name="$(basename "$item")"
        dest="$target/$kind/$name"
        if [ -e "$dest" ]; then verb="обновлён"; else verb="добавлен"; fi

        if [ "$dry" -eq 1 ]; then
            echo "[dry-run] $kind/$name -> $dest ($verb)"
            continue
        fi

        rm -rf "$dest"
        cp -R "$item" "$dest"
        echo "$kind/$name — $verb"
    done
done

echo
echo "Цель: $target"
if [ "$dry" -eq 1 ]; then
    echo "Ничего не скопировано (--dry-run)."
else
    echo "Готово. Изменения подхватятся в новой сессии Claude Code."
fi
