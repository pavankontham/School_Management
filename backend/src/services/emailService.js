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
 */
async function sendEmail({ to, subject, text, html, from }) {
    try {
        const mailOptions = {
            from: from || process.env.SCHOOL_EMAIL || 'noreply@schoolmanagement.com',
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
 */
async function sendAttendanceEmail({ parentEmail, studentName, date, status, teacherName, teacherEmail }) {
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
            border-top: 1px solid #eee;
            font-size: 12px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>Attendance Update</h2>
        </div>
        <div class="content">
            <p>Dear Parent,</p>
            <p>This is to inform you that the attendance for <strong>${studentName}</strong> has been updated.</p>
            
            <div class="info-row">
                <strong>Date:</strong> ${date}
            </div>
            <div class="info-row">
                <strong>Status:</strong> <span class="status ${status.toLowerCase()}">${status}</span>
            </div>
            <div class="info-row">
                <strong>Teacher:</strong> ${teacherName}
            </div>
            
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
        from: teacherEmail
    });
}

/**
 * Send password reset email
 */
async function sendPasswordResetEmail({ email, resetToken, resetUrl }) {
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

    return sendEmail({ to: email, subject, text, html });
}

module.exports = {
    sendEmail,
    sendAttendanceEmail,
    sendPasswordResetEmail
};
