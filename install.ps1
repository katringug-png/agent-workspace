#Requires -Version 5.1
<#
    Разворачивает окружение агентов.

    Что делает:
      1) создаёт пустые рабочие папки (гит не хранит пустые папки сам);
      2) предлагает поставить навык «Сборщик агентов» глобально — тогда его можно
         звать из любого проекта, а не только из этой папки.

    Ничего не удаляет и ничего не отправляет наружу.

    Запуск:   ./install.ps1
    Молча:    ./install.ps1 -Global        (сразу ставить глобально, без вопроса)
              ./install.ps1 -NoGlobal      (только папки, глобально не ставить)
#>
param(
    [switch]$Global,
    [switch]$NoGlobal
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
Set-Location -Path $PSScriptRoot

function Скажи($текст, $цвет = 'Gray') { Write-Host $текст -ForegroundColor $цвет }

Скажи ''
Скажи '  Окружение агентов — установка' 'Cyan'
Скажи ''

# ── 1. Рабочие папки ─────────────────────────────────────────────────────────
$папки = 'проекты', 'входящие', 'результаты', 'корзина', 'окружение'
foreach ($п in $папки) {
    if (Test-Path -LiteralPath $п) {
        Скажи "  папка уже есть:  $п"
    } else {
        New-Item -ItemType Directory -Path $п | Out-Null
        Скажи "  создал папку:    $п" 'Green'
    }
}

# ── 2. Навык глобально ───────────────────────────────────────────────────────
$ставить = $false
if ($Global)        { $ставить = $true }
elseif ($NoGlobal)  { $ставить = $false }
else {
    Скажи ''
    Скажи '  Поставить «Сборщика агентов» глобально?' 'Yellow'
    Скажи '  Тогда его можно звать из любой папки, а не только из этой.'
    $ответ = Read-Host '  Ставить? (д/н)'
    $ставить = $ответ -match '^(д|да|y|yes)$'
}

if ($ставить) {
    $пары = @(
        @{ Откуда = '.claude/skills/sborshchik'; Куда = (Join-Path $HOME '.claude/skills/sborshchik'); Имя = 'Claude Code' },
        @{ Откуда = '.codex/skills/sborshchik';  Куда = (Join-Path $HOME '.codex/skills/sborshchik');  Имя = 'Codex' }
    )
    foreach ($пара in $пары) {
        if (-not (Test-Path -LiteralPath $пара.Откуда)) { continue }
        $родитель = Split-Path -Parent $пара.Куда
        if (-not (Test-Path -LiteralPath $родитель)) { New-Item -ItemType Directory -Path $родитель -Force | Out-Null }

        if (Test-Path -LiteralPath $пара.Куда) {
            # не затираем молча: старую копию отодвигаем с датой в имени
            $запас = "$($пара.Куда).старый-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
            Move-Item -LiteralPath $пара.Куда -Destination $запас
            Скажи "  прежний навык отложен: $запас" 'DarkYellow'
        }
        Copy-Item -LiteralPath $пара.Откуда -Destination $пара.Куда -Recurse
        Скажи "  навык поставлен для $($пара.Имя): $($пара.Куда)" 'Green'
    }
} else {
    Скажи '  Глобально не ставлю — навык работает, когда запускаешь агента из этой папки.'
}

# ── 3. Что дальше ────────────────────────────────────────────────────────────
Скажи ''
Скажи '  Готово.' 'Green'
Скажи ''
Скажи '  Дальше:'
Скажи '    1. Запусти в этой папке:  claude'
Скажи '    2. Скажи своими словами:  собери мне агента, который …'
Скажи '       (или вызови навык явно: /sborshchik)'
Скажи ''
Скажи '  Общий дашборд — файл Дашборд.html, открывается двойным кликом.'
Скажи ''
