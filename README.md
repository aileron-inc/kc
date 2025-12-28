# kc - Keychain Manager for direnv

A CLI tool to securely store and retrieve `.env` files from macOS Keychain, designed to work seamlessly with direnv.

## Features

- 🔐 Securely store `.env` files in macOS Keychain
- 🚀 Native implementation using FFI (no shell command overhead)
- 🎯 Designed for direnv integration
- 📦 Simple CLI interface

## Installation

```bash
gem install kc
```

Or add to your Gemfile:

```ruby
gem 'kc'
```

## Usage

### Save to Keychain

Read from stdin and save to keychain:

```bash
kc save 'myproject' < .env
cat .env | kc save 'myproject'
echo "API_KEY=secret" | kc save 'myproject'
```

### Load from Keychain

Output to stdout or redirect to file:

```bash
kc load 'myproject'
kc load 'myproject' > .env
```

### Delete from Keychain

```bash
kc delete 'myproject'
```

### Use with direnv

In your `.envrc`:

```bash
# Load from keychain and export all variables
eval "$(kc load myproject | sed 's/^/export /')"

# Or restore .env file
kc load myproject > .env
source_env .env
```

## Commands

- `kc save <name>` - Read from stdin and save to keychain
- `kc load <name>` - Load from keychain and output to stdout  
- `kc delete <name>` - Delete entry from keychain

## How it works

`kc` uses macOS Security framework via FFI to directly interact with the Keychain, avoiding shell command overhead. All entries are stored under:

- Service name: `kc`
- Account name: `<your-project-name>`

## Examples

```bash
# Save your .env
kc save 'myapp' < .env

# Load it back
kc load 'myapp' > .env

# Use in a script
if kc load 'myapp' > /dev/null 2>&1; then
  kc load 'myapp' > .env
else
  echo "No saved env found"
fi

# Delete when done
kc delete 'myapp'
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

Bug reports and pull requests are welcome on GitHub at https://github.com/aileron-inc/kc.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Kc project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/aileron-inc/kc/blob/master/CODE_OF_CONDUCT.md).
