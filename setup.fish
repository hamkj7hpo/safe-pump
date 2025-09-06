#!/usr/bin/env fish

set -l repos \
    "solana" \
    "spl-pod" \
    "anchor" \
    "zk-elgamal-proof" \
    "token-2022" \
    "associated-token-account" \
    "solana-program-library" \
    "spl-type-length-value" \
    "token-group" \
    "token-metadata" \
    "transfer-hook" \
    "memo" \
    "raydium-cp-swap"

set -l tmp_dir /tmp/deps
set -l project_dir /var/www/html/program/safe_pump
set -l branch safe-pump-compat

# Ensure git is configured
echo "Checking git configuration..."
if not git config user.name >/dev/null || not git config user.email >/dev/null
    echo "Git user.name or user.email not set. Please configure git:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
    exit 1
end

# Commit any changes to setup.fish to avoid uncommitted changes
cd $project_dir
if git status --porcelain | grep -q "setup.fish"
    echo "Committing changes to setup.fish..."
    git add setup.fish
    git commit -m "Update setup.fish for dependency patching" || true
    git push origin main || true
end

# Create temporary directory for dependencies
mkdir -p $tmp_dir

# Clone or update repositories
for repo in $repos
    set -l repo_dir $tmp_dir/$repo
    set -l repo_url https://github.com/hamkj7hpo/$repo.git

    echo "Processing $repo into $repo_dir..."
    if test -d $repo_dir
        echo "$repo_dir already exists, updating..."
        cd $repo_dir
        git fetch origin
        echo "Checking out $branch for $repo..."
        git checkout $branch || git checkout -b $branch
        git reset --hard origin/$branch
        git pull origin $branch
    else
        echo "Cloning $repo into $repo_dir..."
        git clone --branch $branch $repo_url $repo_dir
        cd $repo_dir
    end

    # Force specific revisions for problematic dependencies
    switch $repo
        case solana
            git fetch origin
            git checkout 079536b9
            git reset --hard 079536b9
        case spl-pod
            git fetch origin
            git checkout 2bcbbd69
            git reset --hard 2bcbbd69
        case zk-elgamal-proof
            git fetch origin
            git checkout b0a83885
            git reset --hard b0a83885
        case associated-token-account
            git fetch origin
            git checkout cb404795
            git reset --hard cb404795
    end
end

# Patch dependency Cargo.toml files
echo "Patching /tmp/deps/solana/sdk/program/Cargo.toml for curve25519-dalek..."
cd /tmp/deps/solana/sdk/program
sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", rev = "4e0e4d6", default-features = false, features = ["std"] }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
git add Cargo.toml
git commit -m "Patch curve25519-dalek and zeroize to safe-pump-compat rev" || true
git push origin $branch || true

echo "Patching /tmp/deps/zk-elgamal-proof/Cargo.toml for solana-program and zeroize..."
cd /tmp/deps/zk-elgamal-proof
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program and zeroize to safe-pump-compat revs" || true
git push origin $branch || true

echo "Patching /tmp/deps/spl-pod/Cargo.toml for solana-program and solana-zk-sdk..."
cd /tmp/deps/spl-pod
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", rev = "b0a83885" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program, solana-zk-sdk, and zeroize to safe-pump-compat revs" || true
git push origin $branch || true

echo "Patching /tmp/deps/anchor/spl/Cargo.toml for solana-program..."
cd /tmp/deps/anchor/spl
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat rev" || true
git push origin $branch || true

echo "Patching /tmp/deps/token-2022/Cargo.toml for solana-zk-sdk and solana-program..."
cd /tmp/deps/token-2022
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", rev = "b0a83885" }|' Cargo.toml
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-zk-sdk, solana-program, and zeroize to safe-pump-compat revs" || true
git push origin $branch || true

echo "Patching /tmp/deps/associated-token-account/Cargo.toml for solana-program..."
cd /tmp/deps/associated-token-account
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|spl-token =.*|spl-token = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
sed -i 's|spl-discriminator =.*|spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
sed -i 's|spl-program-error =.*|spl-program-error = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program and solana-program-library dependencies to safe-pump-compat revs" || true
git push origin $branch || true

echo "Patching /tmp/deps/solana-program-library/libraries/discriminator/Cargo.toml for solana-program..."
cd /tmp/deps/solana-program-library/libraries/discriminator
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat rev" || true
git push origin $branch || true

echo "Patching /tmp/deps/spl-type-length-value/Cargo.toml for solana-program and spl-pod..."
cd /tmp/deps/spl-type-length-value
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", rev = "2bcbbd69" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program and spl-pod to safe-pump-compat revs" || true
git push origin $branch || true

echo "Patching /tmp/deps/token-group/Cargo.toml for solana-program and spl-pod..."
cd /tmp/deps/token-group
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", rev = "2bcbbd69" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program and spl-pod to safe-pump-compat revs" || true
git push origin $branch || true

echo "Patching /tmp/deps/token-metadata/Cargo.toml for solana-program and spl-pod..."
cd /tmp/deps/token-metadata
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", rev = "2bcbbd69" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program and spl-pod to safe-pump-compat revs" || true
git push origin $branch || true

echo "Patching /tmp/deps/transfer-hook/Cargo.toml for solana-program..."
cd /tmp/deps/transfer-hook
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat rev" || true
git push origin $branch || true

echo "Patching /tmp/deps/memo/Cargo.toml for solana-program..."
cd /tmp/deps/memo
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat rev" || true
git push origin $branch || true

echo "Patching /tmp/deps/raydium-cp-swap/Cargo.toml for solana-program, solana-zk-sdk, and zeroize..."
cd /tmp/deps/raydium-cp-swap
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", rev = "b0a83885" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program, solana-zk-sdk, and zeroize to safe-pump-compat revs" || true
git push origin $branch || true

echo "Patching /tmp/deps/raydium-cp-swap/programs/cp-swap/Cargo.toml for solana-program, solana-zk-sdk, zeroize, and spl-token-2022..."
cd /tmp/deps/raydium-cp-swap/programs/cp-swap
sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", rev = "b0a83885" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
sed -i 's|spl-token-2022 =.*|spl-token-2022 = { git = "https://github.com/hamkj7hpo/token-2022.git", rev = "c07e6ca2" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program, solana-zk-sdk, zeroize, and spl-token-2022 to safe-pump-compat revs" || true
git push origin $branch || true

# Patch the main project's Cargo.toml
echo "Patching $project_dir/Cargo.toml for dependencies..."
cd $project_dir
# Ensure all dependencies use the correct revisions
sed -i '/\[dependencies\]/,/^\[/ s|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", rev = "2bcbbd69" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-associated-token-account =.*|spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", rev = "cb404795" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", rev = "b0a83885" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-tlv-account-resolution =.*|spl-tlv-account-resolution = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", rev = "29a9d9520" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token =.*|spl-token = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-discriminator =.*|spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-program-error =.*|spl-program-error = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
# Add or update patch section to override solana-program
if ! grep -q "\[patch.crates-io\]" Cargo.toml
    echo -e "\n[patch.crates-io]" >> Cargo.toml
    echo 'solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", rev = "2bcbbd69" }' >> Cargo.toml
    echo 'solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", rev = "b0a83885" }' >> Cargo.toml
    echo 'spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", rev = "cb404795" }' >> Cargo.toml
    echo 'spl-token = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }' >> Cargo.toml
    echo 'spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }' >> Cargo.toml
    echo 'spl-program-error = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }' >> Cargo.toml
    echo 'spl-tlv-account-resolution = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", rev = "29a9d9520" }' >> Cargo.toml
else
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", rev = "2bcbbd69" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", rev = "b0a83885" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-associated-token-account =.*|spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", rev = "cb404795" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-token =.*|spl-token = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-discriminator =.*|spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-program-error =.*|spl-program-error = { git = "https://github.com/hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-tlv-account-resolution =.*|spl-tlv-account-resolution = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", rev = "29a9d9520" }|' Cargo.toml
end
git add Cargo.toml
git commit -m "Update dependencies to use safe-pump-compat revs for zeroize 1.3.0 compatibility" || true
git push origin main || true

# Clean and build the project
echo "Cleaning and building project..."
cd $project_dir
cargo clean
if cargo build
    echo "Build successful!"
else
    echo "Build failed, check output for errors."
    echo "Generating diagnostic report..."
    cargo build --verbose > /tmp/safe_pump_diagnostic_report.txt 2>&1
    echo "Diagnostic report saved to /tmp/safe_pump_diagnostic_report.txt"
    exit 1
end
