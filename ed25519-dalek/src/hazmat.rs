//! Low-level “hazmat” operations.
//!
//! These APIs are not intended for typical users of the library and should only
//! be used if you really know what you’re doing.

use core::convert::TryFrom;

use curve25519_dalek::scalar::Scalar;
use sha2::{Digest, Sha512};
use subtle::Choice;

use crate::constants::*;
use crate::errors::*;
use crate::public::*;
use crate::secret::*;
use crate::signature::*;

#[cfg(feature = "zeroize")]
use zeroize::Zeroize;

/// An expanded secret key
#[derive(Clone)]
pub struct ExpandedSecretKey {
    pub(crate) scalar: Scalar,
    pub(crate) hash_prefix: [u8; 32],
}

impl ExpandedSecretKey {
    /// Create an `ExpandedSecretKey` from a `SecretKey`.
    pub fn from_secret_key(secret_key: &SecretKey) -> ExpandedSecretKey {
        let hash: [u8; 64] = Sha512::digest(secret_key.as_bytes()).into();

        let mut scalar_bytes = [0u8; 32];
        scalar_bytes.copy_from_slice(&hash[..32]);
        scalar_bytes[0] &= 248;
        scalar_bytes[31] &= 63;
        scalar_bytes[31] |= 64;

        let scalar = Scalar::from_bits(scalar_bytes);

        let mut hash_prefix = [0u8; 32];
        hash_prefix.copy_from_slice(&hash[32..]);

        ExpandedSecretKey { scalar, hash_prefix }
    }
}

#[cfg(feature = "zeroize")]
impl Drop for ExpandedSecretKey {
    fn drop(&mut self) {
        // zeroize the hash prefix
        self.hash_prefix.zeroize();

        // zeroize the scalar bytes (not the Scalar itself)
        let mut scalar_bytes = self.scalar.to_bytes();
        scalar_bytes.zeroize();
    }
}
