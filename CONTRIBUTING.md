# Contributing

## Setup

```bash
# Install dependencies
sudo apt install lua5.1 luarocks
sudo luarocks install busted
sudo luarocks install luacheck

# Run tests
busted spec/

# Run linter
luacheck filebernic/
```

## Code conventions

- Lua 5.1 compatible (LÖVE 11.x)
- Use `global_state` for app state, not bare globals
- 2-space indentation
- No trailing whitespace
- Lines max 120 chars (where practical)

## PR process

1. Create a branch from `main`
2. Make your changes
3. Run tests and linter
4. Update CHANGELOG.md
5. Submit a PR
