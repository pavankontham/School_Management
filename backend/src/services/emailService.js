const nodemailer = require('nodemailer');

// Brevo SMTP configuration
// IMPORTANT: Set BREVO_SMTP_USER and BREVO_SMTP_KEY in your .env file
const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp-relay.brevo.com',
    port: parseInt(process.env.SMTP_PORT) || 587,
    secure: process.env.SMTP_SECURE === 'true', // Use TLS
    auth: {
        user: process.env.BREVO_SMTP_USER,
        pass: process.env.BREVO_SMTP_KEY
    }
});

/**
 * Send email using Brevo SMTP
 * @param {string} to - Recipient email address
 * @param {string} subject - Email subject
 * @param {string} text - Plain text content
 * @param {string} html - HTML content (optional)
 * @param {string} from - Sender email (optional, defaults to school email)
 * @param {string} schoolId - School ID to fetch school email (optional)
 */
async function sendEmail({ to, subject, text, html, from, schoolId }) {
    try {
        let senderEmail = from;

        // If schoolId provided and no explicit 'from', fetch school email
        if (!senderEmail && schoolId) {
            try {
                const { PrismaClient } = require('@prisma/client');
                const prisma = new PrismaClient();

                const school = await prisma.school.findUnique({
                    where: { id: schoolId },
                    select: { email: true, name: true }
                });

                if (school) {
                    senderEmail = school.email;
                    // You can also use school name in the sender
                    // senderEmail = `"${school.name}" <${school.email}>`;
                }

                await prisma.$disconnect();
            } catch (error) {
                console.error('Error fetching school email:', error);
            }
        }

        // Fallback to environment variable or default
        if (!senderEmail) {
            senderEmail = process.env.SCHOOL_EMAIL || process.env.BREVO_SMTP_USER || 'noreply@schoolmanagement.com';
        }

        const mailOptions = {
            from: senderEmail,
            to,
            subject,
            text,
            html: html || text
        };

        const info = await transporter.sendMail(mailOptions);
        console.log('Email sent successfully:', info.messageId);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error('Error sending email:', error);
        return { success: false, error: error.message };
    }
}

/**
 * Send attendance notification email to parent
 * @param {string} parentEmail - Parent's email
 * @param {string} studentName - Student's name
 * @param {string} date - Attendance date
 * @param {string} status - Attendance status
 * @param {string} teacherName - Teacher's name
 * @param {string} teacherEmail - Teacher's email (for contact)
 * @param {string} schoolId - School ID for dynamic sender email (optional)
 */
async function sendAttendanceEmail({ parentEmail, studentName, date, status, teacherName, teacherEmail, schoolId }) {
    const subject = `Attendance Update - ${studentName}`;

    const text = `Dear Parent,

This is to inform you that the attendance for ${studentName} on ${date} has been marked as ${status}.

Teacher: ${teacherName}
Date: ${date}
Status: ${status}

If you have any questions, please contact ${teacherName} at ${teacherEmail}.

Best regards,
School Management System`;

    const html = `
<!DOCTYPE html>
<html>
<head>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f9f9f9;
        }
        .header {
            background-color: #4CAF50;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px 5px 0 0;
        }
        .content {
            background-color: white;
            padding: 20px;
            border-radius: 0 0 5px 5px;
        }
        .status {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 3px;
            font-weight: bold;
            margin: 10px 0;
        }
        .status.present {
            background-color: #4CAF50;
            color: white;
        }
        .status.absent {
            background-color: #f44336;
            color: white;
        }
        .status.late {
            background-color: #ff9800;
            color: white;
        }
        .info-row {
            padding: 10px 0;
            border-bottom: 1px solid #eee;
        }
        .footer {
            margin-top: 20px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            font-size: 12px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>Attendance Notification</h2>
        </div>
        <div class="content">
            <p>Dear Parent,</p>
            
            <p>This is to inform you that the attendance for <strong>${studentName}</strong> has been recorded.</p>
            
            <p><strong>Date:</strong> ${date}</p>
            <p><strong>Status:</strong> <span class="status ${status.toLowerCase()}">${status}</span></p>
            <p><strong>Teacher:</strong> ${teacherName}</p>
            
            <p style="margin-top: 20px;">If you have any questions, please contact ${teacherName} at <a href="mailto:${teacherEmail}">${teacherEmail}</a>.</p>
            
            <div class="footer">
                <p>This is an automated message from the School Management System.</p>
            </div>
        </div>
    </div>
</body>
</html>`;

    return sendEmail({
        to: parentEmail,
        subject,
        text,
        html,
        schoolId // Use school's email as sender instead of teacher's
    });
}

/**
 * Send password reset email
 * @param {string} email - Recipient email
 * @param {string} resetToken - Reset token
 * @param {string} resetUrl - Reset URL
 * @param {string} schoolId - School ID for dynamic sender email (optional)
 */
async function sendPasswordResetEmail({ email, resetToken, resetUrl, schoolId }) {
    const subject = 'Password Reset Request';

    const text = `You have requested to reset your password.

Click the link below to reset your password:
${resetUrl}

This link will expire in 1 hour.

If you did not request this, please ignore this email.

Best regards,
School Management System`;

    const html = `
<!DOCTYPE html>
<html>
<head>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .button {
            display: inline-block;
            padding: 12px 30px;
            background-color: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Password Reset Request</h2>
        <p>You have requested to reset your password.</p>
        <p>Click the button below to reset your password:</p>
        <a href="${resetUrl}" class="button">Reset Password</a>
        <p>Or copy and paste this link into your browser:</p>
        <p>${resetUrl}</p>
        <p><strong>This link will expire in 1 hour.</strong></p>
        <p>If you did not request this, please ignore this email.</p>
    </div>
</body>
</html>`;

    return sendEmail({
        to: email,
        subject,
        text,
        html,
        schoolId // Pass schoolId to use school's email as sender
    });
}

module.exports = {
    sendEmail,
    sendAttendanceEmail,
    sendPasswordResetEmail
};
