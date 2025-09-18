//! Low-level interfaces to ed25519 functions
//!
//! # ⚠️ Warning: Hazmat
//!
//! These primitives are easy-to-misuse low-level interfaces.
//!
//! If you are an end user / non-expert in cryptography, **do not use any of these functions**.
//! Failure to use them correctly can lead to catastrophic failures including **full private key
//! recovery.**

// Permit dead code because 1) this module is only public when the `hazmat` feature is set, and 2)
// even without `hazmat` we still need this module because this is where `ExpandedSecretKey` is
// defined.
#![allow(dead_code)]

use core::fmt::Debug;

use crate::{InternalError, SignatureError};

use curve25519_dalek::scalar::{Scalar, clamp_integer};
use subtle::{Choice, ConstantTimeEq};

#[cfg(feature = "zeroize")]
use zeroize::{Zeroize, ZeroizeOnDrop};

// These are used in the functions that are made public when the hazmat feature is set
use crate::{Signature, VerifyingKey};
use curve25519_dalek::digest::{Digest, array::typenum::U64};

/// Contains the secret scalar and domain separator used for generating signatures.
///
/// This is used internally for signing.
///
/// Instances of this secret are automatically overwritten with zeroes when they fall out of scope.
pub struct ExpandedSecretKey {
    /// The secret scalar used for signing
    pub scalar: Scalar,
    /// The domain separator used when hashing the message to generate the pseudorandom `r` value
    pub hash_prefix: [u8; 32],
}

impl Debug for ExpandedSecretKey {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("ExpandedSecretKey").finish_non_exhaustive() // avoids printing secrets
    }
}

impl ConstantTimeEq for ExpandedSecretKey {
    fn ct_eq(&self, other: &Self) -> Choice {
        self.scalar.ct_eq(&other.scalar) & self.hash_prefix.ct_eq(&other.hash_prefix)
    }
}

impl PartialEq for ExpandedSecretKey {
    fn eq(&self, other: &Self) -> bool {
        self.ct_eq(other).into()
    }
}

impl Eq for ExpandedSecretKey {}

#[cfg(feature = "zeroize")]
impl Drop for ExpandedSecretKey {
    fn drop(&mut self) {
        self.scalar.zeroize();
        self.hash_prefix.zeroize();
    }
}

#[cfg(feature = "zeroize")]
impl ZeroizeOnDrop for ExpandedSecretKey {}

// Conversion methods for `ExpandedSecretKey`
impl ExpandedSecretKey {
    pub fn from_bytes(bytes: &[u8; 64]) -> Self {
        let mut scalar_bytes: [u8; 32] = [0u8; 32];
        let mut hash_prefix: [u8; 32] = [0u8; 32];
        scalar_bytes.copy_from_slice(&bytes[0..32]);
        hash_prefix.copy_from_slice(&bytes[32..64]);

        let scalar = Scalar::from_bytes_mod_order(clamp_integer(scalar_bytes));

        ExpandedSecretKey {
            scalar,
            hash_prefix,
        }
    }

    pub fn from_slice(bytes: &[u8]) -> Result<Self, SignatureError> {
        bytes.try_into().map(Self::from_bytes).map_err(|_| {
            InternalError::BytesLength {
                name: "ExpandedSecretKey",
                length: 64,
            }
            .into()
        })
    }
}

impl TryFrom<&[u8]> for ExpandedSecretKey {
    type Error = SignatureError;

    fn try_from(bytes: &[u8]) -> Result<Self, Self::Error> {
        Self::from_slice(bytes)
    }
}

// Raw Ed25519 signing functions
pub fn raw_sign<CtxDigest>(
    esk: &ExpandedSecretKey,
    message: &[u8],
    verifying_key: &VerifyingKey,
) -> Signature
where
    CtxDigest: Digest<OutputSize = U64>,
{
    esk.raw_sign::<CtxDigest>(&[message], verifying_key)
}

#[cfg(feature = "digest")]
#[allow(non_snake_case)]
pub fn raw_sign_prehashed<CtxDigest, MsgDigest>(
    esk: &ExpandedSecretKey,
    prehashed_message: MsgDigest,
    verifying_key: &VerifyingKey,
    context: Option<&[u8]>,
) -> Result<Signature, SignatureError>
where
    MsgDigest: Digest<OutputSize = U64>,
    CtxDigest: Digest<OutputSize = U64>,
{
    esk.raw_sign_prehashed::<CtxDigest, MsgDigest>(prehashed_message, verifying_key, context)
}

pub fn raw_sign_byupdate<CtxDigest, F>(
    esk: &ExpandedSecretKey,
    msg_update: F,
    verifying_key: &VerifyingKey,
) -> Result<Signature, SignatureError>
where
    CtxDigest: Digest<OutputSize = U64>,
    F: Fn(&mut CtxDigest) -> Result<(), SignatureError>,
{
    esk.raw_sign_byupdate::<CtxDigest, F>(msg_update, verifying_key)
}

pub fn raw_verify<CtxDigest>(
    vk: &VerifyingKey,
    message: &[u8],
    signature: &ed25519::Signature,
) -> Result<(), SignatureError>
where
    CtxDigest: Digest<OutputSize = U64>,
{
    vk.raw_verify::<CtxDigest>(&[message], signature)
}

#[cfg(feature = "digest")]
#[allow(non_snake_case)]
pub fn raw_verify_prehashed<CtxDigest, MsgDigest>(
    vk: &VerifyingKey,
    prehashed_message: MsgDigest,
    context: Option<&[u8]>,
    signature: &ed25519::Signature,
) -> Result<(), SignatureError>
where
    MsgDigest: Digest<OutputSize = U64>,
    CtxDigest: Digest<OutputSize = U64>,
{
    vk.raw_verify_prehashed::<CtxDigest, MsgDigest>(prehashed_message, context, signature)
}

// Unit tests
#[cfg(test)]
mod test {
    #![allow(clippy::unwrap_used)]
    use super::*;
    use rand::{CryptoRng, TryRngCore, rngs::OsRng};

    type CtxDigest = blake2::Blake2b512;
    type MsgDigest = sha3::Sha3_512;

    impl ExpandedSecretKey {
        fn random<R: CryptoRng + ?Sized>(rng: &mut R) -> Self {
            let mut bytes = [0u8; 64];
            rng.fill_bytes(&mut bytes);
            ExpandedSecretKey::from_bytes(&bytes)
        }
    }

    #[test]
    fn sign_verify_nonspec() {
        let mut rng = OsRng.unwrap_err();
        let esk = ExpandedSecretKey::random(&mut rng);
        let vk = VerifyingKey::from(&esk);
        let msg = b"Then one day, a piano fell on my head";

        let sig = raw_sign::<CtxDigest>(&esk, msg, &vk);
        raw_verify::<CtxDigest>(&vk, msg, &sig).unwrap();
    }

    #[cfg(feature = "digest")]
    #[test]
    fn sign_verify_prehashed_nonspec() {
        use curve25519_dalek::digest::Digest;

        let mut rng = OsRng.unwrap_err();
        let esk = ExpandedSecretKey::random(&mut rng);
        let vk = VerifyingKey::from(&esk);

        let msg = b"And then I got trampled by a herd of buffalo";
        let mut h = MsgDigest::new();
        h.update(msg);

        let ctx_str = &b"consequences"[..];

        let sig = raw_sign_prehashed::<CtxDigest, MsgDigest>(&esk, h.clone(), &vk, Some(ctx_str))
            .unwrap();
        raw_verify_prehashed::<CtxDigest, MsgDigest>(&vk, h, Some(ctx_str), &sig).unwrap();
    }

    #[test]
    fn sign_byupdate() {
        let mut rng = OsRng.unwrap_err();
        let esk = ExpandedSecretKey::random(&mut rng);
        let vk = VerifyingKey::from(&esk);

        let msg = b"realistic";
        let good_sig = raw_sign::<CtxDigest>(&esk, msg, &vk);

        let sig = raw_sign_byupdate::<CtxDigest, _>(&esk, |h| {
            h.update(msg);
            Ok(())
        }, &vk);
        assert!(sig.unwrap() == good_sig);

        let sig = raw_sign_byupdate::<CtxDigest, _>(&esk, |h| {
            h.update(msg);
            Err(SignatureError::new())
        }, &vk);
        assert!(sig.is_err());

        let sig = raw_sign_byupdate::<CtxDigest, _>(&esk, |h| {
            h.update(&msg[..1]);
            h.update(&msg[1..]);
            Ok(())
        }, &vk);
        assert!(sig.unwrap() == good_sig);
    }
}
