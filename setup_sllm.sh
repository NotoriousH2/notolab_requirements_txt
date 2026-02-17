#!/usr/bin/env bash
set -e

echo "[1/8] APT 업데이트 및 pciutils 설치"
apt update && apt install -y pciutils

echo "[2/8] nvidia-smi 검사"
if nvidia-smi | grep -q "ERR!"; then
    echo "GPU 오류 발생, 강사에게 문의해주세요!"
    exit 1
fi

# CUDA 버전 검사 (12.8 이상 필요)
CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}')
CUDA_MAJOR=$(echo "$CUDA_VERSION" | cut -d. -f1)
CUDA_MINOR=$(echo "$CUDA_VERSION" | cut -d. -f2)

if [ "$CUDA_MAJOR" -lt 12 ] || { [ "$CUDA_MAJOR" -eq 12 ] && [ "$CUDA_MINOR" -lt 8 ]; }; then
    echo "CUDA 버전이 12.8 미만입니다 (현재: $CUDA_VERSION). 강사에게 문의해주세요!"
    exit 1
fi
echo "CUDA 버전 확인 완료: $CUDA_VERSION"

echo "[3/8] uv 설치"
curl -LsSf https://astral.sh/uv/install.sh | sh
source "$HOME/.local/bin/env"

echo "[4/8] 실습 디렉토리 생성"
cd /workspace
mkdir -p 실습
cd 실습

echo "[5/8] 가상환경 생성"
uv venv .venv
source .venv/bin/activate

echo "[6/8] requirements 파일 다운로드 및 패키지 설치"
wget -O requirements.txt \
https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/main/requirements_sLLM.txt
uv pip install -r requirements.txt

echo "[7/8] Jupyter 커널 등록"
uv pip install ipykernel
python -m ipykernel install --name "NotoLab" --display-name "NotoLab"

echo "[8/8] Ollama 설치"
curl -fsSL https://ollama.com/install.sh | sh

export OLLAMA_CONTEXT_LENGTH=16384
export OLLAMA_KEEP_ALIVE=1200

echo "✅ 환경 설정 완료"
echo "💡 가상환경 활성화: source /workspace/실습/.venv/bin/activate"
