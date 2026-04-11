FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# O Railway injeta a porta automaticamente.
# WEB_CONCURRENCY permite escalar verticalmente por processo (ex.: 2-4 workers).
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers ${WEB_CONCURRENCY:-2} --timeout-keep-alive ${UVICORN_KEEPALIVE:-20} --limit-concurrency ${UVICORN_LIMIT_CONCURRENCY:-200} --backlog ${UVICORN_BACKLOG:-2048}"]
