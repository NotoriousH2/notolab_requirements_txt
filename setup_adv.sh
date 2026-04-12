#!/usr/bin/env bash
set -e

echo "[1/8] APT 업데이트 및 pciutils 설치"
apt update && apt install -y pciutils

echo "[2/8] nvidia-smi 검사"
if nvidia-smi | grep -q "ERR!"; then
    echo "GPU 오류 발생, 강사에게 문의해주세요!"
    exit 1
fi
echo "[3/8] uv 설치"
curl -LsSf https://astral.sh/uv/0.10.3/install.sh | sh
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
source /tmp/.venv/bin/activate
EOF

echo "[4/8] lab 디렉토리 생성"
cd /workspace
mkdir -p lab
cd lab

echo "[5/8] 가상환경 생성 (/tmp/.venv → 로컬 디스크)"
uv venv /tmp/.venv --seed
ln -sfn /tmp/.venv .venv
source /tmp/.venv/bin/activate

echo "[6/8] requirements 파일 다운로드 및 패키지 설치"
wget -O requirements.txt \
https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/main/requirements_adv.txt
uv pip compile requirements.txt -o requirements-lock.txt
uv pip install -r requirements-lock.txt

echo "[7/8] Jupyter 커널 등록"
uv pip install ipykernel
python -m ipykernel install --name "NotoLab" --display-name "NotoLab"

echo "[8/8] AGENTS.md 생성"
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
AGENTSEOF

echo "✅ 환경 설정 완료"
echo "💡 가상환경 활성화: source /tmp/.venv/bin/activate"
