# Database Reset Commands for Render

## ⚠️ WARNING: These commands will DELETE ALL DATA!

## Option 1: Complete Database Reset (Deletes Everything)

### Step 1: Connect to Render Shell
1. Go to https://dashboard.render.com
2. Select your backend service: school-management-api-fxxl
3. Click on "Shell" tab

### Step 2: Reset Database
Run these commands in order:

```bash
# Reset the database (deletes all data and migrations)
npx prisma migrate reset --force

# This will:
# - Drop all tables
# - Delete migration history
# - Re-run all migrations
# - Seed database (if you have seed data)
```

---

## Option 2: Fresh Migration (Recommended - Safer)

If you just want to apply new schema changes without losing data:

```bash
# Generate Prisma client
npx prisma generate

# Apply pending migrations
npx prisma migrate deploy

# If migration fails, you can force it:
npx prisma migrate resolve --applied "migration_name"
```

---

## Option 3: Manual Database Reset via Render Dashboard

### Step 1: Delete Current Database
1. Go to Render Dashboard
2. Find your PostgreSQL database
3. Click "Delete Database" (or create a new one)

### Step 2: Create New Database
1. Create a new PostgreSQL database
2. Copy the new DATABASE_URL

### Step 3: Update Backend Service
1. Go to your backend service environment variables
2. Update DATABASE_URL with new database URL
3. Redeploy the service

### Step 4: Run Initial Migration
In the Shell:
```bash
npx prisma migrate deploy
npx prisma generate
```

---

## Option 4: Push Schema (Development Only)

For quick schema updates without migration history:

```bash
# Push schema changes directly
npx prisma db push

# Warning: This can cause data loss!
```

---

## 🎯 Recommended Approach for Your Situation

Since you have new schema changes (StudentRefreshToken, PasswordReset, etc.), use this:

### Step 1: Backup Current Data (Optional)
```bash
# Export current data
npx prisma db pull
```

### Step 2: Apply New Migrations
```bash
# Generate Prisma client with new schema
npx prisma generate

# Deploy migrations
npx prisma migrate deploy
```

### Step 3: Verify
```bash
# Check database status
npx prisma migrate status
```

---

## 🚨 If You Get Migration Errors

### Error: "Migration failed"
```bash
# Mark migration as applied (if it partially succeeded)
npx prisma migrate resolve --applied "migration_name"

# Or rollback
npx prisma migrate resolve --rolled-back "migration_name"
```

### Error: "Schema drift detected"
```bash
# Reset and start fresh
npx prisma migrate reset --force
```

---

## ✅ After Reset/Migration

### Verify Everything Works:
```bash
# Check Prisma status
npx prisma migrate status

# Test database connection
npx prisma db pull
```

### Create Initial Data:
You'll need to re-create:
- Schools
- Admin users
- Classes
- Subjects
- Students

---

## 📝 Quick Commands Reference

```bash
# See migration status
npx prisma migrate status

# Apply migrations
npx prisma migrate deploy

# Reset everything (DELETES DATA!)
npx prisma migrate reset --force

# Push schema without migrations
npx prisma db push

# Generate Prisma client
npx prisma generate

# Open Prisma Studio (if available)
npx prisma studio
```

---

## 🔗 Your Render Backend

**URL**: https://school-management-api-fxxl.onrender.com

**To access Shell**:
1. Go to: https://dashboard.render.com
2. Find: school-management-api-fxxl
3. Click: "Shell" tab
4. Run commands above

---

## ⚡ Fastest Way to Reset (Recommended)

```bash
# In Render Shell, run:
npx prisma migrate reset --force && npx prisma generate

# This will:
# ✅ Drop all tables
# ✅ Delete old migrations
# ✅ Apply all new migrations
# ✅ Generate Prisma client
# ✅ Create all new tables
```

**Time**: ~30 seconds
**Data Loss**: YES (all data deleted)
**Best for**: Fresh start with new schema

---

## 🎯 What You Should Do Now

1. **Decide**: Do you want to keep existing data?
   - **YES** → Use Option 2 (Fresh Migration)
   - **NO** → Use Option 1 (Complete Reset)

2. **Go to Render Shell**:
   - https://dashboard.render.com
   - Select: school-management-api-fxxl
   - Click: "Shell"

3. **Run Command**:
   ```bash
   # If you want fresh start (deletes data):
   npx prisma migrate reset --force
   
   # If you want to keep data (might fail if schema conflicts):
   npx prisma migrate deploy
   ```

4. **Verify**:
   ```bash
   npx prisma migrate status
   ```

---

**Recommendation**: Since you have major schema changes, I recommend **Option 1 (Complete Reset)** for a clean start.
