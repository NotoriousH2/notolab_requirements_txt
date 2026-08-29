#!/usr/bin/env bash
# 수업 시점 버전을 고정한 setup 스크립트를 GitHub Release로 배포한다.
#
#   bash release.sh 2026-09
#
# 만들어지는 것
#   - 태그 <버전> (현재 origin/main 커밋)
#   - 릴리스 에셋: setup_*.sh 4개 + requirements_*.txt 4개
#     에셋으로 올라가는 setup_*.sh는 NOTOLAB_REF에 태그가 박힌 사본이라,
#     수강생에게 그대로 전달하면 그 시점의 manifest를 받아 설치한다.
set -e

TAG="${1:-}"
if [ -z "$TAG" ]; then
    echo "사용법: bash release.sh <버전>    예: bash release.sh 2026-09" >&2
    exit 1
fi

REPO="NotoriousH2/notolab_requirements_txt"
SCRIPTS="setup_adv.sh setup_peft.sh setup_sllm.sh setup_agent.sh"
MANIFESTS="requirements_adv.txt requirements_PEFT.txt requirements_sLLM.txt requirements_agent.txt"

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

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

for s in $SCRIPTS; do
    sed "s|^NOTOLAB_REF=\"\${NOTOLAB_REF:-main}\"$|NOTOLAB_REF=\"\${NOTOLAB_REF:-$TAG}\"|" "$s" > "$OUT/$s"
    grep -q "NOTOLAB_REF:-$TAG}" "$OUT/$s" || { echo "$s 버전 치환 실패" >&2; exit 1; }
    bash -n "$OUT/$s"
done

gh release create "$TAG" -R "$REPO" \
    --title "NotoLab 실습 환경 $TAG" \
    --notes "$TAG 수업 시점으로 고정된 설치 스크립트입니다.

## 수강생

아래에서 과정에 맞는 \`setup_*.sh\`를 받아 NotoLab 컨테이너에서 실행하세요.
이 스크립트들은 최신판이 아니라 **$TAG 시점의 패키지 목록**을 설치합니다.

\`\`\`bash
bash setup_adv.sh        # 심화 과정
bash setup_peft.sh       # PEFT 과정
bash setup_sllm.sh       # 소형 LLM 과정
bash setup_agent.sh      # 에이전트 과정
\`\`\`

## 참고

- 최신판을 쓰려면 저장소 \`main\`의 스크립트를 사용하세요.
- 다른 버전으로 설치하려면 \`NOTOLAB_REF=<버전> bash setup_sllm.sh\` 형태로 덮어쓸 수 있습니다.
- 설치 로그 첫머리와 마지막 줄에 적용된 버전이 표시됩니다." \
    "$OUT"/setup_adv.sh "$OUT"/setup_peft.sh "$OUT"/setup_sllm.sh "$OUT"/setup_agent.sh \
    $MANIFESTS

echo
echo "완료: https://github.com/$REPO/releases/tag/$TAG"
