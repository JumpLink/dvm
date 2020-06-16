# DVM - Deno Version Manager

![shellcheck](https://github.com/ghosind/dvm/workflows/shellcheck/badge.svg)

Dvm is an nvm-like version manager for [Deno](https://deno.land/).

## Installation

There are two ways to install dvm now:

1. Install dvm from network via following command:

```sh
$ curl -o- https://raw.githubusercontent.com/ghosind/dvm/master/install.sh | bash
```

2. Download and extract release zip, and execute `install.sh` script to install dvm:

```sh
Download/dvm $ ./install.sh
```

## Getting Start

After installed dvm, you can use it to manage 

Use `dvm install <version>` command to download and install a specified version from the source.

```sh
$ dvm install v1.0.0
$ dvn install v0.42.0
```

Use `dvm uninstall <version>` command to uninstall a specified version.

```
$ dvm uninstall v0.39.0
$ dvm uninstall v1.0.0-rc
```

Use `dvm use [version]` command to link `deno` to the specified version by parameter or `.dvmrc` file.

```sh
# use v1.0.0
$ dvm use v1.0.0

# get version from .dvmrc file
# $ cat .dvmrc
# # v1.0.0
$ dvm use
```

Use `dvm current` command to display the current version of deno.

```sh
$ dvm current
# v1.0.0
```

Use `dvm ls` command to list all installed versions, and use `dvm ls-remote` to list all available versions from remote.

```sh
# list all installed versions
$ dvm ls
# list is an alias for ls command
$ dvm list

# list all available versions
$ dvm ls-remote
# list-remote is an alias for ls-remote command
$ dvm list-remote
```

## Uninstalling dvm

You can execute following command to uninstall dvm:

```sh
rm -rf "$DVM_DIR"
```

Edit shell config file (like `.bashrc` or `.zshrc`), and remove the following lines:

```sh
# Deno Version Manager
export DVM_DIR="$HOME/.dvm"
export DVM_BIN="$DVM_DIR/bin"
export PATH="$PATH:$DVM_BIN"
[ -f "$DVM_DIR/dvm.sh" ] && alias dvm="$DVM_DIR/dvm.sh"
```

## Contribution

1. Fork dvm project. ([https://github.com/ghosind/dvm](https://github.com/ghosind/dvm))
2. Create your Branch. (`git checkout -b features/someFeatures`)
3. Commit your Changes. (`git commit -m 'Add some features'`)
4. Push to the Branch. (`git push origin features/someFeatures`)
5. Create a new Pull Request.

## License

Distributed under the MIT License. See LICENSE file for more information.
