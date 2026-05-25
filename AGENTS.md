# Repository Guidelines

## Project Structure & Module Organization

This repository maintains Python dependency manifests and NotoLab setup scripts. There is no application source tree, test suite, or bundled asset directory.

- `requirements.txt`: default dependency set, currently using the PyTorch CUDA 13.0 index.
- `requirements_adv.txt`: advanced environment dependency set.
- `requirements_PEFT.txt`: PEFT-focused environment with Ollama setup support.
- `requirements_sLLM.txt`: small-LLM environment, including pinned `trl` and `transformers`.
- `setup_adv.sh`, `setup_peft.sh`, `setup_sllm.sh`: Linux/NotoLab bootstrap scripts that create `/workspace/lab`, install `uv`, build `/tmp/.venv`, install dependencies, and write runtime guidance.

## Build, Test, and Development Commands

Use a Linux shell for setup scripts; they call `apt-get`, `curl`, `wget`, and `nvidia-smi`.

```bash
bash setup_adv.sh        # provision the advanced environment
bash setup_peft.sh       # provision PEFT dependencies and Ollama
bash setup_sllm.sh       # provision small-LLM dependencies and Ollama
uv pip compile requirements_sLLM.txt -o requirements-lock.txt
```

For local dependency checks, create a temporary virtual environment and install the target manifest:

```bash
uv venv .venv
uv pip install -r requirements.txt
```

## Coding Style & Naming Conventions

Keep requirement files grouped by purpose with short comment headers and one package per line. Pin versions when compatibility matters, for example `transformers==5.8.1` or `setuptools<82.0`. Preserve variant naming: base files use `requirements*.txt`; setup scripts use `setup_*.sh` and should point to the matching requirement file.

Shell scripts should remain Bash-compatible, start with `#!/usr/bin/env bash` and `set -e`, and keep environment variables near the virtual environment setup.

## Testing Guidelines

There is no automated test framework. Validate changes with syntax and dependency-resolution checks:

```bash
bash -n setup_adv.sh setup_peft.sh setup_sllm.sh
uv pip compile requirements.txt -o requirements-lock.txt
python -c "import torch, transformers; print(torch.__version__)"
```

When changing CUDA, PyTorch, `transformers`, `trl`, or `bitsandbytes` versions, test in a GPU-backed NotoLab container.

## Commit & Pull Request Guidelines

Recent history mostly uses concise Conventional Commit-style messages such as `chore: pin transformers to 5.5.0`. Prefer `chore: ...` for dependency and setup updates.

Pull requests should describe which requirement variants changed, why versions were pinned or relaxed, and which validation commands were run. Link related issues when available and include setup log excerpts for environment changes.

## Security & Configuration Tips

Do not commit generated virtual environments, lock files created for one-off testing, API keys, Hugging Face tokens, or local `.claude/` settings. Keep cache paths in setup scripts on local temporary storage such as `/tmp` to avoid slow workspace I/O.
