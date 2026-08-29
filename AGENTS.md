# Repository Guidelines

## Project Structure & Module Organization

This repository maintains Python dependency manifests and NotoLab setup scripts. There is no application source tree, test suite, or bundled asset directory.

- `requirements_adv.txt`: advanced environment dependency set, using the PyTorch CUDA 13.0 index.
- `requirements_PEFT.txt`: PEFT-focused environment with Ollama setup support, using the PyTorch CUDA 13.0 index.
- `requirements_sLLM.txt`: small-LLM environment, using the PyTorch CUDA 13.0 index and including pinned `trl` and `transformers`.
- `requirements_agent.txt`: agent course environment (MCP, Slack, tracing/observability, browser tooling).
- `llama-cpp-v0.3.0-cuda86-linux-x64.tar.gz`: prebuilt CUDA llama.cpp binaries (Compute Capability 8.6) that `setup_sllm.sh` downloads from `main` at install time.
- `setup_adv.sh`, `setup_peft.sh`, `setup_sllm.sh`, `setup_agent.sh`: Linux/NotoLab bootstrap scripts that create `/workspace/lab`, install `uv`, build `/tmp/.venv`, install dependencies, register the `NotoLab` Jupyter kernel, and write runtime guidance. Each script downloads its matching `requirements_*.txt` from the `main` branch on GitHub at install time, so manifest edits take effect only after they are pushed to `main`. `setup_adv.sh` is the only variant that does not install Ollama; `setup_sllm.sh` also installs the prebuilt llama.cpp tarball from this repository, so it runs 10 steps instead of 9.

## Build, Test, and Development Commands

Use a Linux shell for setup scripts; they call `apt-get`, `curl`, `wget`, and `nvidia-smi`.

```bash
bash setup_adv.sh        # provision the advanced environment (no Ollama)
bash setup_peft.sh       # provision PEFT dependencies and Ollama
bash setup_sllm.sh       # provision small-LLM dependencies, llama.cpp, and Ollama
bash setup_agent.sh      # provision agent-course dependencies, chromium, and Ollama
uv pip compile requirements_sLLM.txt --index-strategy unsafe-best-match --emit-index-url -o requirements-lock.txt
```

For local dependency checks, create a temporary virtual environment and install the target manifest:

```bash
uv venv .venv
uv pip install -r requirements_sLLM.txt --index-strategy unsafe-best-match
```

`--index-strategy unsafe-best-match` is required on both compile and install: inside a requirements file `--extra-index-url https://pypi.org/simple` outranks the `--index-url` PyTorch index, so without it torch is pulled from PyPI's default wheel instead of the pinned `cu130` build, and `torch==2.11.0+cu130` in a lock file fails to resolve outright.

## Coding Style & Naming Conventions

Keep requirement files grouped by purpose with short comment headers and one package per line. Pin versions when compatibility matters, for example `transformers==5.14.1` or `setuptools<82.0`. Preserve variant naming: base files use `requirements*.txt`; setup scripts use `setup_*.sh` and should point to the matching requirement file.

Shell scripts should remain Bash-compatible, start with `#!/usr/bin/env bash` and `set -e`, and keep environment variables near the virtual environment setup.

## Testing Guidelines

There is no automated test framework. Validate changes with syntax and dependency-resolution checks:

```bash
bash -n setup_adv.sh setup_peft.sh setup_sllm.sh setup_agent.sh
uv pip compile requirements_sLLM.txt --index-strategy unsafe-best-match --emit-index-url -o requirements-lock.txt
python -c "import torch, transformers; print(torch.__version__)"
```

When changing CUDA, PyTorch, `transformers`, `trl`, or `bitsandbytes` versions, test in a GPU-backed NotoLab container.

## Commit & Pull Request Guidelines

Recent history mostly uses concise Conventional Commit-style messages such as `chore: pin transformers to 5.5.0`. Prefer `chore: ...` for dependency and setup updates.

Pull requests should describe which requirement variants changed, why versions were pinned or relaxed, and which validation commands were run. Link related issues when available and include setup log excerpts for environment changes.

## Security & Configuration Tips

Do not commit generated virtual environments, lock files created for one-off testing, API keys, Hugging Face tokens, or local `.claude/` settings. Keep cache paths in setup scripts on local temporary storage such as `/tmp` to avoid slow workspace I/O.
