# kc - Keychain Manager

A CLI tool to securely store and retrieve secrets from macOS Keychain with namespace support and automatic iCloud sync.

## Features

- 🔐 Securely store any secrets in macOS Keychain
- ☁️ **iCloud Keychain sync** - automatically sync secrets across all your Macs
- 🏷️ **Namespace support** - organize secrets by type (env, ssh, token, etc.)
- 🚀 Native implementation using FFI (no shell command overhead)
- 📦 Simple CLI interface
- 📋 List and filter secrets by namespace

## Installation

```bash
gem install kc
```

Or add to your Gemfile:

```ruby
gem 'kc'
```

## Usage

All commands require a **namespace** in the format `<namespace>:<name>`. Namespaces help organize different types of secrets.

### Save to Keychain

Read from stdin and save to keychain with namespace:

```bash
# Environment variables
kc save env:myproject < .env
cat .env | kc save env:production

# SSH keys
kc save ssh:id_rsa < ~/.ssh/id_rsa
kc save ssh:deploy-key < deploy_key

# API tokens
echo "ghp_xxxxxxxxxxxx" | kc save token:github
kc save token:openai < api_token.txt

# Certificates
kc save cert:ssl-cert < certificate.pem

# Custom namespaces
kc save my-app:config < config.json
```

### Load from Keychain

Output to stdout or redirect to file:

```bash
kc load env:myproject
kc load env:myproject > .env
kc load ssh:id_rsa > ~/.ssh/id_rsa
```

### List Entries

```bash
# List all entries
kc list

# List entries in specific namespace
kc list env:
kc list ssh:
kc list token:
```

### Delete from Keychain

```bash
kc delete env:myproject
kc delete ssh:id_rsa
kc delete token:github
```

### Use with direnv

In your `.envrc`:

```bash
# Load from keychain and export all variables
eval "$(kc load env:myproject | sed 's/^/export /')"

# Or restore .env file
kc load env:myproject > .env
source_env .env
```

## Commands

- `kc save <namespace>:<name>` - Read from stdin and save to keychain
- `kc load <namespace>:<name>` - Load from keychain and output to stdout  
- `kc delete <namespace>:<name>` - Delete entry from keychain
- `kc list [prefix]` - List all entries (optionally filter by prefix)

## Namespaces

Namespaces must contain only lowercase letters, numbers, and hyphens.

**Common namespaces:**
- `env:` - Environment variable files
- `ssh:` - SSH keys
- `token:` - API tokens
- `cert:` - Certificates
- `key:` - Encryption keys
- `secret:` - General secrets

You can create custom namespaces as needed.

## How it works

`kc` uses macOS Security framework via FFI to directly interact with the Keychain, avoiding shell command overhead. All entries are stored as **Internet Passwords** with:

- Server: `kc`
- Account: `<namespace>:<name>` (e.g., `env:myproject`)
- Protocol: HTTPS

### iCloud Keychain Sync

All secrets saved by `kc` are automatically synchronized across your Macs via **iCloud Keychain** (if enabled in System Settings). This means:

- 💾 Save a secret on one Mac → Access it instantly on all your other Macs
- 🔄 Changes and deletions are synced automatically
- 🔐 End-to-end encryption ensures your secrets remain secure during sync
- 🌐 No manual export/import needed

To verify sync is working, open **Keychain Access.app** and select the **iCloud** keychain. Look for entries with server name `kc`.

**Note:** Internet Passwords (used by `kc`) are automatically synced by macOS when iCloud Keychain is enabled. You don't need to do anything special!

## Full Workflow Example

```bash
# Save environment variables for different environments
kc save env:development < .env.development
kc save env:staging < .env.staging
kc save env:production < .env.production

# Save SSH keys
kc save ssh:personal < ~/.ssh/id_rsa
kc save ssh:work < ~/.ssh/id_rsa_work

# Save API tokens
echo "ghp_xxxxxxxxxxxx" | kc save token:github
echo "sk-xxxxxxxxxxxxxx" | kc save token:openai

# List all secrets
kc list
# => env:development
# => env:production
# => env:staging
# => ssh:personal
# => ssh:work
# => token:github
# => token:openai

# List only environment files
kc list env:
# => env:development
# => env:production
# => env:staging

# Load and use in direnv
# .envrc file:
eval "$(kc load env:development | sed 's/^/export /')"

# Or check if exists before loading
if kc list env:production > /dev/null 2>&1; then
  kc load env:production > .env
else
  echo "No production env found"
fi

# Clean up when done
kc delete env:development
kc delete ssh:personal
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

```bash
bundle install
bundle exec rspec
```

## Requirements

- macOS (uses macOS Keychain)
- Ruby 2.5 or later

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/aileron-inc/tools.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Kc project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/aileron-inc/tools/blob/main/CODE_OF_CONDUCT.md).
