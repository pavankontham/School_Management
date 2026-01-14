# Backend Migration Instructions

## Database Schema Updates Required

The following changes have been made to the Prisma schema and need to be applied to the database:

### 1. New Tables to Create:

#### StudentRefreshToken
```sql
CREATE TABLE "StudentRefreshToken" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "studentId" TEXT NOT NULL,
  "token" TEXT NOT NULL UNIQUE,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "StudentRefreshToken_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "StudentRefreshToken_studentId_idx" ON "StudentRefreshToken"("studentId");
CREATE INDEX "StudentRefreshToken_token_idx" ON "StudentRefreshToken"("token");
```

#### PasswordReset
```sql
CREATE TABLE "PasswordReset" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "email" TEXT NOT NULL,
  "token" TEXT NOT NULL UNIQUE,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "used" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "PasswordReset_email_idx" ON "PasswordReset"("email");
CREATE INDEX "PasswordReset_token_idx" ON "PasswordReset"("token");
CREATE INDEX "PasswordReset_expiresAt_idx" ON "PasswordReset"("expiresAt");
```

### 2. Existing Tables to Modify:

#### DashboardPost - Add eventDate column
```sql
ALTER TABLE "DashboardPost" ADD COLUMN "eventDate" TIMESTAMP(3);
CREATE INDEX "DashboardPost_eventDate_idx" ON "DashboardPost"("eventDate");
```

## Migration Options

### Option 1: Automatic Migration (Recommended for Development)
If you have database access and Prisma can connect:
```bash
cd backend
npx prisma migrate dev --name add_student_refresh_tokens_password_reset_and_event_dates
```

### Option 2: Manual Migration (For Production or Limited Access)
If automatic migration fails, apply the SQL manually:

1. Connect to your PostgreSQL database
2. Run the SQL commands above in order
3. Then run:
```bash
npx prisma generate
```

### Option 3: Push Schema (Quick Development)
For development environments only:
```bash
npx prisma db push
```
**Warning**: This skips migration history and can cause data loss

## Verification

After migration, verify the changes:
```bash
npx prisma studio
```

Check that these tables exist:
- StudentRefreshToken
- PasswordReset
- DashboardPost (with eventDate column)

## Rollback (If Needed)

If you need to rollback these changes:
```sql
DROP TABLE IF EXISTS "StudentRefreshToken" CASCADE;
DROP TABLE IF EXISTS "PasswordReset" CASCADE;
ALTER TABLE "DashboardPost" DROP COLUMN IF EXISTS "eventDate";
DROP INDEX IF EXISTS "DashboardPost_eventDate_idx";
```

## Environment Setup

Before running the backend, ensure your `.env` file has:
```bash
# Database
DATABASE_URL="postgresql://user:password@host:port/database"

# Email (Brevo/Sendinblue)
BREVO_SMTP_USER=your-email@example.com
BREVO_SMTP_KEY=your-api-key
SCHOOL_EMAIL=noreply@schoolmanagement.com

# Frontend
FRONTEND_URL=http://localhost:3000

# JWT
JWT_REFRESH_EXPIRES_IN=7d
```

## Testing After Migration

1. **Test Student Login/Logout**:
   - Login as student
   - Verify refresh token is saved in StudentRefreshToken table
   - Logout and verify token is deleted

2. **Test Password Reset**:
   - Request password reset
   - Check PasswordReset table for token
   - Complete reset process
   - Verify token is marked as used

3. **Test Event Posts**:
   - Create an EVENT type post with eventDate
   - Verify it appears in upcoming events
   - Check that past events don't show

## Notes

- The Prisma client has been regenerated successfully
- All code changes are complete and ready to use
- Migration is the only remaining step before testing
- No data loss expected - all changes are additive
