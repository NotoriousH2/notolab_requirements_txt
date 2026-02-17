# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repo manages Python environment setup for GPU-based AI/ML training courses. It provides per-course requirements files and one-click setup shell scripts designed to run on cloud GPU instances (e.g., `/workspace` directory on notebook platforms).

## Course Tracks

| Track | Requirements File | Setup Script | Ollama |
|-------|------------------|--------------|--------|
| **ADV** (심화) | `requirements_adv.txt` | `setup_adv.sh` | No |
| **PEFT** (파인튜닝) | `requirements_PEFT.txt` | `setup_peft.sh` | Yes |
| **sLLM** (소형 LLM) | `requirements_sLLM.txt` | `setup_sllm.sh` | Yes |

## Architecture

All three tracks share a common dependency base:
- **PyTorch 2.8.0** with CUDA 12.8 (`--index-url https://download.pytorch.org/whl/cu128`)
- **LangChain** ecosystem (core, community, openai, google_genai, huggingface, tavily, langgraph)
- **Hugging Face** ecosystem (transformers, peft, trl, accelerate, datasets, hf_transfer)
- **OpenAI** (openai, tiktoken)
- Common utilities: tensorboard, seaborn, pandas, rich, pymupdf

Key differences between tracks:
- **PEFT/sLLM** include: `langchain_ollama`, `langchain_qdrant`, `ragas`, `sacrebleu`, `rank_bm25`, `kiwipiepy` (pinned), `ipywidgets`
- **ADV** includes: `tavily-python` (explicit), `kiwipiepy` (unpinned); omits Ollama-related and advanced RAG evaluation packages

## Setup Script Pattern

Each `setup_*.sh` follows the same structure:
1. APT update + pciutils install
2. GPU health check via `nvidia-smi`
3. CUDA version validation (>= 12.8 required)
4. Create `/workspace/실습/` working directory
5. Download the corresponding `requirements_*.txt` from this repo's GitHub `main` branch
6. `pip install -r requirements.txt`
7. (PEFT/sLLM only) Install Ollama with context/keep-alive env vars

## Conventions

- Requirements files use Korean comments for section headers
- Setup scripts fetch requirements from `https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/main/` — changes pushed to `main` are immediately consumed by students running the setup scripts
- PyTorch versions are pinned with CUDA-specific index URL; other packages are mostly unpinned except `transformers`, `ragas`, and `kiwipiepy` where compatibility matters
