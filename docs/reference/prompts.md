# wfw prompts

List and manage system prompt files.

## Usage

```
wfw prompts [show|edit <name>]
```

## Subcommands

| Command | Description |
|---------|-------------|
| `prompts` | List available prompts (default) |
| `prompts show <name>` | Display prompt in pager |
| `prompts edit <name>` | Open prompt in editor |

## Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Quick help |

## Prompt Location

System prompts are stored in `$WIREFLOW_PROMPT_PREFIX` (default: `~/.config/wireflow/prompts/system/`).

Each prompt is a `.txt` file loaded via the `SYSTEM_PROMPTS` config array.

## Examples

```bash
# List all available prompts
wfw prompts

# Preview a prompt
wfw prompts show base

# Edit a prompt
wfw prompts edit research

# Create new prompt (opens editor with template)
wfw prompts edit my-custom
```

## Prompt Format

New prompts are created with this XML template:

```xml
<system-component>
  <metadata>
    <name>prompt-name</name>
    <version>1.0</version>
  </metadata>
  <content>
    Your prompt content here.
  </content>
</system-component>
```

## See Also

- [Prompts & Templates](../user-guide/prompts.md) - Full prompts guide
- [`wfw config`](config.md) - View SYSTEM_PROMPTS setting
