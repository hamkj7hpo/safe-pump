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
    "raydium-cp-swap" \
    "base64" \
    "bincode" \
    "borsh" \
    "bytemuck" \
    "bytemuck_derive" \
    "getrandom" \
    "itertools" \
    "lazy_static" \
    "light-poseidon" \
    "num" \
    "num-derive" \
    "num-traits" \
    "rand" \
    "serde" \
    "serde_derive" \
    "serde_json" \
    "sha3" \
    "subtle" \
    "thiserror" \
    "tiny-bip39" \
    "js-sys" \
    "wasm-bindgen" \
    "aes-gcm-siv" \
    "spl-math" \
    "arrayref" \
    "uint"

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

# Commit any changes to setup.fish
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
    set -l repo_url git@github.com:hamkj7hpo/$repo.git

    echo "Processing $repo into $repo_dir..."
    if test -d $repo_dir
        echo "$repo_dir already exists, updating..."
        cd $repo_dir
        git fetch origin
        echo "Checking out $branch for $repo..."
        git checkout $branch || git checkout -b $branch
        git pull origin $branch || true
    else
        echo "Cloning $repo into $repo_dir..."
        git clone $repo_url $repo_dir || continue
        cd $repo_dir
        git checkout $branch || git checkout -b $branch
    end

    # Force specific revisions for problematic dependencies
    switch $repo
        case solana
            git checkout 079536b9
            git reset --hard 079536b9
        case spl-pod
            git checkout 2bcbbd69
            git reset --hard 2bcbbd69
        case zk-elgamal-proof
            git checkout b0a83885
            git reset --hard b0a83885
        case associated-token-account
            git checkout cb404795
            git reset --hard cb404795
        case token-2022
            git checkout c07e6ca2
            git reset --hard c07e6ca2
        case spl-type-length-value
            git checkout 50f00a65
            git reset --hard 50f00a65
        case token-group
            git checkout 5442931a
            git reset --hard 5442931a
        case token-metadata
            git checkout f5a9a37d
            git reset --hard f5a9a37d
        case transfer-hook
            git checkout faeabf52
            git reset --hard faeabf52
        case memo
            git checkout 7d7a67db
            git reset --hard 7d7a67db
        case raydium-cp-swap
            git checkout 33d438c6
            git reset --hard 33d438c6
    end
end

# Patch dependency Cargo.toml files
echo "Patching /tmp/deps/solana/sdk/program/Cargo.toml..."
cd /tmp/deps/solana/sdk/program
sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "git@github.com:hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", default-features = false, features = ["std"] }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "git@github.com:hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch curve25519-dalek and zeroize to safe-pump-compat-v2" || true
git push origin $branch || true

echo "Patching /tmp/deps/zk-elgamal-proof/Cargo.toml..."
cd /tmp/deps/zk-elgamal-proof
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "git@github.com:hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["serde"] }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "git@github.com:hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-sdk =.*|solana-sdk = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|aes-gcm-siv =.*|aes-gcm-siv = { git = "git@github.com:hamkj7hpo/aes-gcm-siv.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|base64 =.*|base64 = { git = "git@github.com:hamkj7hpo/base64.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bincode =.*|bincode = { git = "git@github.com:hamkj7hpo/bincode.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|borsh =.*|borsh = { git = "git@github.com:hamkj7hpo/borsh.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bytemuck =.*|bytemuck = { git = "git@github.com:hamkj7hpo/bytemuck.git", branch = "safe-pump-compat", features = ["derive"] }|' Cargo.toml
sed -i 's|getrandom =.*|getrandom = { git = "git@github.com:hamkj7hpo/getrandom.git", branch = "safe-pump-compat", features = ["custom"] }|' Cargo.toml
sed -i 's|lazy_static =.*|lazy_static = { git = "git@github.com:hamkj7hpo/lazy_static.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|light-poseidon =.*|light-poseidon = { git = "git@github.com:hamkj7hpo/light-poseidon.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num =.*|num = { git = "git@github.com:hamkj7hpo/num.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num-derive =.*|num-derive = { git = "git@github.com:hamkj7hpo/num-derive.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num-traits =.*|num-traits = { git = "git@github.com:hamkj7hpo/num-traits.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|rand =.*|rand = { git = "git@github.com:hamkj7hpo/rand.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|serde =.*|serde = { git = "git@github.com:hamkj7hpo/serde.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|sha3 =.*|sha3 = { git = "git@github.com:hamkj7hpo/sha3.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|thiserror =.*|thiserror = { git = "git@github.com:hamkj7hpo/thiserror.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|tiny-bip39 =.*|tiny-bip39 = { git = "git@github.com:hamkj7hpo/tiny-bip39.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat-v2" || true
git push origin $branch || true

echo "Patching /tmp/deps/zk-elgamal-proof/zk-sdk/Cargo.toml..."
cd /tmp/deps/zk-elgamal-proof/zk-sdk
sed -i 's|base64 =.*|base64 = { git = "git@github.com:hamkj7hpo/base64.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bytemuck =.*|bytemuck = { git = "git@github.com:hamkj7hpo/bytemuck.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bytemuck_derive =.*|bytemuck_derive = { git = "git@github.com:hamkj7hpo/bytemuck_derive.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num-derive =.*|num-derive = { git = "git@github.com:hamkj7hpo/num-derive.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num-traits =.*|num-traits = { git = "git@github.com:hamkj7hpo/num-traits.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-instruction =.*|solana-instruction = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9", features = ["std"] }|' Cargo.toml
sed -i 's|solana-pubkey =.*|solana-pubkey = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9", features = ["bytemuck"] }|' Cargo.toml
sed -i 's|solana-sdk-ids =.*|solana-sdk-ids = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|thiserror =.*|thiserror = { git = "git@github.com:hamkj7hpo/thiserror.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|aes-gcm-siv =.*|aes-gcm-siv = { git = "git@github.com:hamkj7hpo/aes-gcm-siv.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bincode =.*|bincode = { git = "git@github.com:hamkj7hpo/bincode.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "git@github.com:hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["serde"] }|' Cargo.toml
sed -i 's|itertools =.*|itertools = { git = "git@github.com:hamkj7hpo/itertools.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|merlin =.*|merlin = { git = "git@github.com:hamkj7hpo/merlin.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|rand =.*|rand = { git = "git@github.com:hamkj7hpo/rand.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|serde =.*|serde = { git = "git@github.com:hamkj7hpo/serde.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|serde_derive =.*|serde_derive = { git = "git@github.com:hamkj7hpo/serde_derive.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|serde_json =.*|serde_json = { git = "git@github.com:hamkj7hpo/serde_json.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|sha3 =.*|sha3 = { git = "git@github.com:hamkj7hpo/sha3.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-derivation-path =.*|solana-derivation-path = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-seed-derivable =.*|solana-seed-derivable = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-seed-phrase =.*|solana-seed-phrase = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-signature =.*|solana-signature = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-signer =.*|solana-signer = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|subtle =.*|subtle = { git = "git@github.com:hamkj7hpo/subtle.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "git@github.com:hamkj7hpo/zeroize.git", branch = "safe-pump-compat", features = ["zeroize_derive"] }|' Cargo.toml
sed -i 's|getrandom =.*|getrandom = { git = "git@github.com:hamkj7hpo/getrandom.git", branch = "safe-pump-compat", features = ["js"] }|' Cargo.toml
sed -i 's|js-sys =.*|js-sys = { git = "git@github.com:hamkj7hpo/js-sys.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|wasm-bindgen =.*|wasm-bindgen = { git = "git@github.com:hamkj7hpo/wasm-bindgen.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-keypair =.*|solana-keypair = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|tiny-bip39 =.*|tiny-bip39 = { git = "git@github.com:hamkj7hpo/tiny-bip39.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/spl-pod/Cargo.toml..."
cd /tmp/deps/spl-pod
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "git@github.com:hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "git@github.com:hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/anchor/spl/Cargo.toml..."
cd /tmp/deps/anchor/spl
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/token-2022/Cargo.toml..."
cd /tmp/deps/token-2022
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "git@github.com:hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "git@github.com:hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/associated-token-account/Cargo.toml..."
cd /tmp/deps/associated-token-account
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|spl-token =.*|spl-token = { git = "git@github.com:hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
sed -i 's|spl-discriminator =.*|spl-discriminator = { git = "git@github.com:hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
sed -i 's|spl-program-error =.*|spl-program-error = { git = "git@github.com:hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/solana-program-library/libraries/discriminator/Cargo.toml..."
cd /tmp/deps/solana-program-library/libraries/discriminator
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/spl-type-length-value/Cargo.toml..."
cd /tmp/deps/spl-type-length-value
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|spl-pod =.*|spl-pod = { git = "git@github.com:hamkj7hpo/spl-pod.git", rev = "2bcbbd69" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/token-group/Cargo.toml..."
cd /tmp/deps/token-group
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|spl-pod =.*|spl-pod = { git = "git@github.com:hamkj7hpo/spl-pod.git", rev = "2bcbbd69" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/token-metadata/Cargo.toml..."
cd /tmp/deps/token-metadata
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|spl-pod =.*|spl-pod = { git = "git@github.com:hamkj7hpo/spl-pod.git", rev = "2bcbbd69" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/transfer-hook/Cargo.toml..."
cd /tmp/deps/transfer-hook
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/memo/Cargo.toml..."
cd /tmp/deps/memo
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/raydium-cp-swap/Cargo.toml..."
cd /tmp/deps/raydium-cp-swap
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "git@github.com:hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "git@github.com:hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/raydium-cp-swap/programs/cp-swap/Cargo.toml..."
cd /tmp/deps/raydium-cp-swap/programs/cp-swap
sed -i 's|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "git@github.com:hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "git@github.com:hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|spl-token-2022 =.*|spl-token-2022 = { git = "git@github.com:hamkj7hpo/token-2022.git", rev = "c07e6ca2" }|' Cargo.toml
sed -i 's|spl-math =.*|spl-math = { git = "git@github.com:hamkj7hpo/spl-math.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|arrayref =.*|arrayref = { git = "git@github.com:hamkj7hpo/arrayref.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bytemuck =.*|bytemuck = { git = "git@github.com:hamkj7hpo/bytemuck.git", branch = "safe-pump-compat", features = ["derive"] }|' Cargo.toml
sed -i 's|uint =.*|uint = { git = "git@github.com:hamkj7hpo/uint.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bincode =.*|bincode = { git = "git@github.com:hamkj7hpo/bincode.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat" || true
git push origin $branch || true

# Patch the main project's Cargo.toml
echo "Patching $project_dir/Cargo.toml..."
cd $project_dir
sed -i '/\[dependencies\]/,/^\[/ s|base64ct =.*|base64ct = { git = "git@github.com:hamkj7hpo/base64ct.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|bincode =.*|bincode = { git = "git@github.com:hamkj7hpo/bincode.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|bytemuck =.*|bytemuck = { git = "git@github.com:hamkj7hpo/bytemuck.git", branch = "safe-pump-compat", features = ["derive"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|zeroize =.*|zeroize = { git = "git@github.com:hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|rand =.*|rand = { git = "git@github.com:hamkj7hpo/rand.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|sha3 =.*|sha3 = { git = "git@github.com:hamkj7hpo/sha3.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|merlin =.*|merlin = { git = "git@github.com:hamkj7hpo/merlin.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { git = "git@github.com:hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-pod =.*|spl-pod = { git = "git@github.com:hamkj7hpo/spl-pod.git", rev = "2bcbbd69", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-associated-token-account =.*|spl-associated-token-account = { git = "git@github.com:hamkj7hpo/associated-token-account.git", rev = "cb404795" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-tlv-account-resolution =.*|spl-tlv-account-resolution = { git = "git@github.com:hamkj7hpo/spl-type-length-value.git", rev = "50f00a65" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-discriminator =.*|spl-discriminator = { git = "git@github.com:hamkj7hpo/solana-program-library.git", rev = "425379d49" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-2022 =.*|spl-token-2022 = { git = "git@github.com:hamkj7hpo/token-2022.git", rev = "c07e6ca2", package = "spl-token-2022", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-memo =.*|spl-memo = { git = "git@github.com:hamkj7hpo/memo.git", rev = "7d7a67db", package = "spl-memo", version = "6.0.0" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-transfer-hook-interface =.*|spl-transfer-hook-interface = { git = "git@github.com:hamkj7hpo/transfer-hook.git", rev = "faeabf52", package = "spl-transfer-hook-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-metadata-interface =.*|spl-token-metadata-interface = { git = "git@github.com:hamkj7hpo/token-metadata.git", rev = "f5a9a37d", package = "spl-token-metadata-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-group-interface =.*|spl-token-group-interface = { git = "git@github.com:hamkj7hpo/token-group.git", rev = "5442931a", package = "spl-token-group-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|anchor-lang =.*|anchor-lang = { git = "git@github.com:hamkj7hpo/anchor.git", rev = "733602ae", features = ["init-if-needed"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|anchor-spl =.*|anchor-spl = { git = "git@github.com:hamkj7hpo/anchor.git", rev = "733602ae", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|raydium-cp-swap =.*|raydium-cp-swap = { git = "git@github.com:hamkj7hpo/raydium-cp-swap.git", rev = "33d438c6", package = "raydium-cp-swap", default-features = false }|' Cargo.toml

# Update patch section
if ! grep -q "\[patch.crates-io\]" Cargo.toml
    echo -e "\n[patch.crates-io]" >> Cargo.toml
    echo 'curve25519-dalek = { git = "git@github.com:hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2" }' >> Cargo.toml
    echo 'solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'spl-pod = { git = "git@github.com:hamkj7hpo/spl-pod.git", rev = "2bcbbd69", default-features = false }' >> Cargo.toml
    echo 'solana-zk-sdk = { git = "git@github.com:hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-associated-token-account = { git = "git@github.com:hamkj7hpo/associated-token-account.git", rev = "cb404795" }' >> Cargo.toml
    echo 'spl-type-length-value = { git = "git@github.com:hamkj7hpo/spl-type-length-value.git", rev = "50f00a65" }' >> Cargo.toml
    echo 'spl-memo = { git = "git@github.com:hamkj7hpo/memo.git", rev = "7d7a67db", version = "6.0.0" }' >> Cargo.toml
    echo 'spl-token-2022 = { git = "git@github.com:hamkj7hpo/token-2022.git", rev = "c07e6ca2" }' >> Cargo.toml
    echo 'spl-transfer-hook-interface = { git = "git@github.com:hamkj7hpo/transfer-hook.git", rev = "faeabf52" }' >> Cargo.toml
    echo 'spl-token-metadata-interface = { git = "git@github.com:hamkj7hpo/token-metadata.git", rev = "f5a9a37d" }' >> Cargo.toml
    echo 'spl-token-group-interface = { git = "git@github.com:hamkj7hpo/token-group.git", rev = "5442931a" }' >> Cargo.toml
    echo 'anchor-lang = { git = "git@github.com:hamkj7hpo/anchor.git", rev = "733602ae" }' >> Cargo.toml
    echo 'anchor-spl = { git = "git@github.com:hamkj7hpo/anchor.git", rev = "733602ae" }' >> Cargo.toml
    echo 'raydium-cp-swap = { git = "git@github.com:hamkj7hpo/raydium-cp-swap.git", rev = "33d438c6" }' >> Cargo.toml
    echo 'solana-instruction = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'solana-pubkey = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'solana-sdk-ids = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'solana-derivation-path = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'solana-seed-derivable = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'solana-seed-phrase = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'solana-signature = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'solana-signer = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'solana-keypair = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    echo 'base64 = { git = "git@github.com:hamkj7hpo/base64.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'bincode = { git = "git@github.com:hamkj7hpo/bincode.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'bytemuck = { git = "git@github.com:hamkj7hpo/bytemuck.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'bytemuck_derive = { git = "git@github.com:hamkj7hpo/bytemuck_derive.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'getrandom = { git = "git@github.com:hamkj7hpo/getrandom.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'itertools = { git = "git@github.com:hamkj7hpo/itertools.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'lazy_static = { git = "git@github.com:hamkj7hpo/lazy_static.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'light-poseidon = { git = "git@github.com:hamkj7hpo/light-poseidon.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'num = { git = "git@github.com:hamkj7hpo/num.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'num-derive = { git = "git@github.com:hamkj7hpo/num-derive.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'num-traits = { git = "git@github.com:hamkj7hpo/num-traits.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'rand = { git = "git@github.com:hamkj7hpo/rand.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'serde = { git = "git@github.com:hamkj7hpo/serde.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'serde_derive = { git = "git@github.com:hamkj7hpo/serde_derive.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'serde_json = { git = "git@github.com:hamkj7hpo/serde_json.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'sha3 = { git = "git@github.com:hamkj7hpo/sha3.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'subtle = { git = "git@github.com:hamkj7hpo/subtle.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'thiserror = { git = "git@github.com:hamkj7hpo/thiserror.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'tiny-bip39 = { git = "git@github.com:hamkj7hpo/tiny-bip39.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'js-sys = { git = "git@github.com:hamkj7hpo/js-sys.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'wasm-bindgen = { git = "git@github.com:hamkj7hpo/wasm-bindgen.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'aes-gcm-siv = { git = "git@github.com:hamkj7hpo/aes-gcm-siv.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-math = { git = "git@github.com:hamkj7hpo/spl-math.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'arrayref = { git = "git@github.com:hamkj7hpo/arrayref.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'uint = { git = "git@github.com:hamkj7hpo/uint.git", branch = "safe-pump-compat" }' >> Cargo.toml
else
    sed -i '/\[patch.crates-io\]/,/^\[/ s|curve25519-dalek =.*|curve25519-dalek = { git = "git@github.com:hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-program =.*|solana-program = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-pod =.*|spl-pod = { git = "git@github.com:hamkj7hpo/spl-pod.git", rev = "2bcbbd69", default-features = false }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { git = "git@github.com:hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-associated-token-account =.*|spl-associated-token-account = { git = "git@github.com:hamkj7hpo/associated-token-account.git", rev = "cb404795" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-type-length-value =.*|spl-type-length-value = { git = "git@github.com:hamkj7hpo/spl-type-length-value.git", rev = "50f00a65" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-memo =.*|spl-memo = { git = "git@github.com:hamkj7hpo/memo.git", rev = "7d7a67db", version = "6.0.0" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-instruction =.*|solana-instruction = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml || echo 'solana-instruction = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-pubkey =.*|solana-pubkey = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml || echo 'solana-pubkey = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-sdk-ids =.*|solana-sdk-ids = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml || echo 'solana-sdk-ids = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-derivation-path =.*|solana-derivation-path = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml || echo 'solana-derivation-path = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-seed-derivable =.*|solana-seed-derivable = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml || echo 'solana-seed-derivable = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-seed-phrase =.*|solana-seed-phrase = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml || echo 'solana-seed-phrase = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-signature =.*|solana-signature = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml || echo 'solana-signature = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-signer =.*|solana-signer = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml || echo 'solana-signer = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-keypair =.*|solana-keypair = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }|' Cargo.toml || echo 'solana-keypair = { git = "git@github.com:hamkj7hpo/solana.git", rev = "079536b9" }' >> Cargo.toml
end
git add Cargo.toml
git commit -m "Update dependencies to safe-pump-compat for zeroize 1.3.0 compatibility" || true
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
```
