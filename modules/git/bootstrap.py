#!/usr/bin/env python3
"""Append one mise-style Git include block without taking over either global file."""

import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys


COMMON = (
    b"[include]\n"
    b"\tpath = ~/.config/git/dotfiles.gitconfig\n"
    b"\tpath = ~/.config/git/identity.gitconfig\n"
)
MAC = b"[include]\n\tpath = ~/.config/git/dotfiles-macos.gitconfig\n"


class UnsafeMigration(Exception):
    pass


def block(identifier, content):
    # Match native mise's block markers; do not leave an XDG compatibility include.
    return (
        ("# >>> mise:" + identifier + " >>> managed by mise — do not edit between markers\n").encode()
        + content
        + ("# <<< mise:" + identifier + " <<<\n").encode()
    )


def remove_block(data, identifier, contents):
    """Only retire a byte-exact block we shipped, never a customized lookalike."""
    starts = ("mise:" + identifier + " >>>").encode()
    ends = ("mise:" + identifier + " <<<").encode()
    if starts not in data and ends not in data:
        return data
    if data.count(starts) != 1 or data.count(ends) != 1:
        raise UnsafeMigration("ambiguous managed block markers")
    for content in contents:
        owned = block(identifier, content)
        offset = data.find(owned)
        if offset >= 0 and (offset == 0 or data[offset - 1 : offset] == b"\n"):
            return data[:offset] + data[offset + len(owned) :]
    raise UnsafeMigration("customized or damaged managed block; review it manually")


def fingerprint(info):
    return (info.st_dev, info.st_ino, info.st_mode, info.st_uid, info.st_nlink,
            info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def safe_parent(path, home):
    try:
        relative = path.parent.relative_to(home)
    except ValueError:
        raise UnsafeMigration("global config path is outside HOME") from None
    parent = home
    for part in (None, *relative.parts):
        if part is not None:
            parent = parent / part
        info = parent.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
            raise UnsafeMigration("global config parent is linked or not user-owned")
        if info.st_mode & 0o022:
            raise UnsafeMigration("global config parent is writable by another account")


def read_config(path, home):
    safe_parent(path, home)
    try:
        info = path.lstat()
    except FileNotFoundError:
        return None, b""
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
        raise UnsafeMigration("global config is linked, shared, or not user-owned")
    if info.st_mode & 0o022 or not info.st_mode & 0o200:
        raise UnsafeMigration("global config permissions are unsafe or read-only")
    # Do not print Git configuration, even when it cannot be migrated.
    with path.open("rb") as stream:
        if fingerprint(os.fstat(stream.fileno())) != fingerprint(info):
            raise UnsafeMigration("global config changed while opening it")
        data = stream.read()
    return info, data


def unchanged(path, info):
    try:
        current = path.lstat()
    except FileNotFoundError:
        return info is None
    return info is not None and fingerprint(current) == fingerprint(info)


def check_managed_includes(path, lock, home, expected):
    # Ask Git to parse only include paths, never print or enumerate private keys.
    result = subprocess.run(
        ["git", "config", "--no-includes", "--null", "--file", str(lock),
         "--get-regexp", r"^(include|includeif\..*)\.path$"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False,
    )
    if result.returncode not in (0, 1):
        raise UnsafeMigration("global config includes could not be parsed")
    managed = {
        (home / ".config/git" / name).resolve()
        for name in ("dotfiles.gitconfig", "identity.gitconfig", "dotfiles-macos.gitconfig")
    }
    matches = 0
    for record in result.stdout.split(b"\0"):
        if not record:
            continue
        value = Path(os.path.expanduser(os.fsdecode(record.partition(b"\n")[2])))
        if not value.is_absolute():
            value = path.parent / value
        if value.resolve() in managed:
            matches += 1
    if matches != expected:
        raise UnsafeMigration("an unmanaged include also loads managed Git settings; review it manually")


def migrate():
    if os.environ.get("GIT_CONFIG_GLOBAL") is not None:
        raise UnsafeMigration("GIT_CONFIG_GLOBAL redirects Git; unset it to migrate standard globals")
    if not os.environ.get("HOME") or not Path(os.environ["HOME"]).is_absolute():
        raise UnsafeMigration("HOME must be an absolute directory")
    if shutil.which("git") is None:
        raise UnsafeMigration("Git is unavailable")
    home = Path(os.environ["HOME"]).resolve(strict=True)
    target = home / ".gitconfig"
    xdg = Path(os.environ.get("XDG_CONFIG_HOME") or str(home / ".config"))
    if not xdg.is_absolute():
        raise UnsafeMigration("XDG_CONFIG_HOME must be absolute")
    legacy_paths = list(dict.fromkeys([home / ".config/git/config", xdg / "git/config"]))
    desired = COMMON + (MAC if sys.platform == "darwin" else b"")
    snapshots = {}
    updates = {}
    for path in [*legacy_paths, target]:
        # Missing legacy directories need no creation or mutation. A dangling link
        # still reaches the safety checks instead of being mistaken for absence.
        if path != target and not os.path.lexists(path):
            continue
        info, original = read_config(path, home)
        snapshots[path] = (info, original)
        cleaned = remove_block(original, "dotfiles", [COMMON, COMMON + MAC])
        cleaned = remove_block(cleaned, "dotfiles-macos", [MAC])
        if path == target:
            if cleaned and not cleaned.endswith(b"\n"):
                cleaned += b"\n"
            cleaned += block("dotfiles", desired)
        if cleaned != original:
            updates[path] = cleaned

    locks = {}
    try:
        # Use Git's conventional exclusive locks and prepare every candidate before
        # changing either file. Existing mode is retained; a fresh global is 0600.
        for path, (_, original) in snapshots.items():
            content = updates.get(path, original)
            lock = path.with_name(path.name + ".lock")
            fd = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            locks[path] = lock
            with os.fdopen(fd, "wb") as stream:
                stream.write(content)
                stream.flush()
                info = snapshots[path][0]
                os.fchmod(stream.fileno(), stat.S_IMODE(info.st_mode) if info else 0o600)
                os.fsync(stream.fileno())
            result = subprocess.run(
                ["git", "config", "--no-includes", "--file", str(lock), "--list"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
            )
            if result.returncode:
                raise UnsafeMigration("global config syntax is invalid")
            check_managed_includes(
                path, lock, home, (3 if sys.platform == "darwin" else 2) if path == target else 0
            )
        if any(not unchanged(path, info) for path, (info, _) in snapshots.items()):
            raise UnsafeMigration("global config changed during migration")
        # Publish the validated owner first so interruption cannot remove signing
        # policy. Until cleanup succeeds both blocks may load; a rerun retires the
        # obsolete one. Neither global file nor its unrelated content is deleted.
        for path in [target, *legacy_paths]:
            if path not in updates:
                continue
            os.replace(locks[path], path)
            del locks[path]
    finally:
        for lock in locks.values():
            lock.unlink(missing_ok=True)


def main():
    try:
        migrate()
    except UnsafeMigration as error:
        print(f"git: {error}; global include migration skipped", file=sys.stderr)
    except (OSError, RuntimeError):
        # Exception strings may include private filenames or config fragments.
        print("git: global include update failed (check paths, permissions and .lock files); skipped remaining changes, review and rerun", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
