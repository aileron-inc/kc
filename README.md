# Tools

A collection of small, focused CLI tools for development workflows.

## Tools

### [kc](./kc-rb/) - Keychain Manager
Securely manage secrets in macOS Keychain with namespace support.

```bash
gem install kc
kc save env:myproject < .env
kc load env:myproject > .env
```

### [gw](./gw-rb/) - Git Worktree Manager
Manage git worktrees with bare repository pattern (core/ and tree/ structure).

```bash
gem install gw
gw clone owner/repo
gw add owner/repo feature-branch
gw list
```

## Philosophy

Each tool follows these principles:

- **Small and focused** - Does one thing well
- **Simple CLI interface** - Easy to use and remember
- **Minimal dependencies** - Fast installation and execution
- **Consistent patterns** - Similar structure across all tools

## Documentation

See individual tool directories for detailed documentation:
- [kc](./kc-rb/README.md) - Keychain Manager
- [gw](./gw-rb/README.md) - Git Worktree Manager

## License

MIT License - see individual tools for details.
