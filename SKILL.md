---
name: image-gen-skill
description: Generate new raster images exclusively with the bundled cross-platform scripts. Use for every request to create, generate, illustrate, render, or produce a bitmap image or visual asset from a text prompt. Select the Bash script on Linux or macOS and the PowerShell script on Windows. Do not use Codex's built-in image generation tool, even as a fallback. This skill does not edit existing images.
---

# Image Gen Script

Generate images only through the scripts bundled with this skill. Never call Codex's built-in image generation tool or another image-generation service.

## Workflow

1. Determine the destination directory, output basename, size, quality, count, and prompt.
2. Select the bundled script for the current operating system.
3. Run the script from the destination directory so relative output paths land there.
4. Rely on the inherited PACKY_IMAGE_API_KEY environment variable. Never print, inspect, log, or expose its value. Do not pass an API key argument unless the user explicitly supplies a key for that invocation.
5. Confirm that the expected PNG files exist and inspect them when visual verification matters.
6. Return the generated file paths and briefly report the selected size and quality.

## Linux And macOS

Require Bash, curl, and standard system utilities. Run:

    bash "<skill-dir>/scripts/image-gen.sh" \
      --prompt "<prompt>" \
      --size <1k|2k|4k|WIDTHxHEIGHT> \
      --quality <high|medium|low> \
      --count <positive-integer> \
      --output <basename>

## Windows

Use Windows PowerShell 5.1 or later and .NET only. Run:

    powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "<skill-dir>\scripts\image-gen.ps1" \
      -Prompt "<prompt>" \
      -Size <1k|2k|4k|WIDTHxHEIGHT> \
      -Quality <high|medium|low> \
      -Count <positive-integer> \
      -Output <basename>

## Defaults And Output

Use 1k, medium, and a count of 1 when the user does not specify them. Choose a short, descriptive output basename. Preserve a requested aspect ratio with an explicit WIDTHxHEIGHT value when appropriate.

For one image, expect <basename>.png. For multiple images, expect <basename>-1.png, <basename>-2.png, and so on. Both scripts accept a relative or absolute output prefix and create missing parent directories.

## Failure Handling

If the script, network request, credentials, or output validation fails, report the concrete error and stop. Never fall back to Codex's built-in image generation tool.

For requests that edit or transform an existing image, explain that this skill supports text-to-image generation only; do not silently substitute another image tool.
