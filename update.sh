#!/usr/bin/env bash
# Обновляет окружение агентов до свежей версии.
#
# Что обновляет:  навык «Сборщик агентов», правила, дашборд, установщики.
# Что НЕ трогает: папки проекты, входящие, результаты, окружение —
#                 там твоя работа, к ней обновление не подходит.
#
# Дашборд — особый случай. В нём и оформление (обновляем), и твои данные:
# список агентов, задачи, журнал (сохраняем). Скрипт пересаживает данные
# в новый дашборд, а не затирает их.
#
# Всё заменённое кладётся в корзина/обновление-<дата>/ — ничего не пропадает.
#
#   bash update.sh
#
# Имена переменных латиницей: bash не принимает кириллицу в именах.

set -euo pipefail
cd "$(dirname "$0")"

REPO="${1:-https://github.com/katringug-png/agent-workspace}"

ok()   { printf '\033[32m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m%s\033[0m\n' "$1"; }
bad()  { printf '\033[31m%s\033[0m\n' "$1"; }
say()  { printf '%s\n' "$1"; }

echo
printf '\033[36m%s\033[0m\n' '  Обновление окружения агентов'
echo

# ── 0. Убеждаемся, что мы в окружении, а не в случайной папке ────────────────
if [ ! -f CLAUDE.md ] || [ ! -d .claude/skills/sborshchik ]; then
  bad '  Это не папка окружения агентов.'
  say '  Запусти скрипт внутри папки «Агенты» — там, где лежит CLAUDE.md.'
  exit 1
fi

# ── 1. Качаем свежую версию во временную папку ───────────────────────────────
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say '  качаю свежую версию…'
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$REPO/archive/refs/heads/main.zip" -o "$tmp/fresh.zip"
else
  wget -q "$REPO/archive/refs/heads/main.zip" -O "$tmp/fresh.zip"
fi
( cd "$tmp" && unzip -q fresh.zip )
fresh="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)"
[ -n "$fresh" ] || { bad '  Архив пустой — обновление отменено.'; exit 1; }
ok '  скачано'

# ── 2. Куда складываем прежнее ───────────────────────────────────────────────
backup="корзина/обновление-$(date +%Y-%m-%d-%H%M)"
mkdir -p "$backup"

put_aside() {
  [ -e "$1" ] || return 0
  mkdir -p "$backup/$(dirname "$1")"
  cp -R "$1" "$backup/$1"
}

# ── 3. Дашборд: новое оформление, твои данные ────────────────────────────────
# Три массива с данными вырезаем из старого дашборда и вставляем в новый.
# Массива может не быть (у старых версий не было ЗАДАЧИ) — тогда остаётся пустой.
if [ -f "Дашборд.html" ] && [ -f "$fresh/Дашборд.html" ]; then
  put_aside "Дашборд.html"
  if perl -e '
      use strict; use warnings;
      my ($old_f, $new_f) = @ARGV;
      local $/;
      open my $o, "<:encoding(UTF-8)", $old_f or die; my $old = <$o>; close $o;
      open my $n, "<:encoding(UTF-8)", $new_f or die; my $new = <$n>; close $n;
      my @moved;
      for my $name ("АГЕНТЫ", "ЗАДАЧИ", "ЖУРНАЛ") {
        my $re = qr/const \Q$name\E = \[.*?\n\];/s;
        next unless $old =~ /($re)/;
        my $block = $1;
        next unless $new =~ $re;
        # значение переменной подставляется как есть: $ и \ внутри журнала не разбираются
        $new =~ s/$re/$block/s;
        push @moved, $name;
      }
      open my $w, ">:encoding(UTF-8)", $new_f or die; print $w $new; close $w;
      print join(", ", @moved), "\n";
    ' "Дашборд.html" "$fresh/Дашборд.html" > "$tmp/moved.txt" 2>/dev/null; then
    cp "$fresh/Дашборд.html" "Дашборд.html"
    moved="$(cat "$tmp/moved.txt")"
    if [ -n "${moved// /}" ]; then ok "  дашборд обновлён, данные сохранены: $moved"
    else ok '  дашборд обновлён (данных для переноса не нашлось)'; fi
  else
    warn '  дашборд перенести не вышло — твой оставлен как есть, новый лежит в корзине'
  fi
elif [ -f "$fresh/Дашборд.html" ]; then
  cp "$fresh/Дашборд.html" "Дашборд.html"
  ok '  дашборд поставлен'
fi

# ── 4. Навык и служебные файлы — заменяем целиком ────────────────────────────
for path in \
  ".claude/skills/sborshchik" \
  ".codex/skills/sborshchik" \
  "README.md" \
  "install.ps1" "install.sh" \
  "update.ps1"  "update.sh" \
  ".gitignore"  ".gitattributes" \
  "ВЕРСИЯ.txt"
do
  [ -e "$fresh/$path" ] || continue
  put_aside "$path"
  mkdir -p "$(dirname "$path")"
  rm -rf "$path"
  cp -R "$fresh/$path" "$path"
  ok "  обновлено: $path"
done
chmod +x install.sh update.sh 2>/dev/null || true

# ── 5. Правила — не затираем молча ───────────────────────────────────────────
# CLAUDE.md и AGENTS.md человек правит под себя чаще всего. Кладём новую версию
# рядом и просим сравнить: молча стереть чужие правила хуже, чем попросить взглянуть.
for f in CLAUDE.md AGENTS.md; do
  [ -f "$fresh/$f" ] || continue
  if [ ! -f "$f" ]; then cp "$fresh/$f" "$f"; ok "  поставлено: $f"; continue; fi
  if cmp -s "$f" "$fresh/$f"; then continue; fi
  cp "$fresh/$f" "$f.новый"
  warn "  правила изменились: твой $f не тронут, новая версия рядом — $f.новый"
done

# ── 6. Если навык стоял глобально — обновляем и там ──────────────────────────
update_global() {
  src="$1"; dst="$2"; tag="$3"
  [ -d "$dst" ] || return 0        # глобально не ставили — не навязываемся
  cp -R "$dst" "$backup/глобальный-$tag"
  rm -rf "$dst"
  cp -R "$src" "$dst"
  ok "  обновлён глобальный навык: $dst"
}
update_global ".claude/skills/sborshchik" "$HOME/.claude/skills/sborshchik" "claude"
update_global ".codex/skills/sborshchik"  "$HOME/.codex/skills/sborshchik"  "codex"

echo
ok '  Готово.'
say "  Прежние файлы: $backup"
echo
say '  Дальше: закрой и открой чат заново — иначе обновлённый навык не подхватится.'
echo
