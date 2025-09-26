use curve25519_dalek::ristretto::RistrettoPoint;
use curve25519_dalek::scalar::Scalar;

#[no_mangle]
pub fn test_curve25519_dalek() -> RistrettoPoint {
    let scalar = Scalar::one();
    RistrettoPoint::default() * scalar
}
