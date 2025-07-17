# manage-arangodb.ps1
# PowerShell script to start/stop/restart ArangoDB Docker container using config from .env file

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------ Load .env Configuration ------------------
$envFilePath = ".env"

if (-Not (Test-Path $envFilePath)) {
    Write-Error "❌ .env file not found in current directory."
    exit 1
}

# Parse .env into environment variables
Get-Content $envFilePath | ForEach-Object {
    if ($_ -notmatch '^\s*#' -and $_ -match '^\s*(\w+)\s*=\s*(.+)\s*$') {
        $name, $value = $Matches[1], $Matches[2]
        [Environment]::SetEnvironmentVariable($name, $value)
    }
}

# ------------------ Validate Required Variables ------------------
$requiredVars = @(
    "CONTAINER_NAME",
    "ARANGO_IMAGE",
    "DB_VOLUME",
    "LISTEN_IP",
    "LISTEN_PORT",
    "ARANGO_ROOT_PASSWORD"
)

foreach ($var in $requiredVars) {
    if (-not [Environment]::GetEnvironmentVariable($var)) {
        Write-Error "❌ Missing required environment variable: $var"
        exit 1
    }
}

# ------------------ Helper: Get Env ------------------
function Get-Env($key) {
    return [Environment]::GetEnvironmentVariable($key)
}

# ------------------ Docker Control Functions ------------------

function Start-Arango {
    $name = Get-Env "CONTAINER_NAME"
    $image = Get-Env "ARANGO_IMAGE"
    $volume = Get-Env "DB_VOLUME"
    $ip = Get-Env "LISTEN_IP"
    $port = Get-Env "LISTEN_PORT"
    $password = Get-Env "ARANGO_ROOT_PASSWORD"

    Write-Host "🚀 Starting ArangoDB container: $name"

    $existing = docker ps -a --filter "name=^$name$" --format "{{.Names}}"

    if ($existing -eq $name) {
        Write-Host "🔄 Container exists. Starting..."
        docker start $name | Out-Null
    } else {
        Write-Host "📦 Creating and running container..."
        docker run -d `
            --name $name `
            --restart=always `
            -p "$ip`:$port`:8529" `
            -v "$volume:/var/lib/arangodb3" `
            -e "ARANGO_ROOT_PASSWORD=$password" `
            $image | Out-Null
    }

    Write-Host "✅ ArangoDB is running."
}

function Stop-Arango {
    $name = Get-Env "CONTAINER_NAME"
    Write-Host "🛑 Stopping ArangoDB container..."
    $running = docker ps --filter "name=^$name$" --format "{{.Names}}"
    if ($running -eq $name) {
        docker stop $name | Out-Null
        Write-Host "✅ Container stopped."
    } else {
        Write-Host "🤷 Container not running."
    }
}

function Restart-Arango {
    $name = Get-Env "CONTAINER_NAME"
    Write-Host "🔁 Restarting ArangoDB container..."
    docker restart $name | Out-Null
    Write-Host "✅ Container restarted."
}

function Status-Arango {
    $name = Get-Env "CONTAINER_NAME"
    Write-Host "📊 Status for ArangoDB container:"
    docker ps -a --filter "name=^$name$"
}

# ------------------ CLI Interface ------------------

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop", "restart", "status")]
    [string]$Command
)

switch ($Command) {
    "start"   { Start-Arango }
    "stop"    { Stop-Arango }
    "restart" { Restart-Arango }
    "status"  { Status-Arango }
}
