#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
command -v msgfmt > /dev/null
log=$(mktemp)
trap 'rm -f "$log"' EXIT HUP INT TERM
passed=0
inherited=0
failed=0
for file in components/*/locale/*.po; do
    if msgfmt --check -o /dev/null "$file" > "$log" 2>&1; then
        passed=$((passed + 1))
    else
        baseline=$(awk -v path="$file" '$2 == path { print $1 }' tests/translation-baseline.txt)
        if [ -n "$baseline" ] && [ "$(git hash-object "$file")" = "$baseline" ]; then
            printf 'KNOWN baseline plural-form failure: %s\n' "$file"
            inherited=$((inherited + 1))
        else
            printf 'FAILED translation validation: %s\n' "$file" >&2
            sed -n '1,80p' "$log" >&2
            failed=$((failed + 1))
        fi
    fi
done
printf 'Translations: %s passed, %s unchanged baseline failures, %s new failures\n' "$passed" "$inherited" "$failed"
[ "$failed" -eq 0 ]
