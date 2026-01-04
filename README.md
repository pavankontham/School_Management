# School Management System

A comprehensive school management system with AI-powered features including face recognition attendance, AI chatbot for doubt clearing, and complete academic management.

## Features

### For Principals
- Dashboard with school-wide analytics
- Teacher management (CRUD operations)
- Student management (CRUD operations)
- Class and subject management
- View attendance reports
- Monitor academic performance

### For Teachers
- Take attendance (Manual & Face Recognition)
- Manage marks and grades
- Create and manage quizzes
- Upload textbooks and study materials
- Add student remarks
- AI-powered chatbot for student queries
- Class-wise student management

### For Students
- View attendance records
- Check marks and grades
- Take quizzes
- Access textbooks and materials
- AI chatbot for doubt clearing
- View remarks and feedback

## Tech Stack

### Backend
- **Runtime**: Node.js with Express.js
- **Database**: PostgreSQL with Prisma ORM
- **Authentication**: JWT (Access + Refresh tokens)
- **AI Integration**: Google Gemini API
- **File Storage**: Local storage with cloud-ready architecture

### Frontend (Mobile App)
- **Framework**: Flutter
- **State Management**: flutter_bloc
- **Architecture**: Clean Architecture with Repository Pattern
- **Local Storage**: SharedPreferences

### Face Recognition Service
- **Language**: Python
- **Libraries**: face_recognition, OpenCV

## Project Structure

```
School_Management/
├── backend/                 # Node.js Express API
│   ├── src/
│   │   ├── middleware/     # Auth, validation middleware
│   │   ├── routes/         # API routes
│   │   └── utils/          # Helpers and utilities
│   ├── prisma/             # Database schema
│   └── uploads/            # File uploads
├── flutter_app/            # Flutter mobile application
│   └── lib/
│       ├── core/           # Theme, utils, widgets
│       └── features/       # Feature modules (auth, principal, teacher, student)
└── face-recognition-service/  # Python face recognition
```

## Setup Instructions

### Backend Setup

1. Navigate to backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create `.env` file from example:
   ```bash
   cp .env.example .env
   ```

4. Update `.env` with your credentials:
   - DATABASE_URL: PostgreSQL connection string
   - JWT_SECRET: Secret key for JWT
   - GEMINI_API_KEY: Google Gemini API key

5. Run database migrations:
   ```bash
   npx prisma migrate dev
   ```

6. Seed the database:
   ```bash
   npx prisma db seed
   ```

7. Start the server:
   ```bash
   npm start
   ```

### Flutter App Setup

1. Navigate to flutter_app directory:
   ```bash
   cd flutter_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## API Endpoints

### Authentication
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/refresh` - Refresh access token
- `POST /api/v1/auth/logout` - User logout

### Principal Routes
- `GET/POST /api/v1/principal/teachers` - Manage teachers
- `GET/POST /api/v1/principal/students` - Manage students
- `GET/POST /api/v1/principal/classes` - Manage classes

### Teacher Routes
- `GET/POST /api/v1/teacher/attendance` - Attendance management
- `GET/POST /api/v1/teacher/marks` - Marks management
- `GET/POST /api/v1/teacher/quizzes` - Quiz management

### Student Routes
- `GET /api/v1/student/attendance` - View attendance
- `GET /api/v1/student/marks` - View marks
- `GET /api/v1/student/quizzes` - Access quizzes

## Default Login Credentials

After seeding the database:

| Role | Email | Password |
|------|-------|----------|
| Principal | principal@school.com | password123 |
| Teacher | teacher@school.com | password123 |
| Student | student@school.com | password123 |

## License

This project is for educational purposes.

