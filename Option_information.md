다음은 최신 정보를 반영한 **LLM 모델별 하이퍼파라미터 기준 최종 정리본**입니다.

---

# 📌 LLM 모델별 하이퍼파라미터 기준 (최종본)

## OpenAI

| 모델          | Max tokens (컨텍스트 한도)                      | temperature | top\_p  | 기타 파라미터                                                                   | 비고                       |
| ----------- | ----------------------------------------- | ----------- | ------- | ------------------------------------------------------------------------- | ------------------------ |
| GPT-4o      | 4,096–16,384                              | 0.0–2.0     | 0.0–1.0 | —                                                                         | 모든 샘플링 파라미터 지원           |
| GPT-4o-mini | 4,096–16,384                              | 0.0–2.0     | 0.0–1.0 | —                                                                         | 모든 샘플링 파라미터 지원           |
| GPT-5       | **입력 272K + 출력(reasoning) 128K → 총 400K** | —           | —       | `reasoning.effort`(minimal/low/medium/high), `verbosity`(low/medium/high) | temperature / top\_p 미지원 |
| GPT-5-mini  | **입력 272K + 출력(reasoning) 128K → 총 400K** | —           | —       | `reasoning.effort`(minimal/low/medium/high), `verbosity`(low/medium/high) | temperature / top\_p 미지원 |

---

## Anthropic (Claude)

| 모델               | Max tokens\* | temperature | top\_p  | 비고         |
| ---------------- | ------------ | ----------- | ------- | ---------- |
| Claude 3.5 Haiku | 8,192        | 0.0–1.0     | 0.0–1.0 | 모든 파라미터 지원 |
| Claude Sonnet 4  | 64,000       | 0.0–1.0     | 0.0–1.0 | 모든 파라미터 지원 |
| Claude Opus 4.1  | 32,000       | 0.0–1.0     | 0.0–1.0 | 모든 파라미터 지원 |

> \* `Max tokens`는 입력+출력 합산 기준이며, 실제 사용 가능 한도는 API 호스팅 환경(예: Bedrock)과 설정에 따라 다를 수 있음.

---

## Google Gemini

| 모델               | Max tokens   | temperature | top\_p  | 기타 파라미터           | 비고             |
| ---------------- | ------------ | ----------- | ------- | ----------------- | -------------- |
| Gemini 2.5 Flash | 8,192–65,536 | 0.0–2.0     | 0.0–1.0 | `thinking_budget` | 모든 샘플링 파라미터 지원 |
| Gemini 2.5 Pro   | 8,192–65,536 | 0.0–2.0     | 0.0–1.0 | `thinking_budget` | 모든 샘플링 파라미터 지원 |

---

## 참고 사항

* **OpenAI GPT-5 계열**: 샘플링 파라미터(`temperature`, `top_p`) 미지원. 대신 `reasoning.effort`와 `verbosity`로 응답 스타일·길이 조절.
* **Claude**: 모든 모델이 `temperature`, `top_p`, `max_tokens_to_sample` 지원.
* **Gemini**: 모든 모델이 `temperature`, `top_p` 지원하며, `thinking_budget`으로 추론 리소스 조절 가능.
* **실제 사용 한도**는 API 버전, 호스팅 환경(예: OpenAI API, AWS Bedrock, Vertex AI) 및 조직 설정에 따라 달라질 수 있음.

---

원하시면 제가 이 표를 **API 호출 예제 코드**와 함께 연결해서, 실제 하이퍼파라미터 설정 샘플을 만들어 드릴 수도 있습니다.
그렇게 하면 실무에서 바로 테스트 가능하게 됩니다.
