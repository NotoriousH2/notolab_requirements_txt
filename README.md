# NotoLab Requirements

Last Updated : 2026-08-30

NotoLab 강의 수강생을 위한 실습 환경 설치 파일 모음입니다.
NotoLab 컨테이너에서 스크립트 한 줄로 과정에 맞는 Python 환경을 구성합니다.

## 시작하기

수업에서는 RunPod 템플릿으로 NotoLab 컨테이너를 실행합니다.

- 수업용 RunPod 템플릿: https://console.runpod.io/deploy?template=lom3sqxgoc&ref=88shxnpk
- RunPod 가입: https://runpod.io?ref=88shxnpk

## 사용 방법

### 수업 시점 환경 그대로 (권장)

[릴리스 페이지](https://github.com/NotoriousH2/notolab_requirements_txt/releases)에서 수강한 시점의 버전을 열고, 과정에 맞는 `setup_*.sh`를 받아 실행합니다.

```bash
bash setup_sllm.sh
```

GPU 컨테이너에서 검증한 조합을 그대로 설치하므로 몇 달 뒤에도 같은 환경이 구성됩니다.

### 최신 버전

`main`의 스크립트는 설치 시점에 의존성을 다시 해석합니다.

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

## 설치 후

가상환경 `/tmp/.venv`가 `~/.bashrc`에서 자동으로 활성화됩니다.
Jupyter에서는 커널 `NotoLab`을 선택합니다.

```bash
source /tmp/.venv/bin/activate
```

심화, PEFT, 소형 LLM 과정은 unsloth 실습용 환경을 하나 더 만듭니다.
transformers와 trl 요구 버전이 메인 환경과 달라 분리하며, 해당 실습에서는 커널을 `NotoLab (Unsloth)`로 바꿉니다.

setup을 다시 실행하면 가상환경이 새로 만들어지므로, 직접 `pip install`한 패키지는 다시 설치하세요.

## 내 환경 확인하기

설치가 끝나면 `/workspace/lab/.notolab-env`에 결과가 기록됩니다.

```
NOTOLAB_REF=2026-09
INSTALL_SOURCE=lock
UNSLOTH_SOURCE=lock
INSTALLED_AT=2026-08-30T12:14:19+09:00
```

| INSTALL_SOURCE | 의미 |
|---|---|
| `lock` | 릴리스에 동봉된 검증본을 그대로 설치했습니다. 버전이 고정된 상태입니다. |
| `compile` | 설치 시점에 의존성을 다시 해석했습니다. `main` 스크립트에서는 이 값이 정상이며, 릴리스 스크립트에서 출력되면 버전 고정이 풀린 상태입니다. |

같은 내용이 `/workspace/lab/AGENTS.md` 끝에도 표로 들어갑니다.
이 파일이 없으면 설치가 중간에 실패한 것입니다.

## 환경변수

| 변수 | 기본값 | 용도 |
|---|---|---|
| `NOTOLAB_REF` | `main` | 패키지 목록을 받아올 버전. 릴리스 사본에는 해당 태그가 들어 있습니다. |
| `NOTOLAB_LOCK` | `1` | `0`이면 lock을 건너뛰고 설치 시점에 다시 해석합니다. |

```bash
NOTOLAB_REF=2026-09 bash setup_sllm.sh
NOTOLAB_LOCK=0 bash setup_sllm.sh
```

오래된 버전은 언젠가 설치가 실패합니다.
PyPI에서 패키지가 내려가거나 컨테이너 이미지의 드라이버와 CUDA 빌드가 어긋나는 경우입니다.
그럴 때는 최신 버전을 쓰거나 `NOTOLAB_LOCK=0`으로 다시 해석하세요.

## 과정별 패키지 목록

| 패키지 목록 파일 | 용도 | CUDA |
|------------|------|------|
| requirements_adv.txt | 심화 과정 | 13.0 (cu130) |
| requirements_PEFT.txt | PEFT 과정 | 13.0 (cu130) |
| requirements_sLLM.txt | 소형 LLM 과정 | 13.0 (cu130) |
| requirements_agent.txt | 에이전트 과정 (MCP, Slack, 트레이싱, 브라우저 도구) | 해당 없음 (PyTorch 제외) |
| requirements_unsloth.txt | unsloth 실습 (심화, PEFT, 소형 LLM 과정에 별도 환경으로 설치) | 13.0 (cu130) |

## vLLM 실행 예시

심화, PEFT, 소형 LLM 과정은 `vllm==0.24.0`이 가상환경에 함께 설치됩니다.

```bash
vllm serve <model_name>
```

다른 버전으로 서빙할 때는 가상환경에 설치하지 말고 `uvx`로 실행합니다.

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

PEFT, 소형 LLM, 에이전트 과정은 사전 빌드된 llama.cpp를 `/opt/llama.cpp`에 설치하고 `/usr/local/bin`에 링크합니다.

```bash
llama-server -hf <저장소>:<양자화> --alias <이름> --port 8080 -c 32768 -ngl auto --jinja
```

배포 바이너리는 Compute Capability 8.6 이상 전용입니다.
그 미만 GPU에서는 설치를 건너뛰고 소스 빌드 안내를 출력합니다.

## 참고 사항 (RunPod/NotoLab 환경 한정)

아래 내용은 RunPod 기반 NotoLab 컨테이너 기준이며, 일반 로컬 세팅에는 해당하지 않습니다.

setup 스크립트는 GitHub에서 패키지 목록을 내려받아 설치합니다.
어느 버전에서 받을지는 `NOTOLAB_REF`가 정합니다.
`main` 스크립트를 쓸 때 패키지 목록 수정은 main에 푸시된 뒤에 수강생 환경으로 반영됩니다.

캐시와 가상환경은 모두 로컬 디스크 `/tmp`에 둡니다.
`/workspace`는 FUSE 네트워크 스토리지라 대량 I/O가 느립니다.

자세한 규칙은 AGENTS.md를 참고하세요.
