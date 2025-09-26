use thiserror::Error;
use solana_program::program_error::ProgramError;
use spl_program_error::spl_program_error;

#[derive(Error, Debug, Clone, PartialEq)]
#[spl_program_error]
pub enum PodSliceError {
    #[error("Error in checked math operation")]
    CalculationFailure,
    #[error("Provided byte buffer too small for expected type")]
    BufferTooSmall,
    #[error("Provided byte buffer too large for expected type")]
    BufferTooLarge,
}

impl From<PodSliceError> for ProgramError {
    fn from(e: PodSliceError) -> Self {
        ProgramError::Custom(e as u32)
    }
}
