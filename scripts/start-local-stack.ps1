param(
    [string]$ProjectName = "gemini-flow-stack",
    [string]$ComposeFile = "docker-compose.stack.yml",
    [string]$RemoteBrowserBaseUrl = "http://flow-captcha-service:8060"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[flow-stack] $Message"
}

function Test-Command {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Stop-ConflictingContainer {
    param(
        [string]$Name,
        [string]$ExpectedProject
    )

    try {
        $inspectJson = docker inspect $Name 2>$null
    } catch {
        return
    }

    if ($LASTEXITCODE -ne 0) {
        return
    }

    if (-not $inspectJson) {
        return
    }

    $inspect = $inspectJson | ConvertFrom-Json
    if (-not $inspect) {
        return
    }

    $project = $inspect[0].Config.Labels.'com.docker.compose.project'
    if (-not $project) {
        $project = "<manual>"
    }
    if ($project -eq $ExpectedProject) {
        return
    }

    Write-Step "Stopping existing container '$Name' from project '$project' to avoid name conflicts."
    docker stop $Name | Out-Null
    docker rm $Name | Out-Null
}

function Update-SettingTomlRemoteUrl {
    param([string]$Path, [string]$BaseUrl)

    if (-not (Test-Path $Path)) {
        return
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $content = [System.IO.File]::ReadAllText(
        $resolvedPath,
        [System.Text.UTF8Encoding]::new($false, $true)
    )
    $replacement = "remote_browser_base_url = `"$BaseUrl`""
    $hasCaptchaSection = $content -match '(?m)^\[captcha\]\s*$'
    if ($content -match '(?m)^remote_browser_base_url\s*=') {
        $content = [regex]::Replace(
            $content,
            '(?m)^remote_browser_base_url\s*=\s*".*?"',
            $replacement
        )
    } elseif ($hasCaptchaSection) {
        $content = $content -replace '(?m)^\[captcha\]\s*$', "[captcha]`r`n$replacement"
    } else {
        $content = $content.TrimEnd() + "`r`n`r`n[captcha]`r`n$replacement`r`n"
        $hasCaptchaSection = $true
    }

    if ($content -match '(?m)^captcha_method\s*=') {
        $content = [regex]::Replace(
            $content,
            '(?m)^captcha_method\s*=\s*".*?"',
            'captcha_method = "remote_browser"'
        )
    } elseif ($hasCaptchaSection) {
        $content = $content -replace '(?m)^\[captcha\]\s*$', "[captcha]`r`ncaptcha_method = `"remote_browser`""
    }

    [System.IO.File]::WriteAllText(
        $resolvedPath,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-HttpGetWithRetry {
    param(
        [string]$Uri,
        [int]$Attempts = 30,
        [int]$DelaySeconds = 2
    )

    $lastError = $null
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            return Invoke-RestMethod -Method Get -Uri $Uri -TimeoutSec 10
        } catch {
            $lastError = $_.Exception.Message
            if ($attempt -lt $Attempts) {
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }

    throw "GET $Uri failed after $Attempts attempts. Last error: $lastError"
}

function Invoke-ContainerHttpGet {
    param(
        [string]$Container,
        [string]$Url
    )

    $escapedUrl = $Url.Replace("'", "'`"''`"'")
    docker exec $Container sh -lc "if command -v curl >/dev/null 2>&1; then curl -fsS '$escapedUrl'; else python -c 'import sys, urllib.request; print(urllib.request.urlopen(sys.argv[1], timeout=10).read().decode())' '$escapedUrl'; fi"
}

if (-not (Test-Command "docker")) {
    throw "Docker CLI was not found. Please start Docker Desktop and ensure docker is on PATH."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not (Test-Path $ComposeFile)) {
    throw "Compose file not found: $ComposeFile"
}

if (-not (Test-Path "third_party/flow_captcha_service/Dockerfile.headed")) {
    throw "third_party/flow_captcha_service is missing. Clone genz27/flow_captcha_service into third_party/flow_captcha_service first."
}

if (-not (Test-Path "config/setting.toml")) {
    Write-Step "config/setting.toml is missing; copying from config/setting_example.toml."
    Copy-Item -LiteralPath "config/setting_example.toml" -Destination "config/setting.toml"
}

Write-Step "Setting local config captcha_method and remote_browser_base_url."
Update-SettingTomlRemoteUrl -Path "config/setting.toml" -BaseUrl $RemoteBrowserBaseUrl

Stop-ConflictingContainer -Name "flow2api" -ExpectedProject $ProjectName
Stop-ConflictingContainer -Name "flow-captcha-service" -ExpectedProject $ProjectName

Write-Step "Starting unified Docker Compose project '$ProjectName'."
docker compose -p $ProjectName -f $ComposeFile up -d --build

Write-Step "Updating Flow2API runtime database remote_browser_base_url when available."
$dbUpdateScript = @"
import sqlite3
from pathlib import Path

db_path = Path('/app/data/flow.db')
if not db_path.exists():
    print('flow.db not found; skipped runtime DB update')
    raise SystemExit(0)

con = sqlite3.connect(str(db_path))
cur = con.cursor()
cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='captcha_config'")
if cur.fetchone() is None:
    print('captcha_config table not found; skipped runtime DB update')
    con.close()
    raise SystemExit(0)

cur.execute("SELECT COUNT(*) FROM captcha_config WHERE id=1")
if cur.fetchone()[0]:
    cur.execute(
        "UPDATE captcha_config SET captcha_method=?, remote_browser_base_url=?, remote_browser_timeout=? WHERE id=1",
        ('remote_browser', '$RemoteBrowserBaseUrl', 60),
    )
else:
    cur.execute(
        "INSERT INTO captcha_config (id, captcha_method, remote_browser_base_url, remote_browser_timeout) VALUES (1, ?, ?, ?)",
        ('remote_browser', '$RemoteBrowserBaseUrl', 60),
    )
con.commit()
con.close()
print('captcha_config remote_browser_base_url updated')
"@

$encodedScript = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($dbUpdateScript))
docker exec flow2api python -c "import base64; exec(base64.b64decode('$encodedScript').decode('utf-8'))"

Write-Step "Restarting flow2api so runtime config reloads."
docker compose -p $ProjectName -f $ComposeFile restart flow2api

Write-Step "Checking Docker service-name connectivity from flow2api."
Invoke-ContainerHttpGet -Container "flow2api" -Url "$RemoteBrowserBaseUrl/api/v1/health"

Write-Step "Stack status:"
docker compose -p $ProjectName -f $ComposeFile ps

Write-Step "Health checks:"
try {
    Invoke-HttpGetWithRetry -Uri "http://127.0.0.1:8060/api/v1/health" | ConvertTo-Json -Compress
    Invoke-HttpGetWithRetry -Uri "http://127.0.0.1:38000/health" | ConvertTo-Json -Compress
} catch {
    Write-Warning "Health check failed: $($_.Exception.Message)"
    exit 1
}

Write-Step "Done. Flow2API: http://127.0.0.1:38000 ; Captcha service: http://127.0.0.1:8060"
