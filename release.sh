#!/usr/bin/env bash
# 수업 시점 버전을 고정한 setup 스크립트와 lock 파일을 GitHub Release로 배포한다.
#
#   bash release.sh 2026-09             # 수강생용 (Latest 배지)
#   bash release.sh 2026-10-rc1 --pre    # 테스트용 (Pre-release, Latest 아님)
#
# 대상 과정을 릴리스 노트에 넣으려면 NOTOLAB_COURSES 에 줄 단위로 준다.
#   NOTOLAB_COURSES="2026년 9월 'A 과정'
#   2026년 9월 'B 과정'" bash release.sh 2026-10
#
# 전제: locks/ 디렉터리에 GPU 컨테이너에서 **검증을 마친** lock 4개가 있어야 한다.
#       여기서 lock을 새로 만들지 않는다. 검증하지 않은 lock을 배포하면
#       버전 고정의 의미가 사라지기 때문이다. 만드는 방법은 TODO.md 참고.
#
# 만들어지는 것
#   - 태그 <버전> (현재 origin/main 커밋)
#   - 릴리스 에셋: setup_*.sh 4개(NOTOLAB_REF에 태그가 박힌 사본)
#                  + requirements_*.txt 4개 + requirements-lock-*.txt 4개
set -e

TAG="${1:-}"
if [ -z "$TAG" ]; then
    echo "사용법: bash release.sh <버전> [--pre]    예: bash release.sh 2026-09" >&2
    exit 1
fi

# --pre 는 테스트 발행이다. GitHub이 Latest로 잡지 않으므로 릴리스 페이지에서
# 수강생에게 최신본으로 보이지 않는다. 에셋은 그대로 공개되므로
# NOTOLAB_REF=<태그>로 lock 다운로드 경로까지 실제로 검증할 수 있다.
# (--draft 는 쓸 수 없다. 드래프트 에셋은 인증이 필요해서 스크립트의 curl이
#  404를 받고 조용히 compile 폴백으로 빠진다.)
PRERELEASE=""
PRENOTE=""
case "${2:-}" in
    --pre|--prerelease)
        PRERELEASE="--prerelease"
        PRENOTE="> **테스트 발행입니다. 수강생은 사용하지 마세요.**
> 수업용은 Latest 배지가 붙은 릴리스입니다.

"
        ;;
    "") ;;
    *) echo "알 수 없는 옵션: $2 (쓸 수 있는 것: --pre)" >&2; exit 1 ;;
esac

# 이 릴리스가 어느 기수를 위한 것인지 노트에 남긴다. 발행마다 달라지므로
# 스크립트에 박지 않고 NOTOLAB_COURSES 로 받는다. 비어 있으면 섹션이 빠진다.
COURSES_SECTION=""
if [ -n "${NOTOLAB_COURSES:-}" ]; then
    COURSES_SECTION="
## 대상 과정

$(printf '%s\n' "$NOTOLAB_COURSES" | sed '/^[[:space:]]*$/d; s/^[[:space:]]*//; s/^/- /')
"
fi

REPO="NotoriousH2/notolab_requirements_txt"
LOCKDIR="${LOCKDIR:-locks}"
SCRIPTS="setup_adv.sh setup_peft.sh setup_sllm.sh setup_agent.sh"
MANIFESTS="requirements_adv.txt requirements_PEFT.txt requirements_sLLM.txt requirements_agent.txt"
VARIANTS="adv PEFT sLLM agent"

# manifest에 적힌 패키지가 lock에 전부 들어있고 == 핀이 일치하는지 확인한다.
# manifest를 고치고 lock을 다시 뽑지 않은 채 배포하는 사고를 막는 장치다.
# 이름 존재까지 보는 이유: 무핀 패키지(ipykernel 등)를 새로 추가하면
# 핀 비교만으로는 lock이 낡았다는 걸 알 수 없기 때문이다.
check_pins() {
    awk '
    # PEP 503 정규화: 대소문자 통일, - _ . 연속을 하나의 - 로 (discord.py -> discord-py)
    function norm(s) { gsub(/[-_.]+/, "-", s); return tolower(s) }
    NR==FNR {
        line = $0; sub(/[[:space:]].*$/, "", line)
        if (line ~ /^[A-Za-z0-9._-]+==/) {
            n = line; sub(/==.*/, "", n)
            v = line; sub(/^[^=]*==/, "", v)
            have[norm(n)] = v
        }
        next
    }
    {
        line = $0
        sub(/#.*$/, "", line)
        sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
        if (line == "" || line ~ /^-/) next

        name = line
        sub(/;.*$/, "", name); sub(/\[.*$/, "", name); sub(/[=<>!~].*$/, "", name)
        sub(/[[:space:]]+$/, "", name)
        k = norm(name)

        if (!(k in have)) { printf "    누락: %s (lock에 없음 — lock을 다시 뽑으세요)\n", name; bad++; next }

        if (line ~ /==/) {
            v = line; sub(/^[^=]*==/, "", v)
            sub(/[;,].*$/, "", v); sub(/[[:space:]].*$/, "", v)
            if (have[k] != v && index(have[k], v "+") != 1) {
                printf "    불일치: %s manifest=%s lock=%s\n", name, v, have[k]; bad++
            }
        }
    }
    END { exit (bad > 0) }
    ' "$2" "$1"
}

# 커밋되지 않은 변경은 태그에 담기지 않는다
if [ -n "$(git status --porcelain -- $SCRIPTS $MANIFESTS)" ]; then
    echo "커밋되지 않은 변경이 있습니다. 먼저 커밋하고 푸시하세요." >&2
    git status --short -- $SCRIPTS $MANIFESTS >&2
    exit 1
fi

# 태그는 원격 커밋에 붙으므로 로컬이 앞서 있으면 안 된다
git fetch origin main -q
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    echo "HEAD가 origin/main과 다릅니다. 먼저 푸시하세요." >&2
    echo "  HEAD:        $(git rev-parse --short HEAD)" >&2
    echo "  origin/main: $(git rev-parse --short origin/main)" >&2
    exit 1
fi

# lock 4개가 있고 manifest와 어긋나지 않는지 확인
echo "lock 검사"
FAIL=0
for v in $VARIANTS; do
    lock="$LOCKDIR/requirements-lock-$v.txt"
    case "$v" in
        adv)   manifest="requirements_adv.txt" ;;
        PEFT)  manifest="requirements_PEFT.txt" ;;
        sLLM)  manifest="requirements_sLLM.txt" ;;
        agent) manifest="requirements_agent.txt" ;;
    esac
    if [ ! -f "$lock" ]; then
        echo "  없음: $lock — GPU 컨테이너에서 만들어 가져오세요 (TODO.md 참고)" >&2
        FAIL=1
        continue
    fi
    if check_pins "$manifest" "$lock"; then
        echo "  OK: $manifest -> $(basename "$lock")"
    else
        echo "  ★ $manifest 의 핀이 lock에 반영되지 않았습니다. lock을 다시 만들고 재검증하세요." >&2
        FAIL=1
    fi
done
[ "$FAIL" = "0" ] || exit 1

# NOTOLAB_REF에 태그를 박은 스크립트 사본 생성
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

for s in $SCRIPTS; do
    sed "s|^NOTOLAB_REF=\"\${NOTOLAB_REF:-main}\"$|NOTOLAB_REF=\"\${NOTOLAB_REF:-$TAG}\"|" "$s" > "$OUT/$s"
    grep -q "NOTOLAB_REF:-$TAG}" "$OUT/$s" || { echo "$s 버전 치환 실패" >&2; exit 1; }
    bash -n "$OUT/$s"
done

gh release create "$TAG" -R "$REPO" $PRERELEASE \
    --title "NotoLab 실습 환경 $TAG" \
    --notes "$PRENOTE$TAG 수업 시점으로 고정된 설치 스크립트입니다.
$COURSES_SECTION
## 수강생

아래에서 과정에 맞는 \`setup_*.sh\`를 받아 NotoLab 컨테이너에서 실행하세요.
이 스크립트들은 최신판이 아니라 **$TAG 시점에 검증된 패키지 조합**을 설치합니다.

\`\`\`bash
bash setup_adv.sh        # 심화 과정
bash setup_peft.sh       # PEFT 과정
bash setup_sllm.sh       # 소형 LLM 과정
bash setup_agent.sh      # 에이전트 과정
\`\`\`

설치 로그에 \`lock 사용: ...\` 이 찍히면 고정된 조합이 적용된 것입니다.

## 참고

- 최신판을 쓰려면 저장소 \`main\`의 스크립트를 사용하세요.
- lock 설치가 깨지면 \`NOTOLAB_LOCK=0 bash setup_sllm.sh\` 로 최신 해석을 시도할 수 있습니다.
- 다른 버전을 쓰려면 \`NOTOLAB_REF=<버전> bash setup_sllm.sh\`" \
    "$OUT"/setup_adv.sh "$OUT"/setup_peft.sh "$OUT"/setup_sllm.sh "$OUT"/setup_agent.sh \
    $MANIFESTS \
    "$LOCKDIR"/requirements-lock-adv.txt "$LOCKDIR"/requirements-lock-PEFT.txt \
    "$LOCKDIR"/requirements-lock-sLLM.txt "$LOCKDIR"/requirements-lock-agent.txt

# 업로드 누락은 404 -> compile 폴백으로 조용히 넘어가므로 반드시 확인한다
echo
echo "에셋 확인"
ASSETS="$(gh release view "$TAG" -R "$REPO" --json assets --jq '.assets[].name')"
for v in $VARIANTS; do
    if echo "$ASSETS" | grep -qx "requirements-lock-$v.txt"; then
        echo "  OK: requirements-lock-$v.txt"
    else
        echo "  ★ 누락: requirements-lock-$v.txt — 이대로 두면 학생 설치가 조용히 lock 없이 진행됩니다" >&2
        FAIL=1
    fi
done
[ "$FAIL" = "0" ] || exit 1

echo
echo "완료: https://github.com/$REPO/releases/tag/$TAG"
if [ -n "$PRERELEASE" ]; then
    echo
    echo "테스트 발행입니다. Latest로 잡히지 않으므로 수강생 안내에는 보이지 않습니다."
    echo "  설치 검증: NOTOLAB_REF=$TAG bash setup_peft.sh"
    echo "  정리:      gh release delete $TAG -R $REPO --cleanup-tag"
fi
