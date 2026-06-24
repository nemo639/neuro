# NeuroVerse

NeuroVerse is a multimodal digital health platform for early neurological screening.
It combines a Flutter mobile app, a FastAPI backend, and two Next.js dashboards to support patient assessment, clinician review, and admin operations.

The system is designed around non-invasive screening workflows for:

- Alzheimer's disease screening using speech, cognitive, and drawing-based tasks
- Parkinson's disease screening using motor, gait, and facial analysis tasks
- Explainable AI outputs for clinician-facing interpretation

## Product Overview

NeuroVerse provides a complete workflow from patient data capture to decision support:

1. The mobile app collects speech recordings, drawing inputs, motor tasks, gait signals, and facial analysis inputs.
2. The backend stores data, manages authentication, and exposes REST APIs.
3. Machine learning services extract features, run predictors, fuse results, and generate explanations.
4. The doctor dashboard shows patients, reports, and alerts.
5. The admin dashboard manages users, doctors, and platform activity.

## Repository Structure

- `lib/` - Flutter mobile app
- `neuroverse-backend/` - FastAPI backend and ML pipeline
- `doctor-dashboard/` - Next.js dashboard for clinicians
- `admin-dashboard/` - Next.js dashboard for administrators
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` - Flutter platform targets
- `test/` - Flutter tests
- `assets/` - App assets and images

## Core Features

### Mobile App

- Patient authentication and profile management
- Speech tasks and cognitive assessments
- Drawing-based assessments such as clock drawing, spiral, and meander
- Motor and gait evaluation tasks
- Facial analysis capture using camera input
- Notifications, sharing, and local storage support

### Backend

- JWT-based authentication and role handling
- REST API for users, reports, sessions, doctors, admin, notifications, and feedback
- ML feature extraction, prediction, fusion, and explainability
- Database integration for persistent records

### Dashboards

- Doctor dashboard for patient review and reports
- Admin dashboard for user and system management

## Technology Stack

- Flutter
- FastAPI
- Python
- PyTorch
- Next.js
- Tailwind CSS
- PostgreSQL / Supabase
- Playwright for end-to-end testing

## Prerequisites

- Flutter SDK
- Dart SDK
- Python 3.11 or newer
- Node.js 18 or newer
- Git

For mobile testing, install Android Studio or Xcode as needed.

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/nemo639/neuro.git
cd neuroverse
```

### 2. Flutter app

```bash
flutter pub get
flutter run
```

### 3. Backend

```bash
cd neuroverse-backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### 4. Doctor dashboard

```bash
cd doctor-dashboard
npm install
npm run dev
```

### 5. Admin dashboard

```bash
cd admin-dashboard
npm install
npm run dev
```

## Configuration

The Flutter app communicates with the backend through `lib/core/api_service.dart`.
If you are running locally, update the backend base URL there to match your machine or network IP.

Environment-specific secrets, tokens, and API keys should not be committed to the repository.

## Testing

### Flutter tests

```bash
flutter test
```

### Backend tests

```bash
cd neuroverse-backend
python -m pytest tests/
```

### Dashboard end-to-end tests

```bash
cd doctor-dashboard
npx playwright test

cd ../admin-dashboard
npx playwright test
```

## Deployment Notes

- Deploy the backend on a cloud runtime such as Google Cloud Run or a container platform.
- Build the Flutter app for Android, iOS, or web depending on the target release.
- Deploy the dashboards separately as Next.js applications.

## Testing Summary

NeuroVerse includes automated validation across the stack:

- Backend API tests
- ML and XAI tests
- Flutter widget and service tests
- Playwright dashboard tests

## About This Project

NeuroVerse is a final-year project focused on building a practical, explainable screening platform for neurological health assessment.

## License

No license has been specified yet.
