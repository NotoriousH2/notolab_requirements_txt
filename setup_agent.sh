#!/usr/bin/env bash
set -e

# 이 스크립트가 참조할 저장소 버전(태그/브랜치).
# 릴리스로 배포된 사본에는 수업 시점 태그가 박혀 있고, main 사본은 최신을 따라간다.
# 다른 버전으로 설치하려면: NOTOLAB_REF=<태그> bash setup_agent.sh
NOTOLAB_REF="${NOTOLAB_REF:-main}"

# 다른 프로세스(Claude Code 배치 설치 등)가 apt를 점유 중이면 즉시 실패하지 말고
# 최대 120초 dpkg 락을 대기한다. 이 스크립트의 모든 apt(nodesource/playwright 내부 호출 포함)에 적용된다.
mkdir -p /etc/apt/apt.conf.d && echo 'DPkg::Lock::Timeout "120";' > /etc/apt/apt.conf.d/99lock-timeout

echo "[1/10] nvidia-smi 검사"
if nvidia-smi 2>/dev/null | grep -q "ERR!"; then
    echo "GPU 오류 발생, 강사에게 문의해주세요!"
    exit 1
fi

echo "[2/10] APT 일괄 설치 (pciutils, chromium, Node.js, Playwright Chrome)"
# ⚠️ 이 스크립트의 apt 작업은 전부 이 단계에 모은다.
#    이후 단계(uv/venv/requirements/llama.cpp/ollama)는 apt를 쓰지 않으므로,
#    "✅ APT 완료" 마커 이후에는 Claude Code 배치 설치(apt 사용)를
#    병렬로 돌려도 dpkg 락 충돌이 없다.
apt-get update -qq && apt-get install -y -qq pciutils chromium-browser > /dev/null 2>&1 \
    || apt-get install -y -qq pciutils chromium > /dev/null 2>&1
if ! command -v node > /dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null 2>&1
fi
# Playwright MCP의 기본 채널은 chrome이며, apt로 설치한 chromium은 인식하지 않는다.
# chrome 채널은 --with-deps가 내부적으로 apt(google-chrome-stable + libs)를 쓰므로 이 블록에 둔다.
npx -y playwright install --with-deps chrome > /dev/null 2>&1
echo "✅ APT 완료 — 이후 단계는 apt 미사용 (Claude Code 병렬 설치 시작 가능)"

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

echo "[6/10] requirements 파일 다운로드 및 패키지 설치 (버전: $NOTOLAB_REF)"
wget -qO requirements.txt \
"https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/$NOTOLAB_REF/requirements_agent.txt"
# 릴리스에 동봉된 lock이 있으면 그대로 설치해 수업 시점 환경을 재현한다.
# lock이 없거나 깨졌으면 manifest에서 다시 해석한다 (NOTOLAB_LOCK=0으로 강제 가능).
LOCK_URL="https://github.com/NotoriousH2/notolab_requirements_txt/releases/download/$NOTOLAB_REF/requirements-lock-agent.txt"
if [ "${NOTOLAB_LOCK:-1}" = "1" ] && curl -fsSL "$LOCK_URL" -o requirements-lock.txt 2>/dev/null; then
    echo "  lock 사용: requirements-lock-agent.txt ($NOTOLAB_REF)"
else
    echo "  lock 없음 — manifest에서 해석"
    uv pip compile requirements.txt -o requirements-lock.txt -q
fi
uv pip install -r requirements-lock.txt -q

echo "[7/10] Jupyter 커널 등록"
uv pip install ipykernel -q
python -m ipykernel install --name "NotoLab" --display-name "NotoLab" > /dev/null 2>&1

echo "[8/10] llama.cpp 설치"
LLAMACPP_URL="https://github.com/NotoriousH2/notolab_requirements_txt/releases/download/llama-cpp-v0.3.0-cuda86/llama-cpp-v0.3.0-cuda86-linux-x64.tar.gz"
LLAMACPP_MIN_CC=86   # 배포 바이너리는 sm_86(Compute Capability 8.6)으로 빌드됨
LLAMACPP_MANUAL=0

# 장착된 GPU 중 가장 낮은 Compute Capability를 정수로 환산 (8.6 -> 86, 12.0 -> 120)
MIN_CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null \
    | awk -F'[.]' 'NF==2 {v=$1*10+$2; if (m=="" || v<m) m=v} END {if (m!="") print m}')

if [ -z "$MIN_CC" ]; then
    LLAMACPP_MANUAL=1
    echo "  Compute Capability를 확인할 수 없어 건너뜁니다."
elif [ "$MIN_CC" -lt "$LLAMACPP_MIN_CC" ]; then
    LLAMACPP_MANUAL=1
    echo "  Compute Capability $MIN_CC 로 배포 바이너리($LLAMACPP_MIN_CC 이상)와 맞지 않아 건너뜁니다."
elif curl -fsSL "$LLAMACPP_URL" -o /tmp/llama-cpp.tar.gz 2>/dev/null; then
    mkdir -p /opt/llama.cpp
    tar xzf /tmp/llama-cpp.tar.gz -C /opt/llama.cpp
    rm -f /tmp/llama-cpp.tar.gz
    for b in llama-server llama-cli llama-bench llama-quantize; do
        ln -sf "/opt/llama.cpp/bin/$b" "/usr/local/bin/$b"
    done
    echo "  설치 완료: $(llama-server --version 2>&1 | head -1)"
else
    LLAMACPP_MANUAL=1
    echo "  다운로드에 실패해 건너뜁니다."
fi

echo "[9/10] Ollama 설치 (기존 강의자료 호환용)"
curl -fsSL https://ollama.com/install.sh | sh > /dev/null 2>&1

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

## llama.cpp

`llama-server`가 `/opt/llama.cpp`에 설치되어 있으며 `/usr/local/bin`에 링크되어 있습니다.

```bash
llama-server -hf <저장소>:<양자화> --alias <이름> --port 8080 -c 32768 -ngl auto --jinja
```

GGUF는 `HF_HOME`(`/tmp/hf/hub`)에 캐시됩니다. 받아둔 모델은 `llama-server --cache-list`로 확인합니다.
배포 바이너리는 Compute Capability 8.6 이상 전용입니다.

## Ollama

기존 강의자료 호환용으로 함께 설치되어 있습니다. 새로 만드는 실습은 위의 `llama-server`를 사용하세요.
컨테이너에 systemd가 없으므로 데몬은 직접 띄워야 합니다.

```bash
ollama serve &
ollama pull <모델>
```

OpenAI 호환 엔드포인트는 `http://localhost:11434/v1` 입니다.
컨텍스트 길이 16384, 모델 유지 시간 1200초가 `~/.bashrc`에 설정되어 있습니다.

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

echo "✅ 환경 설정 완료 (버전: $NOTOLAB_REF)"
echo "💡 가상환경 활성화: source /tmp/.venv/bin/activate"

# NotoLab aliases
grep -qxF "alias lab='cd /workspace/lab'" "$HOME/.bashrc" || echo "alias lab='cd /workspace/lab'" >> "$HOME/.bashrc"
grep -qxF "alias gpu='watch -d -n 0.5 nvidia-smi'" "$HOME/.bashrc" || echo "alias gpu='watch -d -n 0.5 nvidia-smi'" >> "$HOME/.bashrc"
grep -qxF "alias gpus='watch -d -n 0.5 \"nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits; echo; nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits\"'" "$HOME/.bashrc" || echo "alias gpus='watch -d -n 0.5 \"nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits; echo; nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits\"'" >> "$HOME/.bashrc"
grep -qxF "alias CLAUDE='IS_SANDBOX=1 claude --dangerously-skip-permissions'" "$HOME/.bashrc" || echo "alias CLAUDE='IS_SANDBOX=1 claude --dangerously-skip-permissions'" >> "$HOME/.bashrc"

if [ "$LLAMACPP_MANUAL" = "1" ]; then
    echo
    echo "⚠️  llama.cpp가 자동 설치되지 않았습니다. 수동으로 설치해 주세요."
    echo "    배포 바이너리는 Compute Capability 8.6 이상 전용입니다 (이 서버: ${MIN_CC:-확인 불가})."
    echo "    소스 빌드 (약 15분):"
    echo "      apt-get install -y build-essential cmake git libcurl4-openssl-dev"
    echo "      git clone --depth 1 --branch v0.3.0 https://github.com/ggml-org/llama.cpp /opt/llama.cpp"
    echo "      cd /opt/llama.cpp && cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON \\"
    echo "          -DCMAKE_CUDA_ARCHITECTURES=$MIN_CC -DLLAMA_CURL=ON -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON"
    echo "      cmake --build build --config Release -j \$(nproc)"
    echo "      ln -sf /opt/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server"
fi
