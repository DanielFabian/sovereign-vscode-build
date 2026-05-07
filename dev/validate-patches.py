#!/usr/bin/env python3
"""Validate the active VS Code patch stack without mutating a checkout.

This intentionally avoids shell orchestration. All git invocations use
``subprocess.run(..., shell=False, timeout=...)`` so missing inputs, failed
patches, or wedged git operations become bounded diagnostics instead of an
interactive terminal séance. Computers, famously, love séances.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, NoReturn


EX_USAGE = 64
EX_DATAERR = 65
EX_NOINPUT = 66
EX_SOFTWARE = 70

DEFAULT_TIMEOUT_SECONDS = 120


class ValidationError(Exception):
    def __init__(self, code: int, message: str):
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class PatchVariables:
    app_name: str
    app_display_name: str
    app_name_lc: str
    assets_repository: str
    binary_name: str
    gh_repo_path: str
    global_dirname: str
    org_name: str
    release_version: str
    tunnel_app_name: str

    @classmethod
    def from_environment(cls) -> "PatchVariables":
        app_name = os.environ.get("APP_NAME", "SovereignCode")
        app_display_name = os.environ.get("APP_DISPLAY_NAME", "Sovereign Code")
        binary_name = os.environ.get("BINARY_NAME", "scode")
        quality = os.environ.get("VSCODE_QUALITY", "stable")

        base_global_dirname = os.environ.get("GLOBAL_DIRNAME", binary_name)
        global_dirname = f"{base_global_dirname}-insiders" if quality == "insider" else base_global_dirname

        return cls(
            app_name=app_name,
            app_display_name=app_display_name,
            app_name_lc=app_name.lower(),
            assets_repository=os.environ.get("ASSETS_REPOSITORY", "DanielFabian/sovereign-vscode-build"),
            binary_name=binary_name,
            gh_repo_path=os.environ.get("GH_REPO_PATH", "DanielFabian/sovereign-vscode-build"),
            global_dirname=global_dirname,
            org_name=os.environ.get("ORG_NAME", "DanielFabian"),
            release_version=os.environ.get("RELEASE_VERSION", "0.0.0-validation"),
            tunnel_app_name=os.environ.get("TUNNEL_APP_NAME", f"{binary_name}-tunnel"),
        )

    def replacements(self) -> dict[str, str]:
        return {
            "!!APP_NAME!!": self.app_display_name,
            "!!APP_DISPLAY_NAME!!": self.app_display_name,
            "!!APP_NAME_LC!!": self.app_name_lc,
            "!!ASSETS_REPOSITORY!!": self.assets_repository,
            "!!BINARY_NAME!!": self.binary_name,
            "!!GH_REPO_PATH!!": self.gh_repo_path,
            "!!GLOBAL_DIRNAME!!": self.global_dirname,
            "!!ORG_NAME!!": self.org_name,
            "!!RELEASE_VERSION!!": self.release_version,
            "!!TUNNEL_APP_NAME!!": self.tunnel_app_name,
        }


@dataclass(frozen=True)
class RunResult:
    stdout: str
    stderr: str


def eprint(message: str) -> None:
    print(f"validate-patches: {message}", file=sys.stderr)


def fail(code: int, message: str) -> NoReturn:
    raise ValidationError(code, message)


def env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        return int(raw)
    except ValueError:
        fail(EX_USAGE, f"{name} must be an integer, got {raw!r}")


def run(
    args: Iterable[str | os.PathLike[str]],
    *,
    cwd: Path | None = None,
    timeout: int,
    failure_code: int = EX_SOFTWARE,
    failure_context: str | None = None,
) -> RunResult:
    command = [os.fspath(arg) for arg in args]
    try:
        completed = subprocess.run(
            command,
            cwd=os.fspath(cwd) if cwd else None,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=False,
            timeout=timeout,
            check=False,
        )
    except FileNotFoundError as exc:
        fail(EX_NOINPUT, f"required executable not found: {command[0]} ({exc})")
    except subprocess.TimeoutExpired:
        context = f" while {failure_context}" if failure_context else ""
        fail(failure_code, f"command timed out after {timeout}s{context}: {' '.join(command)}")

    if completed.returncode != 0:
        context = f" while {failure_context}" if failure_context else ""
        details = format_subprocess_output(completed.stdout, completed.stderr)
        fail(failure_code, f"command failed with exit code {completed.returncode}{context}: {' '.join(command)}{details}")

    return RunResult(stdout=completed.stdout, stderr=completed.stderr)


def format_subprocess_output(stdout: str, stderr: str) -> str:
    parts: list[str] = []
    if stdout.strip():
        parts.append(f"\n--- stdout ---\n{stdout.rstrip()}")
    if stderr.strip():
        parts.append(f"\n--- stderr ---\n{stderr.rstrip()}")
    return "".join(parts)


def is_git_checkout(path: Path, timeout: int) -> bool:
    if not path.is_dir():
        return False
    try:
        run(
            ["git", "-C", path, "rev-parse", "--is-inside-work-tree"],
            timeout=timeout,
            failure_code=EX_NOINPUT,
            failure_context=f"checking git checkout {path}",
        )
        return True
    except ValidationError:
        return False


def discover_vscode_dir(repo_root: Path, explicit: str | None, timeout: int) -> Path:
    candidates = [Path(explicit)] if explicit else [repo_root / "vscode", repo_root.parent / "vscode"]

    for candidate in candidates:
        path = candidate.expanduser().resolve()
        if is_git_checkout(path, timeout):
            return path

    if explicit:
        fail(EX_NOINPUT, f"not a git checkout: {Path(explicit).expanduser()}")
    fail(EX_NOINPUT, f"no VS Code checkout found; looked for {repo_root / 'vscode'} and {repo_root.parent / 'vscode'}")


def active_patches(patch_dir: Path) -> list[Path]:
    if not patch_dir.is_dir():
        fail(EX_NOINPUT, f"patch directory does not exist: {patch_dir}")

    patches = sorted(patch_dir.glob("*.patch"), key=lambda path: path.name)
    if not patches:
        fail(EX_DATAERR, f"no active patches found in {patch_dir}/*.patch")
    return patches


def materialize_patch(source: Path, destination: Path, variables: PatchVariables) -> None:
    text = source.read_text(encoding="utf-8")
    for placeholder, value in variables.replacements().items():
        text = text.replace(placeholder, value)
    destination.write_text(text, encoding="utf-8")


def validate_ref(vscode_dir: Path, git_ref: str, timeout: int) -> str:
    run(
        ["git", "-C", vscode_dir, "rev-parse", "--verify", "--quiet", f"{git_ref}^{{commit}}"],
        timeout=timeout,
        failure_code=EX_USAGE,
        failure_context=f"resolving ref {git_ref}",
    )
    short = run(
        ["git", "-C", vscode_dir, "rev-parse", "--short", f"{git_ref}^{{commit}}"],
        timeout=timeout,
        failure_code=EX_USAGE,
        failure_context=f"shortening ref {git_ref}",
    )
    return short.stdout.strip()


def validate_patches(args: argparse.Namespace, repo_root: Path) -> None:
    patch_dir = Path(args.patch_dir).expanduser().resolve() if args.patch_dir else repo_root / "patches"
    patches = active_patches(patch_dir)

    if args.list:
        print(f"validate-patches: active patch order ({len(patches)} patches)")
        for patch in patches:
            print(f"  {patch.name}")
        return

    vscode_dir = discover_vscode_dir(repo_root, args.vscode_dir, args.timeout)
    short_ref = validate_ref(vscode_dir, args.ref, args.timeout)
    variables = PatchVariables.from_environment()

    tmp_dir = Path(tempfile.mkdtemp(prefix="sovereign-patch-validate."))
    worktree_dir = tmp_dir / "vscode"
    materialized_dir = tmp_dir / "patches"
    materialized_dir.mkdir(parents=True)

    keep_temp = bool(args.keep_temp)
    try:
        print(f"validate-patches: source checkout: {vscode_dir}")
        print(f"validate-patches: source ref:      {short_ref}")
        print(f"validate-patches: patch dir:       {patch_dir}")
        print(f"validate-patches: active patches:  {len(patches)}")
        print(f"validate-patches: temp worktree:   {worktree_dir}")

        run(
            ["git", "-C", vscode_dir, "worktree", "add", "--detach", "--quiet", worktree_dir, f"{args.ref}^{{commit}}"],
            timeout=args.timeout,
            failure_context="creating temporary worktree",
        )

        for patch in patches:
            materialized_patch = materialized_dir / patch.name
            materialize_patch(patch, materialized_patch, variables)

            print(f"validate-patches: applying {patch.name}")
            run(
                ["git", "-C", worktree_dir, "apply", "--check", "--ignore-whitespace", materialized_patch],
                timeout=args.timeout,
                failure_code=EX_DATAERR,
                failure_context=f"checking patch {patch.name}",
            )
            run(
                ["git", "-C", worktree_dir, "apply", "--ignore-whitespace", materialized_patch],
                timeout=args.timeout,
                failure_code=EX_DATAERR,
                failure_context=f"applying patch {patch.name}",
            )

        print(f"validate-patches: ok, {len(patches)} active patches apply cleanly")
    finally:
        if keep_temp:
            eprint(f"kept temp worktree: {worktree_dir}")
        else:
            if worktree_dir.exists():
                try:
                    run(
                        ["git", "-C", vscode_dir, "worktree", "remove", "--force", worktree_dir],
                        timeout=args.timeout,
                        failure_context="removing temporary worktree",
                    )
                except ValidationError as exc:
                    eprint(str(exc))
                    shutil.rmtree(worktree_dir, ignore_errors=True)

            shutil.rmtree(tmp_dir, ignore_errors=True)


def parser(repo_root: Path) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="validate-patches.py",
        description="Validate active root patches (patches/*.patch) in a temporary VS Code git worktree.",
    )
    parser.add_argument("--vscode-dir", default=os.environ.get("VSCODE_DIR"), help="VS Code git checkout; defaults to ./vscode, then ../vscode")
    parser.add_argument("--patch-dir", default=os.environ.get("PATCH_DIR", str(repo_root / "patches")), help="Patch directory; default: ./patches")
    parser.add_argument("--ref", default=os.environ.get("VSCODE_REF", "HEAD"), help="Git ref/commit to validate against; default: HEAD")
    parser.add_argument("--timeout", type=int, default=env_int("VALIDATE_PATCHES_TIMEOUT", DEFAULT_TIMEOUT_SECONDS), help=f"Per-git-command timeout in seconds; default: {DEFAULT_TIMEOUT_SECONDS}")
    parser.add_argument("--keep-temp", action="store_true", help="Keep the temporary worktree for inspection")
    parser.add_argument("--list", action="store_true", help="List active patches and exit without requiring a VS Code checkout")
    return parser


def main(argv: list[str]) -> int:
    repo_root = Path(__file__).resolve().parents[1]

    try:
        args = parser(repo_root).parse_args(argv)

        if args.timeout <= 0:
            eprint("--timeout must be a positive integer")
            return EX_USAGE

        validate_patches(args, repo_root)
        return 0
    except ValidationError as exc:
        eprint(str(exc))
        return exc.code
    except KeyboardInterrupt:
        eprint("validation interrupted")
        return EX_SOFTWARE


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))