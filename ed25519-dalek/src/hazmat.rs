use core::convert::TryFrom;

use crate::constants::*;
use crate::errors::*;
// use crate::public::*;   // removed (no longer exists in v3)
// use crate::secret::*;   // removed (no longer exists in v3)
use crate::signature::*;

use curve25519_dalek::edwards::EdwardsPoint;
use curve25519_dalek::scalar::Scalar;

use zeroize::Zeroize;

/// The “expanded” secret key.
///
/// Internally, this is two 32-byte values:
/// - The scalar used for signing
/// - The “prefix” used during nonce generation
#[derive(Clone)]
pub struct ExpandedSecretKey {
    pub key: Scalar,
    pub nonce: [u8; 32],
}

impl Zeroize for ExpandedSecretKey {
    fn zeroize(&mut self) {
        self.key.zeroize();
        self.nonce.zeroize();
    }
}

impl Drop for ExpandedSecretKey {
    fn drop(&mut self) {
        self.zeroize();
    }
}

impl ExpandedSecretKey {
    /// Convert a 64-byte array into an `ExpandedSecretKey`.
    pub fn from_bytes(bytes: &[u8; 64]) -> ExpandedSecretKey {
        let key = Scalar::from_bits(<[u8; 32]>::try_from(&bytes[..32]).unwrap());
        let mut nonce = [0u8; 32];
        nonce.copy_from_slice(&bytes[32..]);
        ExpandedSecretKey { key, nonce }
    }

    /// Convert this expanded secret key to bytes.
    pub fn to_bytes(&self) -> [u8; 64] {
        let mut bytes = [0u8; 64];
        bytes[..32].copy_from_slice(&self.key.to_bytes());
        bytes[32..].copy_from_slice(&self.nonce);
        bytes
    }
}
