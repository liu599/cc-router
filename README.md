# Claude Code Router

Runnable Claude Code Router 2.0.0 package files with local custom transformers.

## Included

- `dist/`
  - Published CCR runtime files copied from `@musistudio/claude-code-router@2.0.0`.
- `package.json`
  - Includes `start`, `restart`, and `stop` scripts for the bundled runtime.
- `transformers/nvidia-glm-cleanup.js`
  - Removes unsupported `reasoning` from NVIDIA OpenAI-compatible requests.
  - Serializes outbound requests with a 5000 ms delay between requests.
- `transformers/gemini-reasoning.js`
  - Example Gemini reasoning transformer.
- `config.example.json`
  - Sanitized config template. Copy it to `config.json` locally and fill in your own API keys.
- `docs/`
  - Upstream CCR README files from the published package.

## Safety

The real `config.json`, backup configs, logs, pid files, and plugins are ignored because they can contain API keys or request data.

## Usage

1. Copy `config.example.json` to `config.json`.
2. Replace placeholder API keys.
3. Update the transformer path if your home directory is different.
4. Start Claude Code Router from this repo:

```powershell
npm start
```

Or install/link the local CLI and use `ccr`:

```powershell
npm install -g .
ccr start
```

Restart an already running router:

```powershell
npm run restart
```

## Notes

This repository contains the runnable published package files, not the full upstream monorepo source tree. The published package does not include the original TypeScript workspace sources.
