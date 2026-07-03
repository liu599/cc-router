# Claude Code Router Config

Personal Claude Code Router configuration with custom transformers.

## Included

- `transformers/nvidia-glm-cleanup.js`
  - Removes unsupported `reasoning` from NVIDIA OpenAI-compatible requests.
  - Serializes outbound requests with a 5000 ms delay between requests.
- `transformers/gemini-reasoning.js`
  - Example Gemini reasoning transformer.
- `config.example.json`
  - Sanitized config template. Copy it to `config.json` locally and fill in your own API keys.

## Safety

The real `config.json`, backup configs, logs, pid files, and plugins are ignored because they can contain API keys or request data.

## Usage

1. Copy `config.example.json` to `config.json`.
2. Replace placeholder API keys.
3. Update the transformer path if your home directory is different.
4. Restart Claude Code Router:

```powershell
ccr restart
```

