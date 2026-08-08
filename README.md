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

## 과정별 패키지 목록

| 패키지 목록 파일 | 용도 | CUDA |
|------------|------|------|
| requirements_adv.txt | 심화 과정 | 13.0 (cu130) |
| requirements_PEFT.txt | PEFT 과정 | 13.0 (cu130) |
| requirements_sLLM.txt | 소형 LLM 과정 | 13.0 (cu130) |
| requirements_agent.txt | 에이전트 과정 (MCP, Slack, 트레이싱, 브라우저 도구) | 해당 없음 (PyTorch 미설치) |

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
