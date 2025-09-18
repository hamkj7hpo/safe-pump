use core::convert::TryFrom;

use curve25519_dalek::scalar::Scalar;
use sha2::{Digest, Sha512};

#[cfg(feature = "zeroize")]
use zeroize::Zeroize;

// bring these back so signing.rs compiles
use crate::constants::*;
use crate::errors::*;
use crate::public::*;
use crate::secret::*;
use crate::signature::*;

/// An expanded secret key
#[derive(Clone)]
pub struct ExpandedSecretKey {
    pub(crate) scalar: Scalar,
    pub(crate) hash_prefix: [u8; 32],
}

impl ExpandedSecretKey {
    /// Create from SecretKey
    pub fn from_secret_key(secret_key: &SecretKey) -> ExpandedSecretKey {
        let hash: [u8; 64] = Sha512::digest(secret_key.as_bytes()).into();

        let mut scalar_bytes = [0u8; 32];
        scalar_bytes.copy_from_slice(&hash[..32]);
        scalar_bytes[0] &= 248;
        scalar_bytes[31] &= 63;
        scalar_bytes[31] |= 64;

        // use from_bytes_mod_order instead of from_bits
        let scalar = Scalar::from_bytes_mod_order(scalar_bytes);

        let mut hash_prefix = [0u8; 32];
        hash_prefix.copy_from_slice(&hash[32..]);

        ExpandedSecretKey { scalar, hash_prefix }
    }

    /// Reconstruct from raw bytes (needed by signing.rs)
    pub fn from_bytes(bytes: &[u8; 64]) -> ExpandedSecretKey {
        let mut scalar_bytes = [0u8; 32];
        scalar_bytes.copy_from_slice(&bytes[..32]);
        scalar_bytes[0] &= 248;
        scalar_bytes[31] &= 63;
        scalar_bytes[31] |= 64;

        let scalar = Scalar::from_bytes_mod_order(scalar_bytes);

        let mut hash_prefix = [0u8; 32];
        hash_prefix.copy_from_slice(&bytes[32..]);

        ExpandedSecretKey { scalar, hash_prefix }
    }
}

#[cfg(feature = "zeroize")]
impl Drop for ExpandedSecretKey {
    fn drop(&mut self) {
        self.hash_prefix.zeroize();
        let mut scalar_bytes = self.scalar.to_bytes();
        scalar_bytes.zeroize();
    }
}
