use sha2::{Digest, Sha512};
use zeroize::Zeroize;

use curve25519_dalek::{
    constants::ED25519_BASEPOINT_TABLE,
    scalar::Scalar,
};
use crate::errors::*;
use crate::signature::{PublicKey, Signature};

/// ExpandedSecretKey is the "hazmat" version of the SecretKey.
/// It exposes the raw scalar (`scalar`) and the prefix (`hash_prefix`).
#[derive(Clone)]
pub struct ExpandedSecretKey {
    pub scalar: Scalar,
    pub hash_prefix: [u8; 32],
}

impl ExpandedSecretKey {
    pub fn from_bytes(bytes: &[u8]) -> Result<ExpandedSecretKey, SignatureError> {
        if bytes.len() != 64 {
            return Err(SignatureError::from(InternalError::BytesLength {
                name: "ExpandedSecretKey",
                length: 64,
            }));
        }

        let mut scalar_bytes = [0u8; 32];
        scalar_bytes.copy_from_slice(&bytes[0..32]);
        scalar_bytes[0] &= 248;
        scalar_bytes[31] &= 63;
        scalar_bytes[31] |= 64;

        let scalar = Scalar::from_bits(scalar_bytes);

        let mut hash_prefix = [0u8; 32];
        hash_prefix.copy_from_slice(&bytes[32..64]);

        Ok(ExpandedSecretKey { scalar, hash_prefix })
    }

    pub fn sign(&self, message: &[u8], public_key: &PublicKey) -> Signature {
        // r = H(hash_prefix || message)
        let mut h = Sha512::new();
        h.update(&self.hash_prefix);
        h.update(message);
        let r = Scalar::from_bytes_mod_order_wide(&h.finalize().into());

        // R = r * B
        let r_encoded = (&r * &ED25519_BASEPOINT_TABLE).compress();

        // k = H(R || A || M)
        let mut h = Sha512::new();
        h.update(r_encoded.as_bytes());
        h.update(public_key.as_bytes());
        h.update(message);
        let k = Scalar::from_bytes_mod_order_wide(&h.finalize().into());

        let s = r + (k * self.scalar);

        Signature { R: r_encoded, s }
    }

    pub fn zeroize(&mut self) {
        let mut scalar_bytes = self.scalar.to_bytes();
        scalar_bytes.zeroize();
        self.scalar = Scalar::from_bytes_mod_order([0u8; 32]);
        self.hash_prefix.zeroize();
    }
}
