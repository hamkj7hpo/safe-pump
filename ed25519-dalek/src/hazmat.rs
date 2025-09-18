use core::convert::TryFrom;

use crate::constants::*;
use crate::errors::*;
use crate::signature::*;
use crate::verify::verify;
use zeroize::Zeroize;

use curve25519_dalek::scalar::Scalar;
use sha2::{Digest, Sha512};

/// ExpandedSecretKey is the "hazmat" version of the SecretKey.
/// It exposes the raw scalar (`key`) and the prefix (`nonce`).
#[derive(Clone)]
pub struct ExpandedSecretKey {
    pub key: Scalar,
    pub nonce: [u8; 32],
}

impl ExpandedSecretKey {
    /// Create an `ExpandedSecretKey` from a 64-byte slice (output of Sha512 on a secret key).
    pub fn from_bytes(bytes: &[u8]) -> Result<ExpandedSecretKey, SignatureError> {
        if bytes.len() != 64 {
            return Err(SignatureError::from(InternalError::BytesLengthError {
                name: "ExpandedSecretKey",
                length: 64,
            }));
        }

        // first 32 bytes = key, clamped
        let mut key_bytes = [0u8; 32];
        key_bytes.copy_from_slice(&bytes[0..32]);
        key_bytes[0] &= 248;
        key_bytes[31] &= 63;
        key_bytes[31] |= 64;

        let key = Scalar::from_bytes_mod_order(key_bytes);

        // second 32 bytes = nonce
        let mut nonce = [0u8; 32];
        nonce.copy_from_slice(&bytes[32..64]);

        Ok(ExpandedSecretKey { key, nonce })
    }

    /// Sign a message with the expanded secret key and a public key.
    pub fn sign(&self, message: &[u8], public_key: &crate::PublicKey) -> Signature {
        // r = H(nonce || message)
        let mut h = Sha512::new();
        h.update(&self.nonce);
        h.update(message);
        let r = Scalar::from_bytes_mod_order_wide(&h.finalize());

        // R = r * B
        let r_encoded = (&r * &crate::constants::ED25519_BASEPOINT_TABLE).compress();

        // k = H(R || A || M)
        let mut h = Sha512::new();
        h.update(r_encoded.as_bytes());
        h.update(public_key.as_bytes());
        h.update(message);
        let k = Scalar::from_bytes_mod_order_wide(&h.finalize());

        // s = r + k*key
        let s = r + (k * self.key);

        Signature {
            R: r_encoded,
            s: s.reduce(),
        }
    }

    /// Zeroize the secret material.
    pub fn zeroize(&mut self) {
        // wipe key material
        let mut key_bytes = self.key.to_bytes();
        key_bytes.zeroize();
        self.key = Scalar::from_bytes_mod_order([0u8; 32]);

        // wipe nonce
        self.nonce.zeroize();
    }
}
