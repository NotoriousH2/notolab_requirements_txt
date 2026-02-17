#!/usr/bin/env bash
set -e

echo "[1/7] APT 업데이트 및 pciutils 설치"
apt update && apt install -y pciutils

echo "[2/7] nvidia-smi 검사"
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

echo "[3/7] uv 설치"
curl -LsSf https://astral.sh/uv/install.sh | sh
source "$HOME/.local/bin/env"
export UV_CACHE_DIR=/workspace/.uv-cache

echo "[4/7] 실습 디렉토리 생성"
cd /workspace
mkdir -p 실습
cd 실습

echo "[5/7] 가상환경 생성"
uv venv .venv --seed
source .venv/bin/activate

echo "[6/7] requirements 파일 다운로드 및 패키지 설치"
wget -O requirements.txt \
https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/main/requirements_adv.txt
uv pip compile requirements.txt -o requirements-lock.txt
uv pip install -r requirements-lock.txt

echo "[7/7] Jupyter 커널 등록"
uv pip install ipykernel
python -m ipykernel install --name "NotoLab" --display-name "NotoLab"

echo "✅ 환경 설정 완료"
echo "💡 가상환경 활성화: source /workspace/실습/.venv/bin/activate"
