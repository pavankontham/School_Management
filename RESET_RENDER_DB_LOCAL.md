# Reset Render Database Locally

## Your Render Database URL:
postgresql://school_admin:3J8oYBszSLbWSz9pmJ4i0trgjZv95EJW@dpg-d5d07her433s73a74v90-a/school_management_0g1h

## Step 1: Update Local .env with Render Database

Replace your DATABASE_URL in backend/.env with:
DATABASE_URL="postgresql://school_admin:3J8oYBszSLbWSz9pmJ4i0trgjZv95EJW@dpg-d5d07her433s73a74v90-a.oregon-postgres.render.com/school_management_0g1h"

Note: Added ".oregon-postgres.render.com" to the host

## Step 2: Run Migration Locally (Connects to Render DB)

Open terminal in backend folder and run:

```bash
# Navigate to backend
cd backend

# Reset the database (DELETES ALL DATA!)
npx prisma migrate reset --force

# Or if you want to keep data, try:
npx prisma migrate deploy
```

This will connect to your Render database and apply all migrations!

## Step 3: Verify

```bash
npx prisma migrate status
```

## Step 4: Restore Local .env

After migration, change DATABASE_URL back to your local database.
