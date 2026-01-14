# Quick Backend Test Script

## Test 1: Health Check ✅
curl https://school-management-api-fxxl.onrender.com/health

## Test 2: Register School (Tests if schema is updated)
curl -X POST https://school-management-api-fxxl.onrender.com/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "schoolName": "Test School",
    "schoolEmail": "testschool@example.com",
    "address": "123 Test Street",
    "city": "Test City",
    "state": "Test State",
    "country": "Test Country",
    "postalCode": "12345",
    "phone": "+1234567890",
    "principalFirstName": "Test",
    "principalLastName": "Principal",
    "principalEmail": "testprincipal@example.com",
    "password": "Test@12345"
  }'

## Test 3: Login
curl -X POST https://school-management-api-fxxl.onrender.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testprincipal@example.com",
    "password": "Test@12345"
  }'

## Test 4: Password Reset (Tests new PasswordReset table)
curl -X POST https://school-management-api-fxxl.onrender.com/api/v1/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testprincipal@example.com"
  }'

## Expected Results:
- Test 1: {"status":"ok","timestamp":"..."}
- Test 2: 201 Created with school data (if schema updated) OR error (if not)
- Test 3: 200 OK with tokens
- Test 4: 200 OK with success message (if PasswordReset table exists)

## If Test 2 or 4 Fails:
Schema is not updated. Need to run migration.

## To Run Migration on Render:
1. Update Build Command in Render:
   Settings → Build Command:
   npm install && npx prisma generate && npx prisma migrate deploy

2. Manual Deploy:
   Dashboard → Manual Deploy → Deploy latest commit
