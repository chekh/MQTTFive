# Contributing to MQTTFive

## Code Style

- Follow existing MQL5 conventions in the codebase
- No external DLL dependencies — pure MQL5 only
- Use `snake_case` for functions and variables, `PascalCase` for classes
- Keep methods concise and well-structured
- Do not add comments unless requested

## Development Setup

1. Clone the repository
2. Symlink `Include/MQTTFive/` to your MT5 `MQL5/Include/MQTTFive/`
3. Open MetaEditor, compile, test

## Testing

- Start Mosquitto 5.0 on `127.0.0.1:1883`
- Run focused test scripts from `Scripts/MQTTFive/TestT01` through `TestT15`
- All 15 tests must pass before submitting a PR

## Pull Request Process

1. Create a branch from `dev` (not `main`)
2. Make your changes
3. Test with all 15 test scripts
4. Open PR against `dev`
5. Describe what changed and why

## Branch Structure

```
main    — stable releases only (tagged with version)
dev     — integration branch for next release
feat/*  — feature branches (from dev)
fix/*   — bugfix branches (from dev)
```

## Reporting Issues

Use the GitHub issue templates:
- [Bug Report](../../issues/new?template=bug_report.md)
- [Feature Request](../../issues/new?template=feature_request.md)
