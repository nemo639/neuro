# NeuroVerse

<p align="center">
  <img src="assets/images/logo.png" alt="NeuroVerse Logo" width="180"/>
</p>

<p align="center">
  <b>Multimodal Explainable AI Platform for Early Neurological Screening</b><br/>
  Alzheimer's Disease · Parkinson's Disease · Clinical Decision Support
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.11-blue?style=flat-square&logo=python"/>
  <img src="https://img.shields.io/badge/PyTorch-2.x-orange?style=flat-square&logo=pytorch"/>
  <img src="https://img.shields.io/badge/FastAPI-0.110-green?style=flat-square&logo=fastapi"/>
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?style=flat-square&logo=flutter"/>
  <img src="https://img.shields.io/badge/GCP-Cloud%20Run-yellow?style=flat-square&logo=googlecloud"/>
  <img src="https://img.shields.io/badge/License-Research%20Only-red?style=flat-square"/>
</p>

---

## Overview

NeuroVerse is a full-stack multimodal digital health platform for early, non-invasive neurological screening. It fuses speech, cognitive, drawing, motor, gait, and facial biomarkers across **15,000+ samples** to detect early signs of Alzheimer's and Parkinson's disease — achieving **87% classification accuracy**, 14% above single-modality baselines.

The system pairs deep learning prediction with **SHAP-based explainability** so clinicians understand not just what the model predicted, but why — enabling clinical auditability and trust.

---

## Key Results

| Metric | Value |
|---|---|
| Classification Accuracy | 87% (multimodal fusion) |
| Single-modality Baseline | ~73% |
| Improvement over Baseline | +14% |
| Dataset Size | 15,000+ samples |
| Modalities Fused | 4 (speech, cognitive, motor/gait, facial) |
| Explainability Method | SHAP feature attribution + saliency mapping |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                       │
│   Speech · Drawing · Motor/Gait · Facial · Cognitive Tasks  │
└───────────────────────┬─────────────────────────────────────┘
                        │ REST API (JWT Auth)
┌───────────────────────▼─────────────────────────────────────┐
│                   FastAPI Backend                            │
│   Auth · Sessions · Reports · Notifications · Admin API     │
└──────┬────────────────┬───────────────────────┬─────────────┘
       │                │                       │
┌──────▼──────┐  ┌──────▼──────┐  ┌────────────▼────────────┐
│  ML Pipeline │  │  Supabase   │  │     Next.js Dashboards  │
│             │  │ (PostgreSQL) │  │  Doctor · Admin         │
│ Encoders    │  └─────────────┘  └─────────────────────────┘
│ Fusion      │
│ SHAP/XAI    │
└─────────────┘
```

### ML Pipeline Architecture

```
Speech Input    → BiLSTM Encoder      ─┐
Cognitive Input → MLP Encoder         ─┤
Facial Input    → ResNet50 Encoder    ─┼→ Attention-Weighted
Motor/Gait Input→ CNN+BiLSTM Encoder  ─┘   Late Fusion
                                            │
                                            ▼
                                     Final Classifier
                                            │
                                    ┌───────┴────────┐
                                    │  Prediction    │
                                    │  SHAP Values   │
                                    │  Saliency Maps │
                                    └────────────────┘
```

**Why late fusion?**
Each modality has its own encoder that learns modality-specific representations before fusion. This outperforms early fusion (concatenating raw features) because feature spaces across modalities are too heterogeneous for joint early learning. Attention-weighted concatenation allows the model to dynamically weight each modality's contribution based on input quality.

---

## Product Overview

NeuroVerse provides a complete workflow from patient data capture to clinical decision support:

1. **Mobile App** — collects speech, drawing, motor, gait, and facial inputs from patients
2. **FastAPI Backend** — handles authentication, data storage, and REST API exposure
3. **ML Services** — extract features, run modality encoders, fuse predictions, generate SHAP explanations
4. **Doctor Dashboard** — shows patient reports, screening alerts, and XAI outputs
5. **Admin Dashboard** — manages users, doctors, and platform activity

---

## Repository Structure

```
neuroverse/
├── lib/                        # Flutter mobile app
│   ├── core/                   # API service, constants, theme
│   ├── features/               # Feature modules (auth, assessment, reports)
│   └── shared/                 # Shared widgets and utilities
├── neuroverse-backend/         # FastAPI backend + ML pipeline
│   ├── app/
│   │   ├── main.py             # FastAPI entrypoint
│   │   ├── api/                # Route handlers
│   │   ├── models/             # Pydantic + DB models
│   │   ├── ml/                 # ML pipeline
│   │   │   ├── encoders/       # Modality-specific encoders
│   │   │   ├── fusion/         # Late fusion + attention
│   │   │   ├── explainability/ # SHAP + saliency mapping
│   │   │   └── predictor.py    # Inference pipeline
│   │   └── services/           # Auth, storage, notifications
│   ├── tests/                  # Pytest test suite
│   ├── requirements.txt
│   └── Dockerfile
├── doctor-dashboard/           # Next.js clinician dashboard
│   ├── app/                    # Next.js app router
│   ├── components/             # UI components
│   └── tests/                  # Playwright E2E tests
├── admin-dashboard/            # Next.js admin dashboard
├── android/                    # Flutter Android target
├── ios/                        # Flutter iOS target
├── web/                        # Flutter web target
├── test/                       # Flutter widget tests
├── assets/                     # App assets and images
├── docker-compose.yml          # Local development orchestration
└── cloudbuild.yaml             # GCP Cloud Build configuration
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter 3.x, Dart |
| Backend | FastAPI, Python 3.11, Uvicorn |
| ML Framework | PyTorch 2.x, Hugging Face, SHAP |
| Dashboards | Next.js 14, Tailwind CSS, TypeScript |
| Database | PostgreSQL via Supabase |
| Auth | JWT, Supabase Auth |
| Storage | Supabase Storage (audio, images) |
| Deployment | GCP Cloud Run, Cloud Build, Artifact Registry |
| Containers | Docker, Docker Compose |
| E2E Testing | Playwright |
| API Testing | Pytest, HTTPX |

---

## Prerequisites

```
Flutter SDK >= 3.0
Dart SDK >= 3.0
Python >= 3.11
Node.js >= 18
Docker >= 24
Git
GCP account (for cloud deployment)
```

For mobile testing install Android Studio or Xcode as needed.

---

## Local Development Setup

### 1. Clone the repository

```bash
git clone https://github.com/nemo639/neuro.git
cd neuroverse
```

### 2. Environment variables

Create a `.env` file in `neuroverse-backend/`:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_service_role_key
JWT_SECRET=your_jwt_secret
ENVIRONMENT=development
MODEL_PATH=app/ml/weights/
```

> Never commit `.env` files. Add to `.gitignore` immediately.

### 3. Flutter app

```bash
flutter pub get
flutter run
```

Update backend URL in `lib/core/api_service.dart` to match your local IP.

### 4. Backend

```bash
cd neuroverse-backend
python -m venv .venv

# Windows
.venv\Scripts\activate

# macOS/Linux
source .venv/bin/activate

pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

API docs available at: `http://localhost:8000/docs`

### 5. Doctor dashboard

```bash
cd doctor-dashboard
npm install
npm run dev
# Runs on http://localhost:3000
```

### 6. Admin dashboard

```bash
cd admin-dashboard
npm install
npm run dev
# Runs on http://localhost:3001
```

### 7. Full stack with Docker Compose

```bash
docker-compose up --build
```

---

## Testing

### Backend API tests

```bash
cd neuroverse-backend
python -m pytest tests/ -v
```

### Backend ML pipeline tests

```bash
cd neuroverse-backend
python -m pytest tests/ml/ -v --tb=short
```

Tests cover:
- Feature extraction per modality
- Fusion layer output shapes
- SHAP value generation
- Predictor end-to-end inference
- API endpoint response validation

### Flutter widget and unit tests

```bash
flutter test
flutter test --coverage
```

### Dashboard E2E tests (Playwright)

```bash
# Doctor dashboard
cd doctor-dashboard
npx playwright install
npx playwright test

# Admin dashboard
cd admin-dashboard
npx playwright test

# With UI mode
npx playwright test --ui
```

### Full test suite

```bash
# Backend
cd neuroverse-backend && python -m pytest tests/ -v

# Flutter
flutter test

# Dashboards
cd doctor-dashboard && npx playwright test
cd admin-dashboard && npx playwright test
```

---

## GCP Deployment

NeuroVerse backend deploys to **Google Cloud Run** via **Cloud Build** with container images stored in **Artifact Registry**.

### Prerequisites

```bash
# Install Google Cloud CLI
# https://cloud.google.com/sdk/docs/install

gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

### Step 1 — Create Artifact Registry repository

```bash
gcloud artifacts repositories create neuroverse \
  --repository-format=docker \
  --location=us-central1 \
  --description="NeuroVerse container images"
```

### Step 2 — Build and push Docker image

```bash
cd neuroverse-backend

# Build image
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/neuroverse/backend:latest .

# Configure Docker auth
gcloud auth configure-docker us-central1-docker.pkg.dev

# Push image
docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/neuroverse/backend:latest
```

### Step 3 — Deploy to Cloud Run

```bash
gcloud run deploy neuroverse-backend \
  --image us-central1-docker.pkg.dev/YOUR_PROJECT_ID/neuroverse/backend:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8000 \
  --memory 2Gi \
  --cpu 2 \
  --set-env-vars SUPABASE_URL=your_url,SUPABASE_KEY=your_key,ENVIRONMENT=production
```

### Step 4 — CI/CD with Cloud Build

The `cloudbuild.yaml` in the root triggers automatic build and deploy on every push to `main`:

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - build
      - -t
      - us-central1-docker.pkg.dev/$PROJECT_ID/neuroverse/backend:$COMMIT_SHA
      - ./neuroverse-backend

  - name: 'gcr.io/cloud-builders/docker'
    args:
      - push
      - us-central1-docker.pkg.dev/$PROJECT_ID/neuroverse/backend:$COMMIT_SHA

  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - run
      - deploy
      - neuroverse-backend
      - --image
      - us-central1-docker.pkg.dev/$PROJECT_ID/neuroverse/backend:$COMMIT_SHA
      - --region
      - us-central1
      - --platform
      - managed
```

### Step 5 — Connect Cloud Build to GitHub

```bash
# In GCP Console:
# Cloud Build → Triggers → Connect Repository → GitHub
# Set trigger on push to main branch
```

### Step 6 — Deploy dashboards to Cloud Run

```bash
# Build doctor dashboard
cd doctor-dashboard
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/neuroverse/doctor-dashboard:latest .
docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/neuroverse/doctor-dashboard:latest

gcloud run deploy neuroverse-doctor-dashboard \
  --image us-central1-docker.pkg.dev/YOUR_PROJECT_ID/neuroverse/doctor-dashboard:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 3000
```

### Step 7 — Update Flutter app with production URL

After Cloud Run deployment, update `lib/core/api_service.dart`:

```dart
const String baseUrl = "https://neuroverse-backend-xxxx-uc.a.run.app";
```

Rebuild Flutter app for production:

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

### GCP Services Used

| Service | Purpose |
|---|---|
| Cloud Run | Serverless container hosting for backend + dashboards |
| Cloud Build | CI/CD pipeline — auto build and deploy on push |
| Artifact Registry | Docker image storage |
| Cloud Logging | Runtime logs and monitoring |
| Cloud Monitoring | Uptime checks and alerts |
| Supabase | PostgreSQL database + Auth + Storage |

---

## API Reference

Full interactive docs available at `/docs` (Swagger UI) and `/redoc` when backend is running.

| Method | Endpoint | Description |
|---|---|---|
| POST | `/auth/register` | Register new user |
| POST | `/auth/login` | Login and get JWT token |
| GET | `/patients/` | List all patients |
| POST | `/sessions/` | Create screening session |
| POST | `/ml/predict` | Run multimodal prediction |
| GET | `/reports/{id}` | Get screening report with SHAP |
| GET | `/admin/users` | Admin — list all users |

---

## Explainability

NeuroVerse generates SHAP (SHapley Additive exPlanations) values for every prediction — giving clinicians feature-level attribution:

- Which modality contributed most to the prediction
- Which speech features were most informative
- Which motor signals indicated abnormality
- Saliency maps for drawing and facial inputs

This makes the system clinically auditable — doctors are not shown a black-box score but a transparent explanation aligned with clinical intuition.

---

## Research Context

NeuroVerse is a Final Year Project at FAST-NUCES under supervision of **Dr. Sahar Ajmal**, focusing on building practical, explainable AI for neurological health assessment. The work spans:

- Multimodal deep learning for clinical biomarker fusion
- Explainable AI for clinical auditability
- Mobile-first deployment for low-resource screening settings

---

## License

This project is for research and educational purposes only. Not approved for clinical use. No license for commercial use or redistribution has been granted.

---

## Contact

**Muhammad Naeem**
FAST-NUCES | AI/ML Engineer
naeemubeen639@gmail.com | [LinkedIn](https://linkedin.com) | [GitHub](https://github.com/nemo639) | [Medium](https://medium.com)
