from groq import Groq
from dotenv import load_dotenv
import httpx
import os

load_dotenv()

api_key = os.getenv("GROQ_API_KEY")
if not api_key:
    print("ERROR: No se encontró GROQ_API_KEY en el .env")
    exit(1)

print(f"API Key encontrada: {api_key[:8]}...")

try:
    http_client = httpx.Client(verify=False)
    client = Groq(api_key=api_key, http_client=http_client)
    completion = client.chat.completions.create(
        model="llama-3.1-8b-instant",
        max_tokens=50,
        messages=[
            {"role": "user", "content": "Di solo: Groq funcionando correctamente en MathMágico"}
        ],
    )
    respuesta = completion.choices[0].message.content
    print(f"\nRespuesta de Groq: {respuesta}")
    print("\nOK: La API de Groq está funcionando correctamente.")
except Exception as e:
    print(f"\nERROR: {e}")
