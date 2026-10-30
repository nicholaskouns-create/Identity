"""GitHub adapter: compilation, commit pinning, CI log and artifact collection.

LIVE when `git` and the compilers are present. Compiler invocation is real;
this module never synthesizes a 'pass'.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

NAME = "github"


def status() -> dict:
    return {
        "adapter": NAME,
        "mode": "LIVE",
        "git": shutil.which("git") is not None,
        "lean": _version(["lean", "--version"]),
        "coqc": _version(["coqc", "--version"]),
        "python": _version(["python3", "--version"]),
    }


def _version(cmd: list[str]) -> str | None:
    exe = shutil.which(cmd[0])
    if not exe:
        return None
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None
    lines = (r.stdout or r.stderr).strip().splitlines()
    return lines[0] if lines else None


def head_commit(repo: Path) -> str:
    r = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else "UNKNOWN"


def worktree_clean(repo: Path) -> bool:
    r = subprocess.run(["git", "-C", str(repo), "status", "--porcelain"],
                       capture_output=True, text=True)
    return r.returncode == 0 and not r.stdout.strip()


def compile_proof(repo: Path, rel: str, timeout: int = 900) -> dict:
    """Compile one self-contained Lean or Coq file. Returns the real result."""
    src = repo / rel
    if not src.is_file():
        return {"file": rel, "exit_code": 127, "log": "file missing",
                "compiler": None, "compiler_version": None}

    if rel.endswith(".lean"):
        cmd, ver = ["lean"], _version(["lean", "--version"])
    elif rel.endswith(".v"):
        cmd, ver = ["coqc"], _version(["coqc", "--version"])
    else:
        return {"file": rel, "exit_code": 2, "log": "not a Lean or Coq file",
                "compiler": None, "compiler_version": None}

    if shutil.which(cmd[0]) is None:
        return {"file": rel, "exit_code": 127,
                "log": f"{cmd[0]} not installed in this environment",
                "compiler": cmd[0], "compiler_version": None}

    work = Path(tempfile.mkdtemp(prefix="monorail-"))
    try:
        dest = work / src.name
        shutil.copy(src, dest)
        proc = subprocess.run(cmd + [src.name], cwd=work, capture_output=True,
                              text=True, timeout=timeout)
        return {"file": rel, "exit_code": proc.returncode,
                "log": (proc.stdout + proc.stderr).strip()[:8000],
                "compiler": cmd[0], "compiler_version": ver}
    except subprocess.TimeoutExpired:
        return {"file": rel, "exit_code": 124, "log": f"timeout after {timeout}s",
                "compiler": cmd[0], "compiler_version": ver}
    finally:
        shutil.rmtree(work, ignore_errors=True)


def run_python(repo: Path, rel: str, timeout: int = 900) -> dict:
    src = repo / rel
    if not src.is_file():
        return {"file": rel, "exit_code": 127, "log": "file missing",
                "compiler": "python3", "compiler_version": None}
    proc = subprocess.run(["python3", "-I", str(src)], cwd=repo,
                          capture_output=True, text=True, timeout=timeout)
    return {"file": rel, "exit_code": proc.returncode,
            "log": (proc.stdout + proc.stderr).strip()[:8000],
            "compiler": "python3", "compiler_version": _version(["python3", "--version"])}


def run_url() -> str | None:
    """The CI run URL, when executing inside GitHub Actions. None locally."""
    srv = os.environ.get("GITHUB_SERVER_URL")
    repo = os.environ.get("GITHUB_REPOSITORY")
    rid = os.environ.get("GITHUB_RUN_ID")
    return f"{srv}/{repo}/actions/runs/{rid}" if srv and repo and rid else None
