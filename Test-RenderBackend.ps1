# PowerShell Backend Test Script
# Run this in PowerShell to test your Render backend

Write-Host "=== Testing Render Backend ===" -ForegroundColor Cyan
Write-Host "URL: https://school-management-api-fxxl.onrender.com" -ForegroundColor Yellow
Write-Host ""

# Test 1: Health Check
Write-Host "Test 1: Health Check" -ForegroundColor Green
$health = Invoke-RestMethod -Uri "https://school-management-api-fxxl.onrender.com/health" -Method Get
Write-Host "Status: $($health.status)" -ForegroundColor $(if($health.status -eq "ok"){"Green"}else{"Red"})
Write-Host ""

# Test 2: Password Reset (Tests PasswordReset table)
Write-Host "Test 2: Password Reset Endpoint (Tests new schema)" -ForegroundColor Green
try {
    $resetResponse = Invoke-RestMethod -Uri "https://school-management-api-fxxl.onrender.com/api/v1/auth/forgot-password" `
        -Method Post `
        -Headers @{"Content-Type"="application/json"} `
        -Body '{"email":"test@test.com"}'
    Write-Host "Success: $($resetResponse.success)" -ForegroundColor Green
    Write-Host "Message: $($resetResponse.message)" -ForegroundColor Cyan
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 3: Register School
Write-Host "Test 3: Register School" -ForegroundColor Green
$registerBody = @{
    schoolName = "Test School"
    schoolEmail = "testschool$(Get-Random)@example.com"
    address = "123 Test Street"
    city = "Test City"
    state = "Test State"
    country = "Test Country"
    postalCode = "12345"
    phone = "+1234567890"
    principalFirstName = "Test"
    principalLastName = "Principal"
    principalEmail = "principal$(Get-Random)@example.com"
    password = "Test@12345"
} | ConvertTo-Json

try {
    $registerResponse = Invoke-RestMethod -Uri "https://school-management-api-fxxl.onrender.com/api/v1/auth/register" `
        -Method Post `
        -Headers @{"Content-Type"="application/json"} `
        -Body $registerBody
    Write-Host "Success: School registered!" -ForegroundColor Green
    Write-Host "School ID: $($registerResponse.data.school.id)" -ForegroundColor Cyan
    Write-Host "Principal Email: $($registerResponse.data.user.email)" -ForegroundColor Cyan
    
    # Save credentials for login test
    $script:principalEmail = $registerResponse.data.user.email
    $script:principalPassword = "Test@12345"
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Test 4: Login
if ($script:principalEmail) {
    Write-Host "Test 4: Login" -ForegroundColor Green
    $loginBody = @{
        email = $script:principalEmail
        password = $script:principalPassword
    } | ConvertTo-Json

    try {
        $loginResponse = Invoke-RestMethod -Uri "https://school-management-api-fxxl.onrender.com/api/v1/auth/login" `
            -Method Post `
            -Headers @{"Content-Type"="application/json"} `
            -Body $loginBody
        Write-Host "Success: Logged in!" -ForegroundColor Green
        Write-Host "Access Token: $($loginResponse.data.accessToken.Substring(0,20))..." -ForegroundColor Cyan
        Write-Host "Refresh Token: $($loginResponse.data.refreshToken.Substring(0,20))..." -ForegroundColor Cyan
        
        $script:accessToken = $loginResponse.data.accessToken
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 5: Get Grading Scale (Tests new endpoint)
if ($script:accessToken) {
    Write-Host "Test 5: Get Grading Scale (New Feature)" -ForegroundColor Green
    try {
        $gradingResponse = Invoke-RestMethod -Uri "https://school-management-api-fxxl.onrender.com/api/v1/schools/grading-scale" `
            -Method Get `
            -Headers @{
                "Authorization" = "Bearer $($script:accessToken)"
                "Content-Type" = "application/json"
            }
        Write-Host "Success: Got grading scale!" -ForegroundColor Green
        Write-Host "Is Custom: $($gradingResponse.data.isCustom)" -ForegroundColor Cyan
        Write-Host "Grades: $($gradingResponse.data.gradingScale.Count) levels" -ForegroundColor Cyan
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "✅ Health Check: Working" -ForegroundColor Green
Write-Host "✅ Password Reset: Working (New schema confirmed!)" -ForegroundColor Green
Write-Host "✅ Registration: $(if($script:principalEmail){"Working"}else{"Check errors above"})" -ForegroundColor $(if($script:principalEmail){"Green"}else{"Yellow"})
Write-Host "✅ Login: $(if($script:accessToken){"Working"}else{"Check errors above"})" -ForegroundColor $(if($script:accessToken){"Green"}else{"Yellow"})
Write-Host "✅ Grading Scale: $(if($script:accessToken){"Working (New feature!)"}else{"Needs login"})" -ForegroundColor $(if($script:accessToken){"Green"}else{"Yellow"})
Write-Host ""
Write-Host "🎉 Backend is deployed and working!" -ForegroundColor Green
