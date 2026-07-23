# image-gen-script Skill

This repository implements a coding agent skill for generating raster images via the bundled cross-platform scripts.

It is not a general image model integration repository. The skill is designed to:

- use the included shell and PowerShell scripts only
- require a valid `PACKY_IMAGE_API_KEY` environment variable or explicit key argument
- produce PNG output from the Packy image generation API
- never fall back to built-in image generation tools
- support text-to-image generation only

## Repository structure

- `SKILL.md` - skill metadata and usage guidance for the agent.
- `agents/openai.yaml` - agent interface definition.
- `scripts/image-gen.sh` - Bash shell script for Linux/macOS.
- `scripts/image-gen.ps1` - PowerShell script for Windows.

## How the skill works

1. Determine the prompt, size, quality, count, and output basename.
2. Select the appropriate script for the current OS.
3. Run the script from the destination directory so relative output files are created there.
4. Use `PACKY_IMAGE_API_KEY` unless the user explicitly supplies `--api-key` / `-ApiKey`.
5. Return generated PNG file paths and a brief summary of the selected size/quality.

## Usage

### Bash (Linux/macOS)

```bash
bash scripts/image-gen.sh \
  --prompt "A neon cityscape at dusk" \
  --size 2k \
  --quality high \
  --count 2 \
  --output "cityscape"
```

### PowerShell (Windows)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/image-gen.ps1 \
  -Prompt "A neon cityscape at dusk" \
  -Size 2k \
  -Quality high \
  -Count 2 \
  -Output "cityscape"
```

## Supported parameters

### Shell script

- `-p`, `--prompt`: Prompt text (required)
- `-s`, `--size`: `1k` | `2k` | `4k` | `WIDTHxHEIGHT` (default: `1k`)
- `-q`, `--quality`: `high` | `medium` | `low` (default: `medium`)
- `-n`, `--count`: Number of images (default: `1`)
- `-o`, `--output`: Output basename (default: `image`)
- `-k`, `--api-key`: Optional API key override

### PowerShell script

- `-Prompt`: Prompt text (required)
- `-Size`: `1k`, `2k`, `4k`, or `WIDTHxHEIGHT`
- `-Quality`: `high`, `medium`, `low`
- `-Count`: Number of images
- `-Output`: Output basename
- `-ApiKey`: Optional API key override

## Output files

- Single image: `<basename>.png`
- Multiple images: `<basename>-1.png`, `<basename>-2.png`, ...

Both scripts accept relative or absolute output prefixes and create missing directories automatically.

## API key

Set `PACKY_IMAGE_API_KEY` in the environment, or pass an explicit key to the script.

Example:

```bash
export PACKY_IMAGE_API_KEY="your_api_key_here"
```

## Notes for skill use

- Do not use this repository for image editing or transformation tasks.
- If the user requests an existing image to be modified, explain that this skill only supports text-to-image generation.
- If a script or request fails, report the exact error and stop.
