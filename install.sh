#!/usr/bin/env bash
# Разворачивает окружение агентов.
#
#   1) создаёт пустые рабочие папки (гит не хранит пустые папки сам);
#   2) предлагает поставить навык «Сборщик агентов» глобально — тогда его можно
#      звать из любого проекта, а не только из этой папки.
#
# Ничего не удаляет и ничего не отправляет наружу.
#
#   bash install.sh              спросит про глобальную установку
#   bash install.sh --global     сразу ставить глобально
#   bash install.sh --no-global  только папки
#
# Имена переменных здесь латиницей не для красоты: bash не принимает кириллицу
# в именах и падает с «not a valid identifier». Текст для человека — русский.

set -euo pipefail
cd "$(dirname "$0")"

ok()   { printf '\033[32m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m%s\033[0m\n' "$1"; }
say()  { printf '%s\n' "$1"; }

echo
printf '\033[36m%s\033[0m\n' '  Окружение агентов — установка'
echo

# ── 1. Рабочие папки ─────────────────────────────────────────────────────────
for dir in проекты входящие результаты корзина окружение; do
  if [ -d "$dir" ]; then
    say "  папка уже есть:  $dir"
  else
    mkdir -p "$dir"
    ok "  создал папку:    $dir"
  fi
done

# ── 2. Навык глобально ───────────────────────────────────────────────────────
install_global=""
case "${1:-}" in
  --global)    install_global="yes" ;;
  --no-global) install_global="no" ;;
  *)
    echo
    warn '  Поставить «Сборщика агентов» глобально?'
    say  '  Тогда его можно звать из любой папки, а не только из этой.'
    printf '  Ставить? (д/н): '
    read -r answer || answer="n"
    case "$answer" in [дДyY]*) install_global="yes" ;; *) install_global="no" ;; esac
    ;;
esac

put_skill() {
  src="$1"; dst="$2"; tool="$3"
  [ -d "$src" ] || return 0
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ]; then
    # не затираем молча: старую копию отодвигаем с датой в имени
    backup="$dst.старый-$(date +%Y-%m-%d-%H%M)"
    mv "$dst" "$backup"
    warn "  прежний навык отложен: $backup"
  fi
  cp -R "$src" "$dst"
  ok "  навык поставлен для $tool: $dst"
}

if [ "$install_global" = "yes" ]; then
  put_skill ".claude/skills/sborshchik" "$HOME/.claude/skills/sborshchik" "Claude Code"
  put_skill ".codex/skills/sborshchik"  "$HOME/.codex/skills/sborshchik"  "Codex"
else
  say '  Глобально не ставлю — навык работает, когда запускаешь агента из этой папки.'
fi

# ── 3. Что дальше ────────────────────────────────────────────────────────────
echo
ok '  Готово.'
echo
say '  Дальше:'
say '    1. Запусти в этой папке:  claude'
say '    2. Скажи своими словами:  собери мне агента, который …'
say '       (или вызови навык явно: /sborshchik)'
echo
say '  Общий дашборд — файл Дашборд.html, открывается двойным кликом.'
echo
