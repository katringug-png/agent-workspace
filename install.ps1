#Requires -Version 5.1
<#
    Разворачивает окружение агентов.

    Что делает:
      1) создаёт пустые рабочие папки (гит не хранит пустые папки сам);
      2) предлагает поставить навык «Сборщик агентов» глобально — тогда его можно
         звать из любого проекта, а не только из этой папки.

    Ничего не удаляет и ничего не отправляет наружу.

    Запуск:   ./install.ps1
              ./install.ps1 -Global      сразу ставить глобально, без вопроса
              ./install.ps1 -NoGlobal    только папки

    Два правила про этот файл, оба оплачены поломкой:
      * имена переменных — латиницей;
      * файл сохранён в UTF-8 С BOM. Windows PowerShell 5.1 без BOM читает его
        как ANSI, и весь русский текст превращается в кашу ещё до запуска.
#>
param(
    [switch]$Global,
    [switch]$NoGlobal
)

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

Say ''
Say '  Окружение агентов — установка' 'Cyan'
Say ''

# ── 1. Рабочие папки ─────────────────────────────────────────────────────────
$folders = 'проекты', 'входящие', 'результаты', 'корзина', 'окружение'
foreach ($folder in $folders) {
    if (Test-Path -LiteralPath $folder) {
        Say "  папка уже есть:  $folder"
    } else {
        New-Item -ItemType Directory -Path $folder | Out-Null
        Say "  создал папку:    $folder" 'Green'
    }
}

# ── 2. Навык глобально ───────────────────────────────────────────────────────
if     ($Global)   { $installGlobal = $true }
elseif ($NoGlobal) { $installGlobal = $false }
else {
    Say ''
    Say '  Поставить «Сборщика агентов» глобально?' 'Yellow'
    Say '  Тогда его можно звать из любой папки, а не только из этой.'
    $answer = Read-Host '  Ставить? (д/н)'
    $installGlobal = $answer -match '^(д|да|y|yes)$'
}

if ($installGlobal) {
    # USERPROFILE, а не $HOME: на Windows это та же папка, но $HOME доступен
    # только для чтения — с ним установку нельзя ни проверить, ни перенаправить.
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    $targets = @(
        @{ From = '.claude/skills/sborshchik'; To = (Join-Path $homeDir '.claude/skills/sborshchik'); Tool = 'Claude Code' },
        @{ From = '.codex/skills/sborshchik';  To = (Join-Path $homeDir '.codex/skills/sborshchik');  Tool = 'Codex' }
    )
    foreach ($t in $targets) {
        if (-not (Test-Path -LiteralPath $t.From)) { continue }
        $parent = Split-Path -Parent $t.To
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

        if (Test-Path -LiteralPath $t.To) {
            # не затираем молча: старую копию отодвигаем с датой в имени
            $backup = "$($t.To).старый-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
            Move-Item -LiteralPath $t.To -Destination $backup
            Say "  прежний навык отложен: $backup" 'DarkYellow'
        }
        Copy-Item -LiteralPath $t.From -Destination $t.To -Recurse
        Say "  навык поставлен для $($t.Tool): $($t.To)" 'Green'
    }
} else {
    Say '  Глобально не ставлю — навык работает, когда запускаешь агента из этой папки.'
}

# ── 3. Что дальше ────────────────────────────────────────────────────────────
Say ''
Say '  Готово.' 'Green'
Say ''
Say '  Дальше:'
Say '    1. Запусти в этой папке:  claude'
Say '    2. Скажи своими словами:  собери мне агента, который …'
Say '       (или вызови навык явно: /sborshchik)'
Say ''
Say '  Общий дашборд — файл Дашборд.html, открывается двойным кликом.'
Say ''
