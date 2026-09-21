# clangd Role

Install [clangd](https://clangd.llvm.org/), the native Language Server Protocol (LSP) implementation for C, C++, and Objective-C-family projects. The role installs the platform package and makes the `clangd` executable available to editors and other LSP clients.

## Package mappings

The role uses the native package for each supported distribution:

| Distribution | Package | Installation details |
| --- | --- | --- |
| Arch Linux (`Archlinux`) | `clang` | The package provides `/usr/bin/clangd`. |
| Ubuntu (`Ubuntu`) | `clangd` | Installed with APT. |
| Fedora (`Fedora`) | `clang-tools-extra` | Installed with DNF. |
| macOS (`MacOSX`) | `llvm` | Installed with Homebrew. |

Linux package installation is guarded by the repository's package-install privilege check. When package installation is unavailable, the role leaves the system unchanged and reports that the package was skipped.

## macOS Homebrew setup

Homebrew's `llvm` formula is keg-only, so its binaries are not necessarily on `PATH`. The macOS tasks:

1. Resolve the formula prefix with `brew --prefix llvm`.
2. Ensure `~/.local/bin` exists.
3. Create or update the idempotent symlink `~/.local/bin/clangd` to the resolved `bin/clangd` binary.
4. Refuse to overwrite an existing regular file or conflicting symlink at that destination; replace unmanaged files manually.

Keeping the link in `~/.local/bin` lets editors find the same command without modifying Homebrew's keg-only layout. Ensure `~/.local/bin` is on your `PATH` when invoking `clangd` from a shell.

## Usage

Enable the role in `group_vars/all.yml` or run it explicitly:

```bash
dotfiles -t clangd
```

After installation, configure your editor's C/C++ LSP client to invoke `clangd`.
