#Requires -Version 5.1
<#
    Обновляет окружение агентов до свежей версии.

    Что обновляет:  навык «Сборщик агентов», правила, дашборд, установщики.
    Что НЕ трогает: папки проекты, входящие, результаты, окружение —
                    там твоя работа, к ней обновление не подходит.

    Дашборд — особый случай. В нём и оформление (обновляем), и твои данные:
    список агентов, задачи, журнал (сохраняем). Скрипт пересаживает данные
    в новый дашборд, а не затирает их.

    Всё заменённое кладётся в корзина/обновление-<дата>/ — ничего не пропадает.

    Запуск:   powershell -ExecutionPolicy Bypass -File .\update.ps1

    Файл сохранён в UTF-8 С BOM: без него PowerShell 5.1 читает его как ANSI
    и весь русский текст рассыпается ещё до запуска.
#>
param(
    [string]$Repo = 'https://github.com/katringug-png/agent-workspace'
)

$ErrorActionPreference = 'Stop'

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

Say ''
Say '  Обновление окружения агентов' 'Cyan'
Say ''

# ── 0. Находим папку окружения ───────────────────────────────────────────────
# Сначала та, откуда запустили, и только потом та, где лежит сам скрипт.
# Порядок важен: первое обновление делается скачанным во временную папку
# скриптом, и «папка скрипта» — это temp, где обновлять нечего.
function ЭтоОкружение($path) {
    if (-not $path) { return $false }
    return (Test-Path -LiteralPath (Join-Path $path 'CLAUDE.md')) -and
           (Test-Path -LiteralPath (Join-Path $path '.claude/skills/sborshchik'))
}

$корень = $null
foreach ($кандидат in @((Get-Location).Path, $PSScriptRoot)) {
    if (ЭтоОкружение $кандидат) { $корень = $кандидат; break }
}
if (-not $корень) {
    Say '  Это не папка окружения агентов.' 'Red'
    Say '  Открой папку «Агенты» — ту, где лежит CLAUDE.md, — и запусти оттуда.'
    exit 1
}
Set-Location -Path $корень
Say "  папка окружения: $корень"

# ── 1. Качаем свежую версию во временную папку ───────────────────────────────
$tmp = Join-Path $env:TEMP ('agent-workspace-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$zip = Join-Path $tmp 'свежее.zip'

Say '  качаю свежую версию…'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "$Repo/archive/refs/heads/main.zip" -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$fresh = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
if (-not $fresh) { Say '  Архив пустой — обновление отменено.' 'Red'; exit 1 }
$fresh = $fresh.FullName
Say '  скачано' 'Green'

# ── 2. Куда складываем прежнее ───────────────────────────────────────────────
$backup = Join-Path 'корзина' ('обновление-' + (Get-Date -Format 'yyyy-MM-dd-HHmm'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null

function Отложить($path) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    $to = Join-Path $backup $path
    $parent = Split-Path -Parent $to
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item -LiteralPath $path -Destination $to -Recurse -Force
}

# ── 3. Дашборд: новое оформление, твои данные ────────────────────────────────
# Три массива с данными вырезаем из старого дашборда и вставляем в новый.
# Массива может не быть (у старых версий не было ЗАДАЧИ) — тогда остаётся пустой.
$freshDash = Join-Path $fresh 'Дашборд.html'
if ((Test-Path -LiteralPath 'Дашборд.html') -and (Test-Path -LiteralPath $freshDash)) {
    Отложить 'Дашборд.html'
    $old = Get-Content -LiteralPath 'Дашборд.html' -Raw -Encoding UTF8
    $new = Get-Content -LiteralPath $freshDash        -Raw -Encoding UTF8
    $перенесено = @()
    foreach ($имя in 'АГЕНТЫ', 'ЗАДАЧИ', 'ЖУРНАЛ') {
        $re = "(?s)const $имя = \[.*?\r?\n\];"
        $изСтарого = [regex]::Match($old, $re)
        if (-not $изСтарого.Success) { continue }
        if (-not [regex]::IsMatch($new, $re)) { continue }
        $значение = $изСтарого.Value
        # MatchEvaluator, а не строка: в журнале бывают $ и \, и как замена они сломались бы
        $new = [regex]::Replace($new, $re, { param($m) $значение }, 1)
        $перенесено += $имя
    }
    # Защита от молчаливой потери: в старом дашборде данные есть, а перенести
    # не удалось — значит НЕ трогаем его. Обновить оформление можно и потом,
    # а восстановить чужой журнал уже нельзя.
    if ($перенесено.Count -eq 0 -and $old -match 'const АГЕНТЫ = \[') {
        Say '  дашборд НЕ обновлён: не удалось перенести твои данные, твой файл оставлен как есть' 'Yellow'
        Say '  скажи об этом — новое оформление поставим отдельно, ничего не потеряв'
    } else {
        Set-Content -LiteralPath 'Дашборд.html' -Value $new -Encoding UTF8 -NoNewline
        if ($перенесено.Count) { Say ("  дашборд обновлён, данные сохранены: " + ($перенесено -join ', ')) 'Green' }
        else { Say '  дашборд обновлён (данных для переноса не нашлось)' 'Green' }
    }
} elseif (Test-Path -LiteralPath $freshDash) {
    Copy-Item -LiteralPath $freshDash -Destination 'Дашборд.html'
    Say '  дашборд поставлен' 'Green'
}

# ── 4. Навык и служебные файлы — заменяем целиком ────────────────────────────
$заменить = @(
    '.claude/skills/sborshchik',
    '.codex/skills/sborshchik',
    'README.md',
    'install.ps1', 'install.sh',
    'update.ps1',  'update.sh',
    '.gitignore',  '.gitattributes',
    'ВЕРСИЯ.txt'
)
foreach ($путь in $заменить) {
    $откуда = Join-Path $fresh $путь
    if (-not (Test-Path -LiteralPath $откуда)) { continue }
    Отложить $путь
    $parent = Split-Path -Parent $путь
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $путь) { Remove-Item -LiteralPath $путь -Recurse -Force }
    Copy-Item -LiteralPath $откуда -Destination $путь -Recurse
    Say "  обновлено: $путь" 'Green'
}

# ── 5. Правила — не затираем молча ───────────────────────────────────────────
# CLAUDE.md и AGENTS.md человек правит под себя чаще всего. Кладём новую версию
# рядом и говорим сравнить: молча стереть чужие правила хуже, чем попросить взглянуть.
foreach ($файл in 'CLAUDE.md', 'AGENTS.md') {
    $откуда = Join-Path $fresh $файл
    if (-not (Test-Path -LiteralPath $откуда)) { continue }
    $мой = if (Test-Path -LiteralPath $файл) { Get-Content -LiteralPath $файл -Raw } else { '' }
    $свежий = Get-Content -LiteralPath $откуда -Raw
    if ($мой -eq $свежий) { continue }
    if ($мой -eq '') { Copy-Item -LiteralPath $откуда -Destination $файл; Say "  поставлено: $файл" 'Green'; continue }
    Copy-Item -LiteralPath $откуда -Destination "$файл.новый"
    Say "  правила изменились: твой $файл не тронут, новая версия рядом — $файл.новый" 'Yellow'
}

# ── 6. Если навык стоял глобально — обновляем и там ──────────────────────────
$homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
foreach ($пара in @(
    @{ Откуда = '.claude/skills/sborshchik'; Куда = (Join-Path $homeDir '.claude/skills/sborshchik') },
    @{ Откуда = '.codex/skills/sborshchik';  Куда = (Join-Path $homeDir '.codex/skills/sborshchik')  })) {
    if (-not (Test-Path -LiteralPath $пара.Куда)) { continue }   # глобально не ставили — не навязываемся
    $копия = Join-Path $backup ('глобальный-' + (Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $пара.Куда))))
    Copy-Item -LiteralPath $пара.Куда -Destination $копия -Recurse -Force
    Remove-Item -LiteralPath $пара.Куда -Recurse -Force
    Copy-Item -LiteralPath $пара.Откуда -Destination $пара.Куда -Recurse
    Say "  обновлён глобальный навык: $($пара.Куда)" 'Green'
}

# ── 7. Прибираем за собой ────────────────────────────────────────────────────
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue

Say ''
Say '  Готово.' 'Green'
Say "  Прежние файлы: $backup"
Say ''
Say '  Дальше: закрой и открой чат заново — иначе обновлённый навык не подхватится.'
Say ''
