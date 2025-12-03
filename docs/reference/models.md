# models

Display provider settings and available models.

## Usage

```bash
wfw models [show <model_id>]
```

## Subcommands

| Subcommand | Description |
|------------|-------------|
| (none) | List all provider settings and available models |
| `show <id>` | Show detailed info for a specific model |

## Output

The `wfw models` command displays configuration and available models for each provider.

### Anthropic Section

Always displayed. Shows:

- Current profile setting with source
- Model mappings for each tier (fast, balanced, deep)
- Available models from the Claude API

Example output:

```
Anthropic (Claude API)
  Profile: balanced                              [global]
    fast:     claude-haiku-4-5                   [builtin]
    balanced: claude-sonnet-4-5                  [builtin]
    deep:     claude-opus-4-5                    [builtin]

  Available Models:
    claude-sonnet-4-20250514      Claude Sonnet 4          2025-02-19
    claude-opus-4-20250514        Claude Opus 4            2025-02-19
    ...
```

### OpenAI-Compatible Section

Only shown when `OPENAI_BASE_URL` is configured. Displays:

- Base URL with source
- Server status (Online/Offline)
- Profile settings if OPENAI_MODEL_* values are configured
- Available models from the server

Example output:

```
OpenAI-Compatible Provider
  Base URL: http://localhost:1234/v1             [global]
  Status: Online (LM Studio)
  Profile: balanced                              [global]
    fast:     qwen3-14b-mlx                      [global]
    balanced: qwen/qwen3-30b-a3b-2507            [global]
    deep:     qwen/qwen3-next-80b                [global]

  Available Models:
    * qwen/qwen3-vl-30b           vlm    4bit   mlx    4096/262144  [tool_use]
      qwen/qwen3-next-80b         llm    4bit   mlx    262144       [tool_use]
      ...
```

### LM Studio Detection

Servers on port `:1234` are automatically detected as LM Studio and use the
richer `/api/v0/models` endpoint, which provides:

- **Load state**: Loaded models marked with `*`
- **Model type**: `llm`, `vlm`, or `embeddings`
- **Quantization**: e.g., `4bit`, `Q4_K_M`
- **Format**: `mlx`, `gguf`
- **Context length**: Shows `loaded/max` for loaded models
- **Capabilities**: e.g., `[tool_use]`

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show quick help |

## Examples

```bash
# List all provider settings and models
wfw models

# Show detailed info for a Claude model
wfw models show claude-sonnet-4-20250514

# Show detailed info for an LM Studio model
wfw models show qwen/qwen3-vl-30b
```

## Configuration

Models settings are configured via the [configuration cascade](../user-guide/configuration.md):

| Variable | Description |
|----------|-------------|
| `PROFILE` | Model tier: `fast`, `balanced`, `deep` |
| `MODEL_FAST` | Anthropic model for fast tier |
| `MODEL_BALANCED` | Anthropic model for balanced tier |
| `MODEL_DEEP` | Anthropic model for deep tier |
| `OPENAI_BASE_URL` | OpenAI-compatible server URL |
| `OPENAI_MODEL_FAST` | OpenAI model for fast tier |
| `OPENAI_MODEL_BALANCED` | OpenAI model for balanced tier |
| `OPENAI_MODEL_DEEP` | OpenAI model for deep tier |

## See Also

- [config](config.md) - View all configuration settings
- [Configuration Guide](../user-guide/configuration.md) - Configuration cascade details
