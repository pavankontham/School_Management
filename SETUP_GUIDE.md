# Quick Setup Guide - Backend Services

## Prerequisites
- Node.js 18+ installed
- Python 3.8+ installed
- PostgreSQL database running
- Git installed

---

## 1. Backend Setup

### Install Dependencies
```bash
cd backend
npm install
```

### Configure Environment
```bash
# Copy example file
cp .env.example .env

# Edit .env and set:
# - DATABASE_URL (your PostgreSQL connection string)
# - JWT_SECRET (generate with: openssl rand -hex 32)
# - JWT_REFRESH_SECRET (generate with: openssl rand -hex 32)
# - BREVO_SMTP_USER (your Brevo email)
# - BREVO_SMTP_KEY (your Brevo API key)
# - ML_SERVICE_API_KEY (generate with: openssl rand -hex 32)
# - GEMINI_API_KEY (your Google Gemini API key)
```

### Run Database Migration
```bash
npx prisma migrate dev
npx prisma generate
```

### Start Backend Server
```bash
npm run dev
# Server runs on http://localhost:3000
```

---

## 2. Face Recognition Service Setup

### Create Virtual Environment
```bash
cd face-recognition-service
python -m venv venv

# Activate virtual environment:
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate
```

### Install Dependencies
```bash
pip install -r requirements.txt
```

### Configure Environment
```bash
# Create .env file
cp .env.example .env

# Edit .env and set:
# - API_KEY (use the SAME value as ML_SERVICE_API_KEY in backend .env)
# - PORT=5000
# - CORS_ORIGINS=http://localhost:3000
```

### Start ML Service
```bash
python main.py
# Service runs on http://localhost:5000
```

---

## 3. Verify Setup

### Check Backend Health
```bash
curl http://localhost:3000/health
# Should return: {"status":"ok","timestamp":"..."}
```

### Check ML Service Health
```bash
curl http://localhost:5000/health
# Should return: {"status":"healthy","service":"face-recognition",...}
```

### Test ML Service Authentication
```bash
# Without API key (should fail)
curl -X POST http://localhost:5000/detect \
  -F "image=@test-image.jpg"
# Should return: 401 Unauthorized

# With API key (should work)
curl -X POST http://localhost:5000/detect \
  -H "X-API-Key: your-api-key-here" \
  -F "image=@test-image.jpg"
# Should return face detection results
```

---

## 4. Common Issues & Solutions

### Issue: Prisma migration fails
**Solution**: Check DATABASE_URL is correct and PostgreSQL is running
```bash
# Test database connection
npx prisma db pull
```

### Issue: ML service can't find face_recognition
**Solution**: Install dlib dependencies first
```bash
# Windows: Install Visual Studio C++ Build Tools
# Mac: brew install cmake
# Linux: sudo apt-get install cmake
pip install dlib
pip install face_recognition
```

### Issue: Backend can't connect to ML service
**Solution**: 
1. Check ML service is running on port 5000
2. Verify API_KEY matches in both .env files
3. Check firewall isn't blocking port 5000

### Issue: Email sending fails
**Solution**: 
1. Verify Brevo credentials are correct
2. Check Brevo account is active
3. Review logs for specific error messages

---

## 5. Environment Variables Checklist

### Backend .env
- [x] DATABASE_URL
- [x] JWT_SECRET
- [x] JWT_REFRESH_SECRET
- [x] JWT_EXPIRES_IN=15m
- [x] JWT_REFRESH_EXPIRES_IN=7d
- [x] BREVO_SMTP_USER
- [x] BREVO_SMTP_KEY
- [x] SCHOOL_EMAIL
- [x] FRONTEND_URL
- [x] ML_SERVICE_URL=http://localhost:5000
- [x] ML_SERVICE_API_KEY
- [x] GEMINI_API_KEY
- [x] ENCRYPTION_KEY (32 characters)

### ML Service .env
- [x] PORT=5000
- [x] API_KEY (same as backend ML_SERVICE_API_KEY)
- [x] CORS_ORIGINS
- [x] FACE_DETECTION_MODEL=hog
- [x] FACE_MATCH_TOLERANCE=0.6

---

## 6. Testing the Fixes

### Test Student Authentication
```bash
# 1. Login as student
curl -X POST http://localhost:3000/api/v1/auth/login-student \
  -H "Content-Type: application/json" \
  -d '{"schoolId":"...","rollNumber":"...","password":"..."}'

# 2. Refresh token
curl -X POST http://localhost:3000/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"..."}'

# 3. Logout
curl -X POST http://localhost:3000/api/v1/auth/logout \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"..."}'
```

### Test Password Reset
```bash
# 1. Request reset
curl -X POST http://localhost:3000/api/v1/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'

# 2. Check email for reset link
# 3. Reset password
curl -X POST http://localhost:3000/api/v1/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{"token":"...","newPassword":"newpassword123"}'
```

### Test Face Recognition
```bash
# Upload student face (requires authentication)
curl -X POST http://localhost:3000/api/v1/face-recognition/upload-reference \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "photo=@student-photo.jpg" \
  -F "studentId=..."
```

---

## 7. Production Deployment

### Additional Steps for Production:
1. **Use strong, unique secrets**:
   ```bash
   # Generate secure keys
   openssl rand -hex 32  # For JWT secrets
   openssl rand -hex 32  # For API keys
   openssl rand -hex 16  # For encryption key
   ```

2. **Enable HTTPS**:
   - Get SSL certificates (Let's Encrypt)
   - Configure nginx reverse proxy
   - Update ML_SERVICE_URL to https://

3. **Database**:
   - Use connection pooling
   - Enable SSL for database connections
   - Regular backups

4. **Monitoring**:
   - Set up logging (Winston for backend)
   - Monitor API response times
   - Track failed authentication attempts

5. **Security**:
   - Never commit .env files
   - Rotate API keys regularly
   - Use environment-specific configurations

---

## 8. Troubleshooting Commands

```bash
# Check backend logs
cd backend
npm run dev  # Watch console output

# Check ML service logs
cd face-recognition-service
python main.py  # Watch console output

# Check database
npx prisma studio  # Opens GUI at http://localhost:5555

# Reset database (CAUTION: Deletes all data)
npx prisma migrate reset

# View Prisma schema
npx prisma format
```

---

## Need Help?

1. Check logs in `backend/logs/` directory
2. Review `BACKEND_FIXES_COMPLETE.md` for detailed fix information
3. Check `MIGRATION_INSTRUCTIONS.md` for database issues
4. Verify all environment variables are set correctly

---

**Last Updated**: January 14, 2026
