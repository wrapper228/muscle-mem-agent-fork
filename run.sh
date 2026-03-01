#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Git pull ---
echo "Updating repository..."
git pull

# --- Load .env ---
ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found: $ENV_FILE"
    exit 1
fi
set -a
source "$ENV_FILE"
set +a

# --- Activate virtual environment ---
VENV_ACTIVATE="$SCRIPT_DIR/mem_venv/bin/activate"
if [[ ! -f "$VENV_ACTIVATE" ]]; then
    echo "Error: Virtual environment not found. Run: python -m venv mem_venv && source mem_venv/bin/activate && uv sync"
    exit 1
fi
source "$VENV_ACTIVATE"

# --- Check required variables ---
for var in ANTHROPIC_API_KEY GROUND_URL GROUND_API_KEY; do
    if [[ -z "${!var}" ]]; then
        echo "Error: Variable $var is not set in .env"
        exit 1
    fi
done

# --- Run agent ---
exec muscle-mem-agent \
    --enable_local_env \
    --provider anthropic \
    --model claude-sonnet-4-5 \
    --model_url https://api.anthropic.com \
    --model_temperature 0.0 \
    --ground_provider openai \
    --ground_model qwen3-vl-plus \
    --ground_url "$GROUND_URL" \
    --ground_api_key "$GROUND_API_KEY" \
    --grounding_width 1000 \
    --grounding_height 1000 \
    --image_ground_provider openai \
    --image_ground_model qwen3-vl-plus \
    --image_ground_url "$GROUND_URL" \
    --image_ground_api_key "$GROUND_API_KEY"
