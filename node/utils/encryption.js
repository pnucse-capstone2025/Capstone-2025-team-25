// server/utils/encryption.js
const crypto = require('crypto-js');

const ENCRYPTION_KEY = process.env.MESSAGE_ENCRYPTION_KEY || '4f9a32c6715cbd8e9ac4dbe3e0d8275e77c3e681dff6ac2cf8b69e42d45798cb';

function encrypt(text) {
    return crypto.AES.encrypt(text, ENCRYPTION_KEY).toString();
}

function decrypt(ciphertext) {
    const bytes = crypto.AES.decrypt(ciphertext, ENCRYPTION_KEY);
    return bytes.toString(crypto.enc.Utf8);
}

module.exports = { encrypt, decrypt };
