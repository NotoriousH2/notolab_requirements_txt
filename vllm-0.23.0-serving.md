# vLLM 0.23.0 서빙 (RunPod CUDA 12.8 환경)

이 파드(NVIDIA A40, 드라이버 **570.195.03 / CUDA 12.8**)에서 vLLM 0.23.0을 `uvx`로 서빙하는 검증된 커맨드.

## 동작 커맨드

```bash
export UV_CACHE_DIR=/tmp/.uv-cache PIP_CACHE_DIR=/tmp/.pip-cache HF_HOME=/tmp/hf
export UV_TORCH_BACKEND=auto

WHL="https://github.com/vllm-project/vllm/releases/download/v0.23.0/vllm-0.23.0+cu129-cp38-abi3-manylinux_2_28_x86_64.whl"

uvx --python 3.12 --from "$WHL" \
  --with "fastapi[standard]>=0.115.0,<0.137" \
  vllm serve Qwen/Qwen3.5-9B \
  --max-model-len 16384 \
  --gpu-memory-utilization 0.86 \
  --reasoning-parser qwen3 \
  --language-model-only \
  --speculative-config '{"method":"mtp","num_speculative_tokens":2}'
```

서버는 `http://0.0.0.0:8000` 에 뜬다 (OpenAI 호환 API).

## 원래 커맨드 대비 변경점

| # | 변경 | 이유 |
|---|------|------|
| 1 | `vllm==0.23.0` (PyPI) → **cu129 GitHub 휠** + `UV_TORCH_BACKEND=auto` | PyPI 기본 휠은 CUDA 13 빌드(`libcudart.so.13`)라 드라이버 12.8에서 GPU init 실패("driver too old / 12080"). `--torch-backend`만으론 vLLM `_C`가 cu13이라 안 됨. cu129 휠은 `libcudart.so.12`라 CUDA minor 호환으로 동작 |
| 2 | `--with "fastapi[standard]<0.137"` 추가 | 배포 휠 메타데이터에 fastapi 상한이 빠져 uvx가 0.137.2를 끌어옴 → fastapi 0.137의 `_IncludedRouter`로 **모든 요청 HTTP 500** (`'_IncludedRouter' object has no attribute 'path'`). vLLM `requirements/common.txt`의 의도(`<0.137`)대로 고정해 해결. 하한은 `starlette>=0.49.1`(vllm dep `model-hosting-container-standards`) 때문에 fastapi 0.116 미만 불가 |
| 3 | `--gpu-memory-utilization 0.5` → **0.86** | Qwen3.5는 하이브리드(Mamba+attention) 모델이라 0.5에선 Mamba 캐시 블록 부족(`max_num_seqs 256 > 115 blocks`)으로 CUDA graph capture 실패. 대안: 0.5 유지 + `--max-num-seqs <=115` |

## 검증 결과 (2026-06-18)

- GPU init 통과 (cu13 에러 없음)
- MTP speculative decoding 동작 (`Detected MTP model`)
- `--language-model-only` 텍스트 전용 서빙
- `--reasoning-parser qwen3` 정상
- `/v1/models` → HTTP 200
- `/v1/chat/completions` → HTTP 200, `12 x 8 = 96` 정답, `finish_reason: stop`

## 동작 점검

```bash
# 모델 목록
curl -s http://localhost:8000/v1/models

# 채팅 완료
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen3.5-9B","messages":[{"role":"user","content":"What is 12 x 8?"}],"max_tokens":1024,"temperature":0}'
```
