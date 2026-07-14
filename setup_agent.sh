#!/usr/bin/env bash
set -e

echo "[1/10] APT 업데이트 및 pciutils, chromium 설치"
apt-get update -qq && apt-get install -y -qq pciutils chromium-browser > /dev/null 2>&1 \
    || apt-get install -y -qq pciutils chromium > /dev/null 2>&1

echo "[2/10] nvidia-smi 검사"
if nvidia-smi 2>/dev/null | grep -q "ERR!"; then
    echo "GPU 오류 발생, 강사에게 문의해주세요!"
    exit 1
fi
echo "[3/10] uv 설치"
curl -LsSf https://astral.sh/uv/0.10.3/install.sh | sh > /dev/null 2>&1
if [ -f "$HOME/.local/bin/env" ]; then
    source "$HOME/.local/bin/env"
else
    export PATH="$HOME/.local/bin:$PATH"
fi
export UV_CACHE_DIR=/tmp/.uv-cache
cat >> ~/.bashrc <<'EOF'

# NotoLab 환경 설정
export UV_CACHE_DIR=/tmp/.uv-cache
export PIP_CACHE_DIR=/tmp/.pip-cache
export HF_HOME=/tmp/hf
export HF_HUB_ENABLE_HF_TRANSFER=1
export OLLAMA_CONTEXT_LENGTH=16384
export OLLAMA_KEEP_ALIVE=1200
source /tmp/.venv/bin/activate
EOF

echo "[4/10] lab 디렉토리 생성"
cd /workspace
mkdir -p lab
cd lab

echo "[5/10] 가상환경 생성 (/tmp/.venv → 로컬 디스크)"
uv venv /tmp/.venv --seed -q
ln -sfn /tmp/.venv .venv
source /tmp/.venv/bin/activate

echo "[6/10] requirements 파일 다운로드 및 패키지 설치"
wget -qO requirements.txt \
https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/main/requirements_agent.txt
uv pip compile requirements.txt -o requirements-lock.txt -q
uv pip install -r requirements-lock.txt -q

echo "[7/10] Jupyter 커널 등록"
uv pip install ipykernel -q
python -m ipykernel install --name "NotoLab" --display-name "NotoLab" > /dev/null 2>&1

echo "[8/10] Ollama 설치"
curl -fsSL https://ollama.com/install.sh | sh > /dev/null 2>&1

echo "[9/10] Node.js 및 Playwright Chrome 설치 (Playwright MCP용)"
if ! command -v node > /dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null 2>&1
fi
# Playwright MCP의 기본 채널은 chrome이며, apt로 설치한 chromium은 인식하지 않는다.
npx -y playwright install --with-deps chrome > /dev/null 2>&1

echo "[10/10] AGENTS.md 생성"
cat > /workspace/lab/AGENTS.md <<'AGENTSEOF'
# Environment Context

- **가상환경**: `/tmp/.venv` (심볼릭 링크: `/workspace/lab/.venv`)
- **Jupyter 커널명**: `NotoLab`

## 캐시 경로 규칙

`/workspace`는 FUSE 네트워크 스토리지이므로 대량 I/O를 피해야 합니다.
캐시는 반드시 로컬 디스크(`/tmp`)를 사용하세요.

| 환경변수 | 경로 |
|----------|------|
| UV_CACHE_DIR | `/tmp/.uv-cache` |
| PIP_CACHE_DIR | `/tmp/.pip-cache` |
| HF_HOME | `/tmp/hf` |

## vLLM

vLLM은 가상환경에 직접 설치하지 말고 `uvx`로 실행하세요.

```bash
uvx vllm serve <model_name>
```

## Playwright MCP

브라우저는 `npx playwright install --with-deps chrome`으로 이미 설치되어 있습니다.
컨테이너는 root로 실행되고 디스플레이가 없으므로 아래 두 플래그가 필요합니다.

```bash
npx @playwright/mcp@latest --headless --no-sandbox
```

MCP 설정 JSON에 등록할 때도 `args`에 `--headless`, `--no-sandbox`를 동일하게 넣으세요.
AGENTSEOF

echo "✅ 환경 설정 완료"
echo "💡 가상환경 활성화: source /tmp/.venv/bin/activate"

# NotoLab aliases
grep -qxF "alias lab='cd /workspace/lab'" "$HOME/.bashrc" || echo "alias lab='cd /workspace/lab'" >> "$HOME/.bashrc"
grep -qxF "alias gpu='watch -d -n 0.5 nvidia-smi'" "$HOME/.bashrc" || echo "alias gpu='watch -d -n 0.5 nvidia-smi'" >> "$HOME/.bashrc"
grep -qxF "alias gpus='watch -d -n 0.5 \"nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits; echo; nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits\"'" "$HOME/.bashrc" || echo "alias gpus='watch -d -n 0.5 \"nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits; echo; nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits\"'" >> "$HOME/.bashrc"
