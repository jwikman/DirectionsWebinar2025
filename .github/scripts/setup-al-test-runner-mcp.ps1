param(
    [string]$ClonePath = "/tmp/mcp-servers/al-test-runner-mcp",
    [string]$RepoUrl = "https://github.com/jwikman/al-test-runner-mcp",
    [string]$Branch = "w/johwik/mcp-on-linux"
)

# Use fixed path for GitHub Actions runner (ubuntu-latest uses /home/runner)
if ($env:GITHUB_ACTIONS -eq "true") {
    $ClonePath = "/home/runner/mcp-servers/al-test-runner-mcp"
    Write-Host "Running in GitHub Actions. Using fixed clone path: $ClonePath" -ForegroundColor Cyan
}

Write-Host "=== Setting up AL Test Runner MCP Server ===" -ForegroundColor Cyan

# Ensure parent directory exists
$parentDir = Split-Path $ClonePath -Parent
if (-not (Test-Path $parentDir)) {
    Write-Host "Creating parent directory: $parentDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

# Clone or update repository
if (Test-Path $ClonePath) {
    Write-Host "Repository already exists at $ClonePath. Updating..." -ForegroundColor Yellow
    Push-Location $ClonePath
    try {
        git fetch origin
        git checkout $Branch
        git pull origin $Branch
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "Cloning repository to $ClonePath..." -ForegroundColor Yellow
    git clone $RepoUrl $ClonePath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone repository"
    }

    Push-Location $ClonePath
    try {
        Write-Host "Checking out branch: $Branch" -ForegroundColor Yellow
        git checkout $Branch
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to checkout branch $Branch"
        }
    }
    finally {
        Pop-Location
    }
}

# Build the project
Push-Location $ClonePath
try {
    Write-Host "Installing npm dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        throw "npm install failed"
    }

    Write-Host "Building project..." -ForegroundColor Yellow
    npm run build
    if ($LASTEXITCODE -ne 0) {
        throw "npm build failed"
    }

    # Verify the MCP server can start
    Write-Host "Verifying MCP server can start..." -ForegroundColor Yellow
    $indexPath = Join-Path $ClonePath "build/index.js"

    if (-not (Test-Path $indexPath)) {
        throw "Build artifact not found: $indexPath"
    }

    # Start the MCP server in background and test it
    $mcpProcess = Start-Process -FilePath "node" -ArgumentList $indexPath -PassThru -NoNewWindow -RedirectStandardOutput "mcp-output.log" -RedirectStandardError "mcp-error.log"

    # Wait a bit for the server to start
    Start-Sleep -Seconds 3

    # Check if process is still running
    if ($mcpProcess.HasExited) {
        $errorContent = Get-Content "mcp-error.log" -Raw -ErrorAction SilentlyContinue
        throw "MCP server failed to start. Error: $errorContent"
    }

    Write-Host "MCP server started successfully (PID: $($mcpProcess.Id))" -ForegroundColor Green

    # Stop the MCP server
    Write-Host "Stopping MCP server..." -ForegroundColor Yellow
    Stop-Process -Id $mcpProcess.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    Write-Host "MCP server setup completed successfully!" -ForegroundColor Green
    Write-Host "MCP server location: $indexPath" -ForegroundColor Cyan
}
finally {
    Pop-Location
}
