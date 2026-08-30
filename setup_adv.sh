#!/usr/bin/env bash
set -e
set -o pipefail

# 이 스크립트가 참조할 저장소 버전(태그/브랜치).
# 릴리스로 배포된 사본에는 수업 시점 태그가 박혀 있고, main 사본은 최신을 따라간다.
# 다른 버전으로 설치하려면: NOTOLAB_REF=<태그> bash setup_adv.sh
NOTOLAB_REF="${NOTOLAB_REF:-main}"

COURSE=adv
STATE=/workspace/lab/.notolab-env

# 단계 번호는 여기 한 곳에서만 관리한다. 단계가 늘어도 로그 형식은 그대로다.
TOTAL_STEPS=9
CURRENT_STEP=0
step() { CURRENT_STEP="$1"; shift; echo "[$CURRENT_STEP/$TOTAL_STEPS] $*"; }

# --- 재실행 / 동시 실행 가드 -------------------------------------------------
# [5]단계의 `uv venv --clear`는 기존 가상환경을 지운다. setup이 겹쳐 돌면 나중
# 프로세스가 먼저 돌던 설치의 환경을 삭제해 양쪽이 모두 깨지므로 한 번에 하나만 돈다.
if command -v flock > /dev/null 2>&1; then
    exec 9>/tmp/notolab-setup.lock
    if ! flock -n 9; then
        echo "다른 setup이 이미 실행 중입니다. 종료합니다."
        exit 0
    fi
fi

# 같은 과정이 이미 정상 설치돼 있으면 건드리지 않는다. 자동화가 완료 판정을 잘못해
# 재시도를 던져도 멀쩡한 환경(수강생이 직접 설치한 패키지 포함)이 날아가지 않는다.
# 실패로 끝난 환경(STATUS=failed)은 스킵하지 않고 다시 설치한다.
if [ -z "${NOTOLAB_FORCE:-}" ] \
   && grep -q '^STATUS=ok$' "$STATE" 2>/dev/null \
   && grep -q "^COURSE=$COURSE$" "$STATE" 2>/dev/null; then
    echo "이미 설치가 끝난 환경입니다 ($(grep '^INSTALLED_AT=' "$STATE" | cut -d= -f2-))."
    echo "다시 설치하려면: NOTOLAB_FORCE=1 bash setup_adv.sh"
    exit 0
fi

# 이 지점부터 .notolab-env는 "이번 실행의 결과"만 담는다.
# 파일이 있으면 곧 스크립트가 끝까지 돌았다는 뜻이 되도록, 먼저 지우고 시작한다.
rm -f "$STATE"

record_result() {
    rc=$?
    if [ -f "$STATE" ]; then return 0; fi
    mkdir -p /workspace/lab 2>/dev/null || true
    cat > "$STATE" <<EOF
NOTOLAB_REF=$NOTOLAB_REF
COURSE=$COURSE
STATUS=failed
FAILED_STEP=$CURRENT_STEP
EXIT_CODE=$rc
INSTALLED_AT=$(date -Is)
EOF
    echo "[FAIL] step $CURRENT_STEP/$TOTAL_STEPS 에서 중단되었습니다 (exit $rc)."
}
trap record_result EXIT

# 다른 프로세스(Claude Code 배치 설치 등)가 apt를 점유 중이면 즉시 실패하지 말고
# 최대 120초 dpkg 락을 대기한다.
mkdir -p /etc/apt/apt.conf.d && echo 'DPkg::Lock::Timeout "120";' > /etc/apt/apt.conf.d/99lock-timeout

step 1 "APT 업데이트 및 pciutils 설치"
apt-get update -qq && apt-get install -y -qq pciutils > /dev/null

step 2 "nvidia-smi 검사"
# nvidia-smi가 아예 없거나 행(hang)이면 출력이 비어 ERR! 검사를 그냥 통과한다.
# GPU가 죽었을 때 나타나는 전형적인 증상이므로 빈 출력도 실패로 본다.
SMI_OUT="$(timeout 60 nvidia-smi 2>/dev/null || true)"
if [ -z "$SMI_OUT" ]; then
    echo "nvidia-smi가 응답하지 않습니다 (GPU 행 또는 드라이버 문제). 강사에게 문의해주세요!"
    exit 1
fi
if echo "$SMI_OUT" | grep -q "ERR!"; then
    echo "GPU 오류 발생, 강사에게 문의해주세요!"
    exit 1
fi

step 3 "uv 설치"
curl -LsSf --retry 3 --retry-delay 2 https://astral.sh/uv/0.10.3/install.sh | sh > /dev/null 2>&1
if [ -f "$HOME/.local/bin/env" ]; then
    source "$HOME/.local/bin/env"
else
    export PATH="$HOME/.local/bin:$PATH"
fi
export UV_CACHE_DIR=/tmp/.uv-cache
if ! grep -qxF "# NotoLab 환경 설정" "$HOME/.bashrc" 2>/dev/null; then
cat >> ~/.bashrc <<'EOF'

# NotoLab 환경 설정
export UV_CACHE_DIR=/tmp/.uv-cache
export PIP_CACHE_DIR=/tmp/.pip-cache
export HF_HOME=/tmp/hf
export HF_HUB_ENABLE_HF_TRANSFER=1
if [ -f /tmp/.venv/bin/activate ]; then source /tmp/.venv/bin/activate; fi
EOF
fi

step 4 "lab 디렉토리 생성"
cd /workspace
mkdir -p lab
cd lab

step 5 "가상환경 생성 (/tmp/.venv → 로컬 디스크)"
if [ -d /tmp/.venv ]; then
    echo "  기존 가상환경을 다시 만듭니다 (직접 설치한 패키지는 사라집니다)"
fi
uv venv /tmp/.venv --seed --clear -q
ln -sfn /tmp/.venv .venv
source /tmp/.venv/bin/activate

step 6 "requirements 파일 다운로드 및 패키지 설치 (버전: $NOTOLAB_REF)"
wget -qO requirements.txt \
"https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/$NOTOLAB_REF/requirements_adv.txt"
# 릴리스에 동봉된 lock이 있으면 그대로 설치해 수업 시점 환경을 재현한다.
# lock이 없거나 깨졌으면 manifest에서 다시 해석한다 (NOTOLAB_LOCK=0으로 강제 가능).
LOCK_URL="https://github.com/NotoriousH2/notolab_requirements_txt/releases/download/$NOTOLAB_REF/requirements-lock-adv.txt"
if [ "${NOTOLAB_LOCK:-1}" = "1" ] && curl -fsSL --retry 3 --retry-delay 2 "$LOCK_URL" -o requirements-lock.txt 2>/dev/null; then
    echo "  lock 사용: requirements-lock-adv.txt ($NOTOLAB_REF)"
    INSTALL_SOURCE=lock
else
    echo "  lock 없음 — manifest에서 해석"
    INSTALL_SOURCE=compile
    uv pip compile requirements.txt \
        --index-strategy unsafe-best-match \
        --emit-index-url \
        -o requirements-lock.txt -q
fi
uv pip install -r requirements-lock.txt --index-strategy unsafe-best-match -q

step 7 "Jupyter 커널 등록"
python -m ipykernel install --name "NotoLab" --display-name "NotoLab" > /dev/null 2>&1

step 8 "unsloth 실습 환경 (별도 venv + 전용 커널)"
# unsloth는 transformers/trl을 자체 버전으로 끌어오므로 메인 venv에 넣을 수 없다.
# 다만 torch/CUDA 계층은 [6]단계에서 uv 캐시에 들어와 있어 하드링크로 공유된다.
# 그래서 이 단계는 반드시 [6]단계 뒤에 있어야 한다 — 앞에 두면 torch를 새로 받는다.
wget -qO requirements_unsloth.txt \
"https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/$NOTOLAB_REF/requirements_unsloth.txt"
UNSLOTH_LOCK_URL="https://github.com/NotoriousH2/notolab_requirements_txt/releases/download/$NOTOLAB_REF/requirements-lock-unsloth.txt"
if [ "${NOTOLAB_LOCK:-1}" = "1" ] && curl -fsSL --retry 3 --retry-delay 2 "$UNSLOTH_LOCK_URL" -o requirements-lock-unsloth.txt 2>/dev/null; then
    echo "  lock 사용: requirements-lock-unsloth.txt ($NOTOLAB_REF)"
    UNSLOTH_SOURCE=lock
else
    echo "  lock 없음 — manifest에서 해석"
    UNSLOTH_SOURCE=compile
    uv pip compile requirements_unsloth.txt \
        --index-strategy unsafe-best-match \
        --emit-index-url \
        -o requirements-lock-unsloth.txt -q
fi
if [ -d /tmp/.venv-unsloth ]; then
    echo "  기존 unsloth 가상환경을 다시 만듭니다"
fi
uv venv /tmp/.venv-unsloth --seed --clear -q
ln -sfn /tmp/.venv-unsloth /workspace/lab/.venv-unsloth
VIRTUAL_ENV=/tmp/.venv-unsloth uv pip install --python /tmp/.venv-unsloth/bin/python \
    -r requirements-lock-unsloth.txt --index-strategy unsafe-best-match -q
/tmp/.venv-unsloth/bin/python -m ipykernel install \
    --name "NotoLab-Unsloth" --display-name "NotoLab (Unsloth)" > /dev/null 2>&1

step 9 "AGENTS.md 생성"
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

## unsloth

unsloth 실습은 별도 환경을 씁니다. transformers/trl 버전이 메인 환경과 달라 같은
가상환경에 넣을 수 없습니다.

- 가상환경: `/tmp/.venv-unsloth` (심볼릭 링크: `/workspace/lab/.venv-unsloth`)
- Jupyter 커널: `NotoLab (Unsloth)`

노트북에서 커널을 `NotoLab (Unsloth)`로 바꿔 사용하세요.
터미널에서는 `source /tmp/.venv-unsloth/bin/activate`.

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

cat >> /workspace/lab/AGENTS.md <<EOF

## 이 환경의 버전

| 항목 | 값 |
|------|-----|
| 버전 | \`$NOTOLAB_REF\` |
| 패키지 출처 | \`$INSTALL_SOURCE\` |
| unsloth 출처 | \`$UNSLOTH_SOURCE\` |
| 설치 시각 | \`$(date -Is)\` |

\`lock\`은 릴리스에 동봉된 검증본을 그대로 설치했다는 뜻이고,
\`compile\`은 설치 시점에 의존성을 다시 해석했다는 뜻입니다.
같은 내용이 \`/workspace/lab/.notolab-env\`에도 있습니다.
EOF

echo "✅ 환경 설정 완료 (버전: $NOTOLAB_REF)"
echo "💡 가상환경 활성화: source /tmp/.venv/bin/activate"

# NotoLab aliases
grep -qxF "alias lab='cd /workspace/lab'" "$HOME/.bashrc" || echo "alias lab='cd /workspace/lab'" >> "$HOME/.bashrc"
grep -qxF "alias gpu='watch -d -n 0.5 nvidia-smi'" "$HOME/.bashrc" || echo "alias gpu='watch -d -n 0.5 nvidia-smi'" >> "$HOME/.bashrc"
grep -qxF "alias gpus='watch -d -n 0.5 \"nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits; echo; nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits\"'" "$HOME/.bashrc" || echo "alias gpus='watch -d -n 0.5 \"nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits; echo; nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits\"'" >> "$HOME/.bashrc"
grep -qxF "alias CLAUDE='IS_SANDBOX=1 claude --dangerously-skip-permissions'" "$HOME/.bashrc" || echo "alias CLAUDE='IS_SANDBOX=1 claude --dangerously-skip-permissions'" >> "$HOME/.bashrc"

# 설치 결과를 컨테이너 안에 남긴다. startup으로 실행되면 stdout은 팟 로그로 가서
# 아무도 보지 않으므로, 나중에 버전과 lock 사용 여부를 확인할 수 있어야 한다.
# 이 파일이 있다는 것 자체가 "스크립트가 끝까지 돌았다"는 뜻이므로 맨 마지막에 쓴다.
# 자동화의 완료 판정도 단계 번호가 아니라 이 파일을 봐야 한다.
cat > "$STATE" <<EOF
NOTOLAB_REF=$NOTOLAB_REF
COURSE=$COURSE
STATUS=ok
INSTALL_SOURCE=$INSTALL_SOURCE
UNSLOTH_SOURCE=$UNSLOTH_SOURCE
INSTALLED_AT=$(date -Is)
EOF
