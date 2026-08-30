# NotoLab Requirements

Last Updated : 2026-08-30

NotoLab 강의 수강생을 위한 실습 환경 설치 파일 모음입니다. NotoLab 컨테이너에서 스크립트 한 줄로 과정에 맞는 Python 환경을 구성합니다.

## 시작하기

수업에서는 RunPod 템플릿으로 NotoLab 컨테이너를 띄웁니다.

- 수업용 RunPod 템플릿: https://console.runpod.io/deploy?template=lom3sqxgoc&ref=88shxnpk
- RunPod 가입: https://runpod.io?ref=88shxnpk

## 사용 방법

### 수업 시점 환경 그대로 (권장)

[릴리스 페이지](https://github.com/NotoriousH2/notolab_requirements_txt/releases)에서 수강한 시점의 버전을 열고, 과정에 맞는 `setup_*.sh`를 받아 컨테이너에서 실행합니다.

```bash
bash setup_sllm.sh
```

릴리스에 올라온 스크립트에는 버전이 박혀 있어서 추가 인자나 환경변수가 필요 없습니다. 그 시점에 GPU 컨테이너에서 설치까지 검증한 패키지 조합(lock)을 그대로 설치하므로, 몇 달 뒤에 돌려도 수업 때와 같은 환경이 만들어집니다.

### 최신 버전

새 실습을 만들거나 최신 패키지 조합이 필요하면 `main`의 스크립트를 사용합니다. 이쪽은 lock 없이 설치 시점에 의존성을 다시 해석합니다.

```bash
wget https://raw.githubusercontent.com/NotoriousH2/notolab_requirements_txt/main/setup_sllm.sh
bash setup_sllm.sh
```

### 과정별 스크립트

| 과정 | 스크립트 | Ollama | llama.cpp | unsloth 환경 |
|------|----------|:------:|:---------:|:------------:|
| 심화 | `setup_adv.sh` | | | O |
| PEFT | `setup_peft.sh` | O | O | O |
| 소형 LLM | `setup_sllm.sh` | O | O | O |
| 에이전트 | `setup_agent.sh` | O | O | |

에이전트 과정은 chromium과 Playwright용 Chrome을 함께 설치하고 PyTorch는 설치하지 않습니다.

### 설치 후

가상환경은 `/tmp/.venv`에 만들어지고 `~/.bashrc`에서 자동으로 활성화됩니다. 직접 활성화하려면:

```bash
source /tmp/.venv/bin/activate
```

Jupyter에서는 커널 `NotoLab`을 선택합니다. 심화 / PEFT / 소형 LLM 과정은 **unsloth 실습용 환경을 하나 더** 만듭니다. unsloth는 transformers/trl 버전이 메인 환경과 달라 같은 가상환경에 넣을 수 없기 때문입니다. 해당 실습에서는 커널을 `NotoLab (Unsloth)`로 바꾸면 됩니다.

setup을 다시 실행하면 가상환경은 새로 만들어집니다. 직접 `pip install`한 패키지가 있다면 사라지니 다시 설치하세요.

## 내 환경 확인하기

설치가 끝나면 `/workspace/lab/.notolab-env`에 결과가 기록됩니다.

```
NOTOLAB_REF=2026-09
INSTALL_SOURCE=lock
UNSLOTH_SOURCE=lock
INSTALLED_AT=2026-08-30T12:14:19+09:00
```

- `INSTALL_SOURCE=lock` — 릴리스에 동봉된 검증본을 그대로 설치했습니다. 버전이 고정된 상태입니다.
- `INSTALL_SOURCE=compile` — lock을 받지 못해 설치 시점에 다시 해석했습니다. `main` 스크립트를 쓰면 정상이지만, 릴리스 스크립트에서 이게 뜨면 버전 고정이 걸리지 않은 것입니다.

같은 내용이 `/workspace/lab/AGENTS.md` 끝에도 표로 들어갑니다. 이 파일이 아예 없으면 설치가 중간에 실패한 것입니다.

## 버전 고정 세부 동작

- 설치 로그의 `[6/N] ... (버전: ...)` 줄과 `lock 사용: ...` 줄에서 어떤 버전이 적용됐는지 확인할 수 있습니다.
- 다른 버전으로 설치: `NOTOLAB_REF=2026-09 bash setup_sllm.sh`
- lock을 무시하고 다시 해석: `NOTOLAB_LOCK=0 bash setup_sllm.sh`

오래된 버전은 언젠가 깨집니다. PyPI에서 패키지가 내려가거나 컨테이너 이미지의 드라이버와 CUDA 빌드가 맞지 않으면 설치가 실패할 수 있습니다. 그럴 때는 최신 버전을 쓰거나 `NOTOLAB_LOCK=0`으로 다시 해석하세요.

### 강사용: 새 버전 배포

1. manifest를 고쳐 `main`에 푸시합니다.
2. GPU 컨테이너에서 lock 5개를 새로 뽑고 설치·런타임까지 검증합니다.
3. 검증한 lock을 `locks/`에 두고 실행합니다.

```bash
bash release.sh 2026-10
```

`release.sh`는 lock을 만들지 않고 `locks/`의 검증본을 그대로 올립니다. manifest에 있는 패키지가 lock에 빠져 있거나 `==` 핀이 어긋나면 배포를 거부하고, 업로드 후 에셋 5개가 다 올라갔는지도 확인합니다.

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

## llama.cpp

PEFT / 소형 LLM / 에이전트 과정은 사전 빌드된 llama.cpp가 `/opt/llama.cpp`에 설치되고 `/usr/local/bin`에 링크됩니다.

```bash
llama-server -hf <저장소>:<양자화> --alias <이름> --port 8080 -c 32768 -ngl auto --jinja
```

배포 바이너리는 Compute Capability 8.6 이상 전용입니다. 그 미만 GPU에서는 설치를 건너뛰고 소스 빌드 안내를 출력합니다.

## 참고 사항 (RunPod/NotoLab 환경 한정)

**아래 내용은 RunPod 기반 NotoLab 컨테이너에서 불러올 때 기준이며, 일반 로컬 세팅에는 해당하지 않습니다.**

setup 스크립트는 옆에 있는 로컬 파일이 아니라 GitHub에서 패키지 목록을 내려받아 설치합니다. 어느 버전에서 받을지는 스크립트 맨 위 `NOTOLAB_REF`가 정하며 기본값은 `main`입니다. 따라서 `main` 스크립트를 쓸 때 manifest 수정은 **main 에 푸시된 뒤에야** 수강생 환경에 반영됩니다.

캐시와 가상환경은 모두 로컬 디스크 /tmp 에 둡니다. /workspace 는 FUSE 네트워크 스토리지라 대량 I/O 가 느립니다. 기본 서빙 버전인 vLLM 0.24.0 은 가상환경에 설치되며, 그 외 버전은 uvx 로 실행합니다.

자세한 규칙은 AGENTS.md 를 참고하세요.
