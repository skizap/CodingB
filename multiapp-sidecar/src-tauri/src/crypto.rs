// Encryption module for MultiappV1 Sidecar
// Provides AES-GCM encryption with Argon2 key derivation for state persistence

use aes_gcm::{
    aead::{Aead, AeadCore, KeyInit, OsRng},
    Aes256Gcm, Key, Nonce,
};
use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier, password_hash::{rand_core::RngCore, SaltString}};
use base64::{Engine as _, engine::general_purpose};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CryptoError {
    #[error("Encryption failed: {0}")]
    EncryptionFailed(String),
    #[error("Decryption failed: {0}")]
    DecryptionFailed(String),
    #[error("Key derivation failed: {0}")]
    KeyDerivationFailed(String),
    #[error("Invalid passphrase")]
    InvalidPassphrase,
    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),
}

#[derive(Serialize, Deserialize, Clone)]
pub struct EncryptedData {
    pub salt: String,
    pub nonce: String,
    pub ciphertext: String,
}

pub struct CryptoManager {
    passphrase: Option<String>,
    key_cache: HashMap<String, Vec<u8>>, // Cache derived keys by salt
}

impl CryptoManager {
    pub fn new(passphrase: Option<String>) -> Self {
        Self {
            passphrase,
            key_cache: HashMap::new(),
        }
    }

    /// Derive key from passphrase using Argon2
    fn derive_key(&mut self, salt: &str) -> Result<Vec<u8>, CryptoError> {
        if let Some(cached_key) = self.key_cache.get(salt) {
            return Ok(cached_key.clone());
        }

        let passphrase = self.passphrase.as_ref()
            .ok_or(CryptoError::InvalidPassphrase)?;

        let salt_bytes = general_purpose::STANDARD
            .decode(salt)
            .map_err(|e| CryptoError::KeyDerivationFailed(e.to_string()))?;

        let salt_string = SaltString::from_b64(&general_purpose::STANDARD.encode(&salt_bytes))
            .map_err(|e| CryptoError::KeyDerivationFailed(e.to_string()))?;

        let argon2 = Argon2::default();
        let password_hash = argon2
            .hash_password(passphrase.as_bytes(), &salt_string)
            .map_err(|e| CryptoError::KeyDerivationFailed(e.to_string()))?;

        let key = password_hash.hash
            .ok_or_else(|| CryptoError::KeyDerivationFailed("No hash generated".to_string()))?
            .as_bytes()[..32] // Use first 32 bytes for AES-256
            .to_vec();

        self.key_cache.insert(salt.to_string(), key.clone());
        Ok(key)
    }

    /// Encrypt data with AES-GCM
    pub fn encrypt(&mut self, data: &[u8]) -> Result<EncryptedData, CryptoError> {
        if self.passphrase.is_none() {
            return Err(CryptoError::InvalidPassphrase);
        }

        // Generate random salt for key derivation
        let mut salt = [0u8; 16];
        OsRng.fill_bytes(&mut salt);
        let salt_b64 = general_purpose::STANDARD.encode(salt);

        // Derive key
        let key_bytes = self.derive_key(&salt_b64)?;
        let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
        let cipher = Aes256Gcm::new(key);

        // Generate random nonce
        let nonce = Aes256Gcm::generate_nonce(&mut OsRng);
        
        // Encrypt
        let ciphertext = cipher
            .encrypt(&nonce, data)
            .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?;

        Ok(EncryptedData {
            salt: salt_b64,
            nonce: general_purpose::STANDARD.encode(nonce),
            ciphertext: general_purpose::STANDARD.encode(ciphertext),
        })
    }

    /// Decrypt data with AES-GCM
    pub fn decrypt(&mut self, encrypted_data: &EncryptedData) -> Result<Vec<u8>, CryptoError> {
        if self.passphrase.is_none() {
            return Err(CryptoError::InvalidPassphrase);
        }

        // Derive key using stored salt
        let key_bytes = self.derive_key(&encrypted_data.salt)?;
        let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
        let cipher = Aes256Gcm::new(key);

        // Decode nonce and ciphertext
        let nonce_bytes = general_purpose::STANDARD
            .decode(&encrypted_data.nonce)
            .map_err(|e| CryptoError::DecryptionFailed(e.to_string()))?;
        let nonce = Nonce::from_slice(&nonce_bytes);

        let ciphertext = general_purpose::STANDARD
            .decode(&encrypted_data.ciphertext)
            .map_err(|e| CryptoError::DecryptionFailed(e.to_string()))?;

        // Decrypt
        let plaintext = cipher
            .decrypt(nonce, ciphertext.as_ref())
            .map_err(|e| CryptoError::DecryptionFailed(e.to_string()))?;

        Ok(plaintext)
    }

    /// Encrypt JSON serializable data
    pub fn encrypt_json<T: Serialize>(&mut self, data: &T) -> Result<EncryptedData, CryptoError> {
        let json_bytes = serde_json::to_vec(data)?;
        self.encrypt(&json_bytes)
    }

    /// Decrypt to JSON deserializable data
    pub fn decrypt_json<T: for<'de> Deserialize<'de>>(&mut self, encrypted_data: &EncryptedData) -> Result<T, CryptoError> {
        let json_bytes = self.decrypt(encrypted_data)?;
        let data = serde_json::from_slice(&json_bytes)?;
        Ok(data)
    }

    /// Check if encryption is available
    pub fn is_encryption_enabled(&self) -> bool {
        self.passphrase.is_some()
    }
}

impl Default for CryptoManager {
    fn default() -> Self {
        // Try to get passphrase from environment
        let passphrase = std::env::var("MULTIAPP_PASSPHRASE").ok();
        Self::new(passphrase)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encrypt_decrypt_cycle() {
        let mut crypto = CryptoManager::new(Some("test_passphrase".to_string()));
        let original_data = b"Hello, encrypted world!";
        
        let encrypted = crypto.encrypt(original_data).unwrap();
        let decrypted = crypto.decrypt(&encrypted).unwrap();
        
        assert_eq!(original_data, &decrypted[..]);
    }

    #[test]
    fn test_encrypt_decrypt_json() {
        use serde_json::json;
        
        let mut crypto = CryptoManager::new(Some("test_passphrase".to_string()));
        let original_data = json!({
            "operation": "write_file",
            "path": "/tmp/test.txt",
            "content": "Hello World"
        });
        
        let encrypted = crypto.encrypt_json(&original_data).unwrap();
        let decrypted: serde_json::Value = crypto.decrypt_json(&encrypted).unwrap();
        
        assert_eq!(original_data, decrypted);
    }
}
