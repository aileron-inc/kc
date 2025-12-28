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

### Save .env to Keychain

```bash
# In your project directory with .env file
kc save myproject
```

This saves the entire `.env` file content to macOS Keychain under service name `kc` with account name `myproject`.

### Load .env from Keychain

```bash
kc load myproject
```

This outputs the stored `.env` content to stdout.

### Use with direnv

In your `.envrc`:

```bash
# Load .env from keychain and source it
eval "$(kc load myproject | sed 's/^/export /')"
```

Or simply dump it to a file:

```bash
kc load myproject > .env
```

## How it works

`kc` uses macOS Security framework via FFI to directly interact with the Keychain, avoiding shell command overhead. All entries are stored under:

- Service name: `kc`
- Account name: `<your-project-name>`

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
