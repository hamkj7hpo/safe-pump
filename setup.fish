#!/usr/bin/env fish

# Diagnostic script for safe_pump and curve25519-dalek dependency alignment
set SAFE_PUMP_DIR "/var/www/html/program/safe_pump"
set CURVE_DALEK_DIR "/tmp/deps/curve25519-dalek"
set OUTPUT_FILE "/tmp/safe_pump_diagnostic_report.txt"

# Function to print section headers
function print_section
    echo "===== $argv[1] =====" >> $OUTPUT_FILE
    echo $argv[1]
end

# Initialize output file
echo "Safe Pump and Curve25519-Dalek Diagnostic Report" > $OUTPUT_FILE
echo "Generated on: "(date) >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 1. Check git status for safe_pump
print_section "Git Status: safe_pump ($SAFE_PUMP_DIR)"
cd $SAFE_PUMP_DIR
git status >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 2. Check current commit for safe_pump
print_section "Current Commit: safe_pump"
git log -1 --pretty=%H%n%s%n%an%n%ad >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 3. Check git status for curve25519-dalek
print_section "Git Status: curve25519-dalek ($CURVE_DALEK_DIR)"
cd $CURVE_DALEK_DIR
git status >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 4. Check current commit for curve25519-dalek
print_section "Current Commit: curve25519-dalek"
git log -1 --pretty=%H%n%s%n%an%n%ad >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 5. Check dependency tree for curve25519-dalek
print_section "Dependency Tree: curve25519-dalek"
cargo tree >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 6. Check dependency tree for safe_pump
print_section "Dependency Tree: safe_pump"
cd $SAFE_PUMP_DIR
cargo tree >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 7. Check inverse dependency tree for curve25519-dalek in safe_pump
print_section "Inverse Dependency Tree for curve25519-dalek in safe_pump"
cargo tree --invert curve25519-dalek >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 8. Check for cargo conflicts in safe_pump
print_section "Cargo Dependency Check: safe_pump"
cargo check 2>> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 9. Check Cargo.toml for safe_pump
print_section "Cargo.toml: safe_pump"
cat $SAFE_PUMP_DIR/Cargo.toml >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 10. Check Cargo.toml for curve25519-dalek
print_section "Cargo.toml: curve25519-dalek"
cat $CURVE_DALEK_DIR/curve25519-dalek/Cargo.toml >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 11. Check for uncommitted changes in safe-pump-compat-v2 branch
print_section "Uncommitted Changes in safe-pump-compat-v2 (curve25519-dalek)"
cd $CURVE_DALEK_DIR
git diff origin/safe-pump-compat-v2 >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# 12. Check for uncommitted changes in safe_pump main branch
print_section "Uncommitted Changes in main (safe_pump)"
cd $SAFE_PUMP_DIR
git diff origin/main >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Final message
echo "Diagnostic report generated at $OUTPUT_FILE"
cat $OUTPUT_FILE
