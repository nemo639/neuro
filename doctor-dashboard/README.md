# NeuroVerse Doctor Dashboard

A modern, animated web dashboard for doctors to monitor and manage patients with neurological health risks. Built with Next.js 14, TypeScript, Tailwind CSS, and Framer Motion.

## 🧠 Features

- **Dashboard Overview**: Real-time statistics, risk trends, and patient summaries
- **Patient Management**: Search, filter, and view detailed patient profiles
- **Clinical Notes**: Document and track patient observations
- **Alerts System**: Critical notifications for high-risk patients
- **Reports**: Generate and download comprehensive diagnostic reports
- **Animated UI**: Beautiful, responsive design with smooth animations

## 🎨 Design System

The dashboard follows the NeuroVerse design system with:
- **Colors**: Matching the Flutter patient app (purple, blue, mint, lavender)
- **Glassmorphism**: Frosted glass card effects
- **Animations**: Framer Motion for smooth transitions
- **Charts**: Recharts for data visualization

## 🚀 Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn
- NeuroVerse FastAPI backend running

### Installation

1. Navigate to the dashboard directory:
```bash
cd doctor-dashboard
```

2. Install dependencies:
```bash
npm install
```

3. Create environment file:
```bash
cp .env.example .env.local
```

4. Update `.env.local` with your API URL:
```
NEXT_PUBLIC_API_URL=http://your-api-url:8000/api/v1
```

5. Start the development server:
```bash
npm run dev
```

6. Open [http://localhost:3000](http://localhost:3000) in your browser.

## 📁 Project Structure

```
src/
├── app/
│   ├── dashboard/
│   │   ├── page.tsx           # Main dashboard
│   │   ├── layout.tsx         # Dashboard layout with sidebar
│   │   ├── patients/          # Patients list & detail pages
│   │   ├── notes/             # Clinical notes
│   │   ├── alerts/            # Notifications & alerts
│   │   ├── reports/           # Reports management
│   │   └── settings/          # User settings
│   ├── login/                 # Authentication
│   ├── globals.css            # Global styles
│   └── layout.tsx             # Root layout
├── components/
│   └── ui/                    # Reusable UI components
├── contexts/
│   └── AuthContext.tsx        # Authentication context
└── lib/
    ├── api.ts                 # API service methods
    └── utils.ts               # Utility functions
```

## 🔗 API Integration

The dashboard connects to the FastAPI backend at:
- `POST /doctors/login` - Authentication
- `GET /doctors/dashboard` - Dashboard stats
- `GET /doctors/patients` - Patient list
- `GET /doctors/patients/{id}` - Patient details
- `POST /doctors/notes` - Create notes
- `GET /doctors/alerts` - Get alerts

## 🎯 Key Pages

### Dashboard (`/dashboard`)
- Quick stats cards (total patients, high-risk, pending reviews)
- Risk trend charts (AD/PD over time)
- Recent patients list
- Pending reviews section

### Patients (`/dashboard/patients`)
- Search and filter patients
- Risk level indicators
- Patient detail modals
- Test history

### Patient Detail (`/dashboard/patients/[id]`)
- Full patient profile
- Risk score trends
- Complete test history
- XAI explanations (coming soon)

### Clinical Notes (`/dashboard/notes`)
- Create and manage notes
- Filter by note type
- Flag important notes

### Alerts (`/dashboard/alerts`)
- Critical risk notifications
- New test completions
- Pending reviews

## 🛠️ Built With

- [Next.js 14](https://nextjs.org/) - React framework
- [TypeScript](https://www.typescriptlang.org/) - Type safety
- [Tailwind CSS](https://tailwindcss.com/) - Styling
- [Framer Motion](https://www.framer.com/motion/) - Animations
- [Recharts](https://recharts.org/) - Charts
- [Radix UI](https://www.radix-ui.com/) - Headless components
- [Lucide Icons](https://lucide.dev/) - Icons

## 📝 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXT_PUBLIC_API_URL` | FastAPI backend URL | `http://10.54.16.25:8000/api/v1` |

## 🔐 Authentication

The dashboard uses JWT tokens for authentication:
1. Doctor logs in with email/password
2. Token stored in localStorage
3. Token included in API requests
4. Protected routes redirect to login if unauthenticated

## 📱 Responsive Design

The dashboard is fully responsive:
- **Desktop**: Full sidebar navigation
- **Tablet**: Collapsible sidebar
- **Mobile**: Bottom navigation (coming soon)

## 🤝 Contributing

This is part of the NeuroVerse FYP project. For contributions, please coordinate with the project team.

## 📄 License

Proprietary - NeuroVerse Project

---

Built with 💜 for neurological health screening
