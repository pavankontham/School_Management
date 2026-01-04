const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const SALT_LENGTH = 64;
const TAG_LENGTH = 16;
const KEY_LENGTH = 32;
const ITERATIONS = 100000;

/**
 * Encrypt sensitive data
 * @param {string} text - Text to encrypt
 * @returns {string} - Encrypted text in format: salt:iv:tag:encrypted
 */
function encrypt(text) {
  const key = process.env.ENCRYPTION_KEY;
  if (!key || key.length < 32) {
    throw new Error('ENCRYPTION_KEY must be at least 32 characters');
  }

  const salt = crypto.randomBytes(SALT_LENGTH);
  const iv = crypto.randomBytes(IV_LENGTH);
  
  const derivedKey = crypto.pbkdf2Sync(key, salt, ITERATIONS, KEY_LENGTH, 'sha512');
  
  const cipher = crypto.createCipheriv(ALGORITHM, derivedKey, iv);
  
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  const tag = cipher.getAuthTag();
  
  return `${salt.toString('hex')}:${iv.toString('hex')}:${tag.toString('hex')}:${encrypted}`;
}

/**
 * Decrypt sensitive data
 * @param {string} encryptedText - Encrypted text in format: salt:iv:tag:encrypted
 * @returns {string} - Decrypted text
 */
function decrypt(encryptedText) {
  const key = process.env.ENCRYPTION_KEY;
  if (!key || key.length < 32) {
    throw new Error('ENCRYPTION_KEY must be at least 32 characters');
  }

  const parts = encryptedText.split(':');
  if (parts.length !== 4) {
    throw new Error('Invalid encrypted text format');
  }

  const salt = Buffer.from(parts[0], 'hex');
  const iv = Buffer.from(parts[1], 'hex');
  const tag = Buffer.from(parts[2], 'hex');
  const encrypted = parts[3];
  
  const derivedKey = crypto.pbkdf2Sync(key, salt, ITERATIONS, KEY_LENGTH, 'sha512');
  
  const decipher = crypto.createDecipheriv(ALGORITHM, derivedKey, iv);
  decipher.setAuthTag(tag);
  
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}

/**
 * Hash a value (one-way)
 * @param {string} value - Value to hash
 * @returns {string} - Hashed value
 */
function hash(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

/**
 * Generate a secure random token
 * @param {number} length - Token length in bytes
 * @returns {string} - Random token in hex
 */
function generateToken(length = 32) {
  return crypto.randomBytes(length).toString('hex');
}

module.exports = {
  encrypt,
  decrypt,
  hash,
  generateToken
};

