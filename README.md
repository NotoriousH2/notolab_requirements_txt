# NotoLab Requirements

Last Updated : 2026-08-08

NotoLab 강의 수강생을 위한 실습 환경 설치 파일 모음입니다. NotoLab 컨테이너에서 스크립트 한 줄로 과정에 맞는 Python 환경을 동일하게 구성합니다.

## 시작하기

수업에서는 RunPod 템플릿으로 NotoLab 컨테이너를 띄웁니다.

- 수업용 RunPod 템플릿: https://console.runpod.io/deploy?template=lom3sqxgoc&ref=88shxnpk
- RunPod 가입: https://runpod.io?ref=88shxnpk

## 사용 방법

NotoLab 컨테이너에서 과정에 맞는 스크립트를 실행한 뒤 가상환경을 활성화합니다.

```bash
bash setup_adv.sh        # 심화 과정 (Ollama 미설치)
bash setup_peft.sh       # PEFT 과정 (Ollama)
bash setup_sllm.sh       # 소형 LLM 과정 (Ollama)
bash setup_agent.sh      # 에이전트 과정 (chromium, Ollama)

source /tmp/.venv/bin/activate
```

스크립트는 GPU 상태 확인, uv 설치, /tmp/.venv 가상환경 생성, 패키지 설치, NotoLab Jupyter 커널 등록을 수행합니다.

심화 / PEFT / 소형 LLM 과정은 unsloth 실습용 환경을 하나 더 만듭니다. unsloth는 transformers/trl 버전이 메인 환경과 달라 같은 가상환경에 넣을 수 없기 때문입니다. 노트북에서 커널을 `NotoLab (Unsloth)`로 바꾸면 됩니다.

## 버전 고정 (수업 시점 환경 재현)

`main`의 스크립트는 항상 최신 패키지 목록을 설치합니다. 수업에서 쓰던 환경을 나중에 다시 만들려면 릴리스에서 받은 스크립트를 사용하세요.

- 릴리스 목록: https://github.com/NotoriousH2/notolab_requirements_txt/releases
- 릴리스에 올라온 `setup_*.sh`에는 그 시점 버전이 박혀 있어, 실행하면 해당 시점의 패키지 조합을 설치합니다.
- 릴리스에는 GPU 컨테이너에서 설치까지 검증한 lock 파일이 동봉됩니다. 설치 로그에 `lock 사용: ...`이 찍히면 고정된 조합이 적용된 것이고, `lock 없음 — manifest에서 해석`이면 그때그때 다시 해석한 것입니다.
- lock 설치가 깨지면 `NOTOLAB_LOCK=0 bash setup_sllm.sh`로 최신 해석을 시도할 수 있습니다.
- 어떤 버전이 적용됐는지는 설치 로그의 `[6/N] ... (버전: ...)` 줄과 마지막 완료 줄에서 확인합니다.
- 임시로 다른 버전을 쓰려면 `NOTOLAB_REF=<버전> bash setup_sllm.sh`

오래된 버전은 언젠가 깨집니다. PyPI에서 패키지가 내려가거나 컨테이너 이미지의 드라이버와 CUDA 빌드가 맞지 않으면 설치가 실패할 수 있습니다. 그럴 때는 최신 버전을 쓰거나 `NOTOLAB_LOCK=0`으로 다시 해석하세요.

### 강사용: 새 버전 배포

변경을 `main`에 푸시하고, GPU 컨테이너에서 검증한 lock 4개를 `locks/`에 둔 뒤 실행합니다.
lock이 manifest와 어긋나면 배포를 거부합니다.

```bash
bash release.sh 2026-09
```

## 과정별 패키지 목록

| 패키지 목록 파일 | 용도 | CUDA |
|------------|------|------|
| requirements_adv.txt | 심화 과정 | 13.0 (cu130) |
| requirements_PEFT.txt | PEFT 과정 | 13.0 (cu130) |
| requirements_sLLM.txt | 소형 LLM 과정 | 13.0 (cu130) |
| requirements_agent.txt | 에이전트 과정 (MCP, Slack, 트레이싱, 브라우저 도구) | 해당 없음 (PyTorch 미설치) |
| requirements_unsloth.txt | unsloth 실습 (심화 / PEFT / 소형 LLM 과정에 별도 환경으로 설치) | 13.0 (cu130) |

## vLLM 실행 예시

심화 / PEFT / 소형 LLM 과정은 `vllm==0.24.0` 이 가상환경에 함께 설치됩니다.

```bash
vllm serve <model_name>
```

다른 버전으로 서빙해야 하면 가상환경에 설치하지 말고 `uvx` 로 실행합니다. 버전별 예시는 다음과 같습니다.

vLLM 0.19.1:

```bash
uvx --python 3.12 --from vllm==0.19.1 vllm serve ./outputs/models/Qwen3.5-9B \
  --max-model-len 16384 \
  --gpu-memory-utilization 0.5 \
  --reasoning-parser qwen3 \
  --language-model-only \
  --speculative-config '{"method":"mtp","num_speculative_tokens":2}'
```

vLLM 0.17.1 (`fastapi==0.115.12` 함께 설치):

```bash
uvx --python 3.12 --from vllm==0.17.1 --with fastapi==0.115.12 vllm serve ./Qwen3-30B-A3B-Instruct-2507-AWQ-4bit \
  --dtype auto \
  --gpu_memory_utilization 0.5 \
  --max_model_len 16384
```

## 참고 사항 (RunPod/NotoLab 환경 한정)

**아래 내용은 RunPod 기반 NotoLab 컨테이너에서 불러올 때 기준이며, 일반 로컬 세팅에는 해당하지 않습니다.**

setup 스크립트는 로컬 파일이 아니라 GitHub main 브랜치의 패키지 목록 파일을 내려받아 설치합니다. requirements 파일 수정은 main 에 푸시된 뒤에야 수강생 환경에 반영됩니다.

캐시와 가상환경은 모두 로컬 디스크 /tmp 에 둡니다. /workspace 는 FUSE 네트워크 스토리지라 대량 I/O 가 느립니다. 기본 서빙 버전인 vLLM 0.24.0 은 가상환경에 설치되며, 그 외 버전은 uvx 로 실행합니다.

자세한 규칙은 AGENTS.md 를 참고하세요.
