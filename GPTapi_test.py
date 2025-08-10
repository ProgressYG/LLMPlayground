import os
from dotenv import load_dotenv
from openai import OpenAI

# .env 파일에서 환경변수 로드
load_dotenv()

# .env 파일 또는 환경변수에서 API 키 읽기
api_key = os.getenv('OPENAI_API_KEY') or os.getenv('OpenAIAPIKey')

if not api_key:
    raise ValueError("OpenAI API 키를 찾을 수 없습니다. .env 파일에 OPENAI_API_KEY를 설정하거나 환경변수를 확인해주세요.")

client = OpenAI(api_key=api_key)

def ask(model: str, prompt: str) -> str:
    resp = client.chat.completions.create(
        model=model,  # "gpt-5" 또는 "gpt-5-mini"
        messages=[{"role": "user", "content": prompt}]
        #temperature=0,7 ==> GTP5와 GTP5-mini는 Temperature 사용 불가
    )
    return resp.choices[0].message.content

if __name__ == "__main__":
    prompt = "파이썬으로 퀵소트(quick sort) 구현과 시간복잡도를 간단히 설명해줘."
    print("=== gpt-5 ===")
    print(ask("gpt-5-2025-08-07", prompt))
    print("\n=== gpt-5-mini ===")
    print(ask("gpt-5-mini-2025-08-07", prompt))

    
