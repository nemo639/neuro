# NeuroVerse Backend - CPU Optimized for Railway
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libsndfile1 \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first (Docker cache)
COPY requirements.txt .

# Install PyTorch CPU-only (smaller + faster build) then other deps
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir -r requirements.txt

# Copy application code (v10 - XAI audit fix)
COPY app/ ./app/

# Create uploads directory
RUN mkdir -p uploads

# Expose port (Railway sets PORT env var)
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

# Start server - Railway provides PORT env var
CMD python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 2
