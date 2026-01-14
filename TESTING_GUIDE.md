# Testing Guide - School Management System

## Quick Test Checklist

### 1. Principal Dashboard
- [ ] Login as principal
- [ ] Verify dashboard shows:
  - Total teachers, students, classes
  - Recent posts (if any created)
  - Quick action buttons for all features
- [ ] Click each quick action button to verify navigation

### 2. Teacher Management
- [ ] Navigate to Teachers
- [ ] Click "Add Teacher"
- [ ] Fill in all required fields
- [ ] Select classes (use filter chips)
- [ ] Select subjects (use filter chips)
- [ ] Submit and verify teacher is created
- [ ] Verify teacher appears in list

### 3. Subject Management
- [ ] Navigate to Classes
- [ ] Click on a class
- [ ] Click "Subjects" or navigate to subject management
- [ ] Click "Add Subject"
- [ ] Enter subject name and code
- [ ] Submit and verify subject is created
- [ ] Click on subject menu → "Assign Teacher"
- [ ] Select a teacher from dropdown
- [ ] Verify teacher is assigned
- [ ] Check that teacher name appears under subject

### 4. Attendance (Principal as Teacher)
- [ ] From dashboard, click "Attendance" quick action
- [ ] Verify class dropdown shows classes
- [ ] Select a class (should auto-select if only one)
- [ ] Verify subject dropdown shows subjects for that class
- [ ] Select a subject (should auto-select if only one)
- [ ] Verify students load
- [ ] Mark attendance (Present/Absent/Late)
- [ ] Click "Submit Attendance"
- [ ] Verify success message

### 5. Marks Management
- [ ] Click "Marks" from dashboard
- [ ] Select class and subject
- [ ] Verify students load
- [ ] Enter marks for students
- [ ] Submit and verify

### 6. Quizzes
- [ ] Click "Quizzes" from dashboard
- [ ] Verify quizzes list loads (may be empty)
- [ ] Click "Create Quiz" if available
- [ ] Fill in quiz details
- [ ] Add questions
- [ ] Submit and verify

### 7. Textbooks
- [ ] Click "Textbooks" from dashboard
- [ ] Verify textbooks list loads (may be empty)
- [ ] Click "Upload Textbook" if available
- [ ] Select file and fill details
- [ ] Submit and verify

### 8. Dashboard Posts
- [ ] From dashboard, click "New Post" FAB
- [ ] Select post type (Announcement/Event/etc.)
- [ ] Enter title and content
- [ ] Submit
- [ ] Verify post appears on dashboard
- [ ] Click "View All" to see all posts

### 9. Class Details
- [ ] Navigate to Classes
- [ ] Click on any class card
- [ ] Verify class detail screen shows:
  - Class name and academic year
  - Student count and subject count
  - List of subjects with teachers
  - List of students
- [ ] Click "View All" for subjects
- [ ] Click "View All" for students

### 10. AI Chat
- [ ] Click "AI Chat" from dashboard
- [ ] Type a message
- [ ] Send and verify response
- [ ] Check chat history

## Common Issues to Check

### Dropdowns Not Working
- Verify backend is running
- Check network connectivity
- Verify data exists in database
- Check browser console for errors

### Data Not Updating
- Try pull-to-refresh
- Check if invalidation is working
- Verify backend endpoint is correct
- Check response format

### Teacher Assignment Not Working
- Verify teacher exists
- Check subject exists
- Verify backend endpoint `/subjects/:id/assign-teacher`
- Check network tab for request/response

## Backend Verification

### Check Backend is Running
```bash
# Should see: Server running on port 3000
curl http://localhost:3000/api/v1/health
```

### Test Endpoints
```bash
# Get subjects
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3000/api/v1/subjects

# Assign teacher to subject
curl -X PUT -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" -d '{"teacherId":"TEACHER_ID"}' http://localhost:3000/api/v1/subjects/SUBJECT_ID/assign-teacher
```

## Expected Behavior

### Auto-Selection
- If teacher has only 1 class → auto-selects it
- If class has only 1 subject → auto-selects it
- Improves UX for single-assignment scenarios

### Dynamic Updates
- Creating teacher → updates teacher list
- Creating subject → updates subject list
- Assigning teacher → updates subject display
- All lists refresh automatically

### Error Handling
- Form validation shows errors
- Network errors show retry option
- Empty states show helpful messages
- Loading states show spinners

## Performance Notes

- Dashboard loads in < 2 seconds
- Subject assignment is instant
- Lists support pull-to-refresh
- Cached data for offline viewing

## Security Checks

- [ ] Cannot access without login
- [ ] Principal routes protected
- [ ] School ID validated on all operations
- [ ] Teacher verification before assignment

## Mobile-Specific Tests

- [ ] Responsive layout on phone
- [ ] Touch targets are adequate
- [ ] Scrolling is smooth
- [ ] Keyboard doesn't overlap inputs
- [ ] Back button works correctly
- [ ] App doesn't crash on rotation

## Data Integrity

- [ ] No duplicate subjects
- [ ] No orphaned assignments
- [ ] Cascade deletes work
- [ ] Audit logs created
- [ ] Timestamps are correct

## Report Issues

If you find any issues:
1. Note the exact steps to reproduce
2. Check browser/app console for errors
3. Verify backend logs
4. Take screenshots if UI issue
5. Document expected vs actual behavior
