FROM python:3.13.7-alpine

WORKDIR /app

RUN apk upgrade --no-cache
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appgroup . .

EXPOSE 8080

USER appuser

CMD ["python", "main.py"]