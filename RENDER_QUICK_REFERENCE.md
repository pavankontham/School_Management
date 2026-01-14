# 🚀 QUICK DEPLOYMENT REFERENCE

## Your Render Backend
**URL**: https://school-management-api-fxxl.onrender.com
**Dashboard**: https://dashboard.render.com

---

## ⚡ FASTEST WAY TO RESET DATABASE

### 1. Go to Render Shell:
- Open: https://dashboard.render.com
- Select: **school-management-api-fxxl**
- Click: **"Shell"** tab

### 2. Run This Command:
```bash
npx prisma migrate reset --force
```

**What it does**:
- ✅ Drops all tables
- ✅ Deletes all data
- ✅ Applies all new migrations
- ✅ Creates new schema with all fixes

**Time**: ~30 seconds
**Result**: Fresh database with new schema

---

## 🔧 REQUIRED ENVIRONMENT VARIABLES

Add these in Render Dashboard → Environment:

```bash
# Email Service (Brevo)
BREVO_SMTP_USER=your-brevo-email@example.com
BREVO_SMTP_KEY=your-brevo-api-key
SCHOOL_EMAIL=noreply@schoolmanagement.com
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_SECURE=false

# Frontend
FRONTEND_URL=https://your-frontend-url.com

# Face Recognition (if using)
ML_SERVICE_URL=http://localhost:5000
ML_SERVICE_API_KEY=your-secure-api-key

# JWT
JWT_REFRESH_EXPIRES_IN=7d
```

---

## 📊 NEW DATABASE TABLES

After reset, you'll have:
- ✅ StudentRefreshToken (for student sessions)
- ✅ PasswordReset (for password reset)
- ✅ School.gradingScale (configurable grading)
- ✅ DashboardPost.eventDate (event scheduling)
- ✅ ClassSubject.teacherId (per-class teachers)

---

## ✅ VERIFICATION STEPS

After reset, test:

1. **Health Check**:
   ```
   GET https://school-management-api-fxxl.onrender.com/health
   ```

2. **Register School**:
   ```
   POST https://school-management-api-fxxl.onrender.com/api/v1/auth/register
   ```

3. **Login**:
   ```
   POST https://school-management-api-fxxl.onrender.com/api/v1/auth/login
   ```

---

## 🆘 IF SOMETHING GOES WRONG

### Migration Failed?
```bash
npx prisma migrate status
npx prisma migrate resolve --applied "migration_name"
```

### Schema Drift?
```bash
npx prisma db push --accept-data-loss
```

### Complete Restart?
```bash
npx prisma migrate reset --force
```

---

## 📞 QUICK COMMANDS

```bash
# Check status
npx prisma migrate status

# Apply migrations
npx prisma migrate deploy

# Reset everything
npx prisma migrate reset --force

# Generate client
npx prisma generate
```

---

**Next Steps**:
1. ✅ Code pushed to GitHub - DONE
2. ⏳ Reset database on Render
3. ⏳ Add environment variables
4. ⏳ Test endpoints
5. ⏳ Create initial school/admin

---

**Support**: Check `DATABASE_RESET_GUIDE.md` for detailed instructions
