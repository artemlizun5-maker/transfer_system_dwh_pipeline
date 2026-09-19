FROM python:3.11-slim

WORKDIR /app

COPY docker/generator/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY transfers_dwh/generate_data.py .

CMD ["python", "generate_data.py"]