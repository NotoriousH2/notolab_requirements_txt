#!/usr/bin/env bash
set -e

echo "[1/10] APT 업데이트 및 pciutils 설치"
apt-get update -qq && apt-get install -y -qq pciutils > /dev/null

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
https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/main/requirements_sLLM.txt
uv pip compile requirements.txt \
    --index-strategy unsafe-best-match \
    --emit-index-url \
    -o requirements-lock.txt -q
uv pip install -r requirements-lock.txt --index-strategy unsafe-best-match -q

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

vLLM 0.24.0이 가상환경에 설치되어 있습니다.

```bash
vllm serve <model_name>
```

다른 버전으로 서빙해야 하면 가상환경에 설치하지 말고 `uvx`로 실행하세요.

```bash
uvx --python 3.12 --from vllm==<version> vllm serve <model_name>
```
AGENTSEOF

echo "✅ 환경 설정 완료"
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
