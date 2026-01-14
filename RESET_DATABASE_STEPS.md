# Step-by-Step: Reset Render Database from Local Machine

## ⚠️ IMPORTANT: Get External Database URL First!

Your internal URL won't work from outside Render. You need the EXTERNAL URL.

### Get External URL from Render:
1. Go to: https://dashboard.render.com
2. Click on your PostgreSQL database
3. Look for "External Database URL" or "PSQL Command"
4. Copy the full connection string

It should look like:
```
postgresql://school_admin:3J8oYBszSLbWSz9pmJ4i0trgjZv95EJW@dpg-d5d07her433s73a74v90-a.oregon-postgres.render.com/school_management_0g1h
```

Note the `.oregon-postgres.render.com` part!

---

## Step 1: Backup Current .env DATABASE_URL

Open `backend/.env` and copy your current DATABASE_URL somewhere safe.

---

## Step 2: Update .env with Render Database

Replace DATABASE_URL in `backend/.env` with the EXTERNAL URL from Render dashboard.

Example:
```
DATABASE_URL="postgresql://school_admin:3J8oYBszSLbWSz9pmJ4i0trgjZv95EJW@dpg-d5d07her433s73a74v90-a.oregon-postgres.render.com/school_management_0g1h"
```

---

## Step 3: Run Migration Commands

Open terminal in the project root and run:

```bash
cd backend

# Option A: Reset database (DELETES ALL DATA - Fresh Start)
npx prisma migrate reset --force

# Option B: Deploy migrations (Try to keep data)
npx prisma migrate deploy

# Option C: Push schema directly (Quick but risky)
npx prisma db push --accept-data-loss
```

**Recommended**: Use Option A (reset) for a clean start with new schema.

---

## Step 4: Verify Migration

```bash
npx prisma migrate status
```

Should show: "Database schema is up to date!"

---

## Step 5: Restore Local Database URL

Change DATABASE_URL in `backend/.env` back to your local database.

---

## Step 6: Test Render Backend

Visit: https://school-management-api-fxxl.onrender.com/health

Should return:
```json
{
  "status": "ok",
  "timestamp": "..."
}
```

---

## 🆘 Troubleshooting

### Error: "Can't reach database server"
- Check if you used the EXTERNAL URL (with .oregon-postgres.render.com)
- Verify the URL is correct in Render dashboard

### Error: "Migration failed"
- Try: `npx prisma db push --accept-data-loss`
- This forces the schema update

### Error: "Schema drift detected"
- Use: `npx prisma migrate reset --force`
- This will delete all data and start fresh

---

## ✅ What Will Happen

After migration, your Render database will have:
- ✅ StudentRefreshToken table (new)
- ✅ PasswordReset table (new)
- ✅ School.gradingScale field (new)
- ✅ DashboardPost.eventDate field (new)
- ✅ ClassSubject.teacherId field (new)
- ✅ All other existing tables updated

---

## 🎯 Quick Commands Summary

```bash
# Navigate to backend
cd backend

# Reset database (recommended)
npx prisma migrate reset --force

# Or deploy migrations
npx prisma migrate deploy

# Or push schema
npx prisma db push

# Check status
npx prisma migrate status

# Generate Prisma client
npx prisma generate
```

---

**Next**: After migration succeeds, your Render backend will be ready with the new schema!
