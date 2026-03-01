$ErrorActionPreference = "Stop"

# --- Load .env ---
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Error ".env file not found: $envFile"
    exit 1
}
Get-Content $envFile -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^\s*([^#\s][^=]*)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
    }
}

# --- Activate virtual environment ---
$venvActivate = Join-Path $PSScriptRoot "mem_venv\Scripts\Activate.ps1"
if (-not (Test-Path $venvActivate)) {
    Write-Error "Virtual environment not found: $venvActivate"
    exit 1
}
. $venvActivate

# --- Check required variables ---
foreach ($var in @("ANTHROPIC_API_KEY", "GROUND_URL", "GROUND_API_KEY", "IMAGE_GROUND_URL", "IMAGE_GROUND_API_KEY")) {
    $val = [System.Environment]::GetEnvironmentVariable($var, "Process")
    if ([string]::IsNullOrWhiteSpace($val)) {
        Write-Error "Variable $var is not set in .env"
        exit 1
    }
}

# --- Run agent ---
& "$PSScriptRoot\mem_venv\Scripts\muscle-mem-agent.exe" `
    --provider anthropic `
    --model claude-opus-4-5 `
    --model_url https://api.anthropic.com `
    --ground_provider openai `
    --ground_model qwen3-vl-plus `
    --ground_url $env:GROUND_URL `
    --ground_api_key $env:GROUND_API_KEY `
    --grounding_width 1000 `
    --grounding_height 1000 `
    --image_ground_provider openai `
    --image_ground_model qwen3-vl-plus `
    --image_ground_url $env:GROUND_URL `
    --image_ground_api_key $env:GROUND_API_KEY


# & "$PSScriptRoot\mem_venv\Scripts\muscle-mem-agent.exe" `
#     --provider anthropic `
#     --model claude-opus-4-5 `
#     --ground_provider openai `
#     --ground_model qwen3-vl-plus `
#     --ground_url $env:GROUND_URL `
#     --ground_api_key $env:GROUND_API_KEY `
#     --grounding_width 1000 `
#     --grounding_height 1000 `
#     --image_ground_provider openai `
#     --image_ground_model doubao-seed-1-8-251228 `
#     --image_ground_url $env:IMAGE_GROUND_URL `
#     --image_ground_api_key $env:IMAGE_GROUND_API_KEY
