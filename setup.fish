#!/usr/bin/env fish

# Define repositories under hamkj7hpo
set -l hamkj_repos \
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
    "curve25519-dalek" \
    "zeroize" \
    "utils" \
    "bincode" \
    "bytemuck" \
    "rand" \
    "hashes" \
    "merlin" \
    "rust-base64" \
    "getrandom" \
    "itertools" \
    "lazy-static.rs" \
    "light-poseidon" \
    "num" \
    "num-derive" \
    "num-traits" \
    "serde" \
    "json" \
    "subtle" \
    "thiserror" \
    "tiny-bip39" \
    "js-sys" \
    "wasm-bindgen" \
    "AEADs" \
    "arrayref" \
    "parity-common"

set -l tmp_dir /tmp/deps
set -l project_dir /var/www/html/program/safe_pump
set -l branch safe-pump-compat
set -l github_user hamkj7hpo

# Ensure git is configured
echo "Checking git configuration..."
if not git config user.name >/dev/null || not git config user.email >/dev/null
    echo "Git user.name or user.email not set. Please configure git:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
    exit 1
end

# Verify SSH key is set up
if not ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"
    echo "SSH key not set up correctly for GitHub. Please ensure your SSH key is added to your GitHub account."
    echo "See: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
    exit 1
end

# Commit any changes to setup.fish
cd $project_dir
if git status --porcelain | grep -q "setup.fish"
    echo "Committing changes to setup.fish..."
    git add setup.fish
    git commit -m "Update setup.fish for SSH dependency patching" || true
    git push origin main || true
end

# Create temporary directory for dependencies
mkdir -p $tmp_dir

# Process hamkj7hpo repositories
for repo in $hamkj_repos
    set -l repo_dir $tmp_dir/$repo
    set -l repo_url git@github.com:$github_user/$repo.git

    echo "Processing $repo into $repo_dir..."
    if test -d $repo_dir
        echo "$repo_dir already exists, updating..."
        cd $repo_dir
        # Ensure remote is set to SSH
        if not git remote get-url origin | grep -q "git@github.com"
            echo "Setting remote to SSH for $repo..."
            git remote set-url origin $repo_url
        end
        git fetch origin
        echo "Checking out $branch for $repo..."
        if test "$repo" = "curve25519-dalek"
            git checkout safe-pump-compat-v2 || git checkout -b safe-pump-compat-v2
            git pull origin safe-pump-compat-v2 || true
        else
            git checkout $branch || git checkout -b $branch
            git pull origin $branch || true
        end
    else
        echo "Cloning $repo into $repo_dir using SSH..."
        if git clone $repo_url $repo_dir
            cd $repo_dir
            if test "$repo" = "curve25519-dalek"
                git checkout safe-pump-compat-v2 || git checkout -b safe-pump-compat-v2
            else
                git checkout $branch || git checkout -b $branch
            end
        else
            echo "Failed to clone $repo. Ensure the repository exists at $repo_url and you have access."
            continue
        end
    end
end

# Patch dependency Cargo.toml files
echo "Patching /tmp/deps/solana/sdk/program/Cargo.toml..."
cd /tmp/deps/solana/sdk/program
sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "ssh://git@github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", default-features = false, features = ["std"] }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "ssh://git@github.com/hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch curve25519-dalek and zeroize to safe-pump-compat" || true
git push origin $branch || true

echo "Patching /tmp/deps/zk-elgamal-proof/Cargo.toml..."
cd /tmp/deps/zk-elgamal-proof
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "ssh://git@github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["serde"] }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "ssh://git@github.com/hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-sdk =.*|solana-sdk = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|aes-gcm-siv =.*|aes-gcm-siv = { git = "ssh://git@github.com/hamkj7hpo/AEADs.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|base64 =.*|base64 = { git = "ssh://git@github.com/hamkj7hpo/rust-base64.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bincode =.*|bincode = { git = "ssh://git@github.com/hamkj7hpo/bincode.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bytemuck =.*|bytemuck = { git = "ssh://git@github.com/hamkj7hpo/bytemuck.git", branch = "safe-pump-compat", features = ["derive"] }|' Cargo.toml
sed -i 's|getrandom =.*|getrandom = { git = "ssh://git@github.com/hamkj7hpo/getrandom.git", branch = "safe-pump-compat", features = ["custom"] }|' Cargo.toml
sed -i 's|lazy_static =.*|lazy_static = { git = "ssh://git@github.com/hamkj7hpo/lazy-static.rs.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|light-poseidon =.*|light-poseidon = { git = "ssh://git@github.com/hamkj7hpo/light-poseidon.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num =.*|num = { git = "ssh://git@github.com/hamkj7hpo/num.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num-derive =.*|num-derive = { git = "ssh://git@github.com/hamkj7hpo/num-derive.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num-traits =.*|num-traits = { git = "ssh://git@github.com/hamkj7hpo/num-traits.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|rand =.*|rand = { git = "ssh://git@github.com/hamkj7hpo/rand.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|serde =.*|serde = { git = "ssh://git@github.com/hamkj7hpo/serde.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|sha3 =.*|sha3 = { git = "ssh://git@github.com/hamkj7hpo/hashes.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|thiserror =.*|thiserror = { git = "ssh://git@github.com/hamkj7hpo/thiserror.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|tiny-bip39 =.*|tiny-bip39 = { git = "ssh://git@github.com/hamkj7hpo/tiny-bip39.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/zk-elgamal-proof/zk-sdk/Cargo.toml..."
cd /tmp/deps/zk-elgamal-proof/zk-sdk
sed -i 's|base64 =.*|base64 = { git = "ssh://git@github.com/hamkj7hpo/rust-base64.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bytemuck =.*|bytemuck = { git = "ssh://git@github.com/hamkj7hpo/bytemuck.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bytemuck_derive =.*|bytemuck_derive = { git = "ssh://git@github.com/hamkj7hpo/bytemuck.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num-derive =.*|num-derive = { git = "ssh://git@github.com/hamkj7hpo/num-derive.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|num-traits =.*|num-traits = { git = "ssh://git@github.com/hamkj7hpo/num-traits.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-instruction =.*|solana-instruction = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", features = ["std"] }|' Cargo.toml
sed -i 's|solana-pubkey =.*|solana-pubkey = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", features = ["bytemuck"] }|' Cargo.toml
sed -i 's|solana-sdk-ids =.*|solana-sdk-ids = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|thiserror =.*|thiserror = { git = "ssh://git@github.com/hamkj7hpo/thiserror.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|aes-gcm-siv =.*|aes-gcm-siv = { git = "ssh://git@github.com/hamkj7hpo/AEADs.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bincode =.*|bincode = { git = "ssh://git@github.com/hamkj7hpo/bincode.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "ssh://git@github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["serde"] }|' Cargo.toml
sed -i 's|itertools =.*|itertools = { git = "ssh://git@github.com/hamkj7hpo/itertools.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|merlin =.*|merlin = { git = "ssh://git@github.com/hamkj7hpo/merlin.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|rand =.*|rand = { git = "ssh://git@github.com/hamkj7hpo/rand.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|serde =.*|serde = { git = "ssh://git@github.com/hamkj7hpo/serde.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|serde_derive =.*|serde_derive = { git = "ssh://git@github.com/hamkj7hpo/serde.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|serde_json =.*|serde_json = { git = "ssh://git@github.com/hamkj7hpo/json.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|sha3 =.*|sha3 = { git = "ssh://git@github.com/hamkj7hpo/hashes.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-derivation-path =.*|solana-derivation-path = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-seed-derivable =.*|solana-seed-derivable = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-seed-phrase =.*|solana-seed-phrase = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-signature =.*|solana-signature = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-signer =.*|solana-signer = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|subtle =.*|subtle = { git = "ssh://git@github.com/hamkj7hpo/subtle.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "ssh://git@github.com/hamkj7hpo/zeroize.git", branch = "safe-pump-compat", features = ["zeroize_derive"] }|' Cargo.toml
sed -i 's|getrandom =.*|getrandom = { git = "ssh://git@github.com/hamkj7hpo/getrandom.git", branch = "safe-pump-compat", features = ["js"] }|' Cargo.toml
sed -i 's|js-sys =.*|js-sys = { git = "ssh://git@github.com/hamkj7hpo/js-sys.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|wasm-bindgen =.*|wasm-bindgen = { git = "ssh://git@github.com/hamkj7hpo/wasm-bindgen.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-keypair =.*|solana-keypair = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|tiny-bip39 =.*|tiny-bip39 = { git = "ssh://git@github.com/hamkj7hpo/tiny-bip39.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/spl-pod/Cargo.toml..."
cd /tmp/deps/spl-pod
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "ssh://git@github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "ssh://git@github.com/hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/anchor/spl/Cargo.toml..."
cd /tmp/deps/anchor/spl
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/token-2022/Cargo.toml..."
cd /tmp/deps/token-2022
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "ssh://git@github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "ssh://git@github.com/hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/associated-token-account/Cargo.toml..."
cd /tmp/deps/associated-token-account
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|spl-token =.*|spl-token = { git = "ssh://git@github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|spl-discriminator =.*|spl-discriminator = { git = "ssh://git@github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|spl-program-error =.*|spl-program-error = { git = "ssh://git@github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/solana-program-library/libraries/discriminator/Cargo.toml..."
cd /tmp/deps/solana-program-library/libraries/discriminator
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/spl-type-length-value/Cargo.toml..."
cd /tmp/deps/spl-type-length-value
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|spl-pod =.*|spl-pod = { git = "ssh://git@github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/token-group/Cargo.toml..."
cd /tmp/deps/token-group
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|spl-pod =.*|spl-pod = { git = "ssh://git@github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/token-metadata/Cargo.toml..."
cd /tmp/deps/token-metadata
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|spl-pod =.*|spl-pod = { git = "ssh://git@github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/transfer-hook/Cargo.toml..."
cd /tmp/deps/transfer-hook
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/memo/Cargo.toml..."
cd /tmp/deps/memo
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch solana-program to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/raydium-cp-swap/Cargo.toml..."
cd /tmp/deps/raydium-cp-swap
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "ssh://git@github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "ssh://git@github.com/hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

echo "Patching /tmp/deps/raydium-cp-swap/programs/cp-swap/Cargo.toml..."
cd /tmp/deps/raydium-cp-swap/programs/cp-swap
sed -i 's|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "ssh://git@github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|zeroize =.*|zeroize = { git = "ssh://git@github.com/hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|spl-token-2022 =.*|spl-token-2022 = { git = "ssh://git@github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|spl-math =.*|spl-math = { git = "ssh://git@github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|arrayref =.*|arrayref = { git = "ssh://git@github.com/hamkj7hpo/arrayref.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bytemuck =.*|bytemuck = { git = "ssh://git@github.com/hamkj7hpo/bytemuck.git", branch = "safe-pump-compat", features = ["derive"] }|' Cargo.toml
sed -i 's|uint =.*|uint = { git = "ssh://git@github.com/hamkj7hpo/parity-common.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i 's|bincode =.*|bincode = { git = "ssh://git@github.com/hamkj7hpo/bincode.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Patch dependencies to safe-pump-compat with SSH URLs" || true
git push origin $branch || true

# Patch the main project's Cargo.toml
echo "Patching $project_dir/Cargo.toml..."
cd $project_dir
if ! grep -q "\[patch.crates-io\]" Cargo.toml
    echo -e "\n[patch.crates-io]" >> Cargo.toml
    echo 'curve25519-dalek = { git = "ssh://git@github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2" }' >> Cargo.toml
    echo 'solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-pod = { git = "ssh://git@github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat", default-features = false }' >> Cargo.toml
    echo 'solana-zk-sdk = { git = "ssh://git@github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-associated-token-account = { git = "ssh://git@github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-type-length-value = { git = "ssh://git@github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-memo = { git = "ssh://git@github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", version = "6.0.0" }' >> Cargo.toml
    echo 'spl-token-2022 = { git = "ssh://git@github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-transfer-hook-interface = { git = "ssh://git@github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-token-metadata-interface = { git = "ssh://git@github.com/hamkj7hpo/token-metadata.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-token-group-interface = { git = "ssh://git@github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'anchor-lang = { git = "ssh://git@github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'anchor-spl = { git = "ssh://git@github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'raydium-cp-swap = { git = "ssh://git@github.com/hamkj7hpo/raydium-cp-swap.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-instruction = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-pubkey = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-sdk-ids = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-derivation-path = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-seed-derivable = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-seed-phrase = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-signature = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-signer = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-keypair = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'base64 = { git = "ssh://git@github.com/hamkj7hpo/rust-base64.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'bincode = { git = "ssh://git@github.com/hamkj7hpo/bincode.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'bytemuck = { git = "ssh://git@github.com/hamkj7hpo/bytemuck.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'bytemuck_derive = { git = "ssh://git@github.com/hamkj7hpo/bytemuck.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'getrandom = { git = "ssh://git@github.com/hamkj7hpo/getrandom.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'itertools = { git = "ssh://git@github.com/hamkj7hpo/itertools.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'lazy_static = { git = "ssh://git@github.com/hamkj7hpo/lazy-static.rs.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'light-poseidon = { git = "ssh://git@github.com/hamkj7hpo/light-poseidon.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'num = { git = "ssh://git@github.com/hamkj7hpo/num.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'num-derive = { git = "ssh://git@github.com/hamkj7hpo/num-derive.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'num-traits = { git = "ssh://git@github.com/hamkj7hpo/num-traits.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'rand = { git = "ssh://git@github.com/hamkj7hpo/rand.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'serde = { git = "ssh://git@github.com/hamkj7hpo/serde.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'serde_derive = { git = "ssh://git@github.com/hamkj7hpo/serde.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'serde_json = { git = "ssh://git@github.com/hamkj7hpo/json.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'sha3 = { git = "ssh://git@github.com/hamkj7hpo/hashes.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'subtle = { git = "ssh://git@github.com/hamkj7hpo/subtle.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'thiserror = { git = "ssh://git@github.com/hamkj7hpo/thiserror.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'tiny-bip39 = { git = "ssh://git@github.com/hamkj7hpo/tiny-bip39.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'js-sys = { git = "ssh://git@github.com/hamkj7hpo/js-sys.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'wasm-bindgen = { git = "ssh://git@github.com/hamkj7hpo/wasm-bindgen.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'aes-gcm-siv = { git = "ssh://git@github.com/hamkj7hpo/AEADs.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-math = { git = "ssh://git@github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'arrayref = { git = "ssh://git@github.com/hamkj7hpo/arrayref.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'uint = { git = "ssh://git@github.com/hamkj7hpo/parity-common.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'merlin = { git = "ssh://git@github.com/hamkj7hpo/merlin.git", branch = "safe-pump-compat" }' >> Cargo.toml
else
    sed -i '/\[patch.crates-io\]/,/^\[/ s|curve25519-dalek =.*|curve25519-dalek = { git = "ssh://git@github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-pod =.*|spl-pod = { git = "ssh://git@github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat", default-features = false }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { git = "ssh://git@github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-associated-token-account =.*|spl-associated-token-account = { git = "ssh://git@github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-type-length-value =.*|spl-type-length-value = { git = "ssh://git@github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-memo =.*|spl-memo = { git = "ssh://git@github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", version = "6.0.0" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-token-2022 =.*|spl-token-2022 = { git = "ssh://git@github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-transfer-hook-interface =.*|spl-transfer-hook-interface = { git = "ssh://git@github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-token-metadata-interface =.*|spl-token-metadata-interface = { git = "ssh://git@github.com/hamkj7hpo/token-metadata.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-token-group-interface =.*|spl-token-group-interface = { git = "ssh://git@github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|anchor-lang =.*|anchor-lang = { git = "ssh://git@github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|anchor-spl =.*|anchor-spl = { git = "ssh://git@github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|raydium-cp-swap =.*|raydium-cp-swap = { git = "ssh://git@github.com/hamkj7hpo/raydium-cp-swap.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-instruction =.*|solana-instruction = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-pubkey =.*|solana-pubkey = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-sdk-ids =.*|solana-sdk-ids = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-derivation-path =.*|solana-derivation-path = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-seed-derivable =.*|solana-seed-derivable = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-seed-phrase =.*|solana-seed-phrase = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-signature =.*|solana-signature = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-signer =.*|solana-signer = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-keypair =.*|solana-keypair = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|base64 =.*|base64 = { git = "ssh://git@github.com/hamkj7hpo/rust-base64.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|bincode =.*|bincode = { git = "ssh://git@github.com/hamkj7hpo/bincode.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|bytemuck =.*|bytemuck = { git = "ssh://git@github.com/hamkj7hpo/bytemuck.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|bytemuck_derive =.*|bytemuck_derive = { git = "ssh://git@github.com/hamkj7hpo/bytemuck.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|getrandom =.*|getrandom = { git = "ssh://git@github.com/hamkj7hpo/getrandom.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|itertools =.*|itertools = { git = "ssh://git@github.com/hamkj7hpo/itertools.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|lazy_static =.*|lazy_static = { git = "ssh://git@github.com/hamkj7hpo/lazy-static.rs.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|light-poseidon =.*|light-poseidon = { git = "ssh://git@github.com/hamkj7hpo/light-poseidon.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|num =.*|num = { git = "ssh://git@github.com/hamkj7hpo/num.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|num-derive =.*|num-derive = { git = "ssh://git@github.com/hamkj7hpo/num-derive.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|num-traits =.*|num-traits = { git = "ssh://git@github.com/hamkj7hpo/num-traits.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|rand =.*|rand = { git = "ssh://git@github.com/hamkj7hpo/rand.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|serde =.*|serde = { git = "ssh://git@github.com/hamkj7hpo/serde.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|serde_derive =.*|serde_derive = { git = "ssh://git@github.com/hamkj7hpo/serde.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|serde_json =.*|serde_json = { git = "ssh://git@github.com/hamkj7hpo/json.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|sha3 =.*|sha3 = { git = "ssh://git@github.com/hamkj7hpo/hashes.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|subtle =.*|subtle = { git = "ssh://git@github.com/hamkj7hpo/subtle.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|thiserror =.*|thiserror = { git = "ssh://git@github.com/hamkj7hpo/thiserror.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|tiny-bip39 =.*|tiny-bip39 = { git = "ssh://git@github.com/hamkj7hpo/tiny-bip39.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|js-sys =.*|js-sys = { git = "ssh://git@github.com/hamkj7hpo/js-sys.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|wasm-bindgen =.*|wasm-bindgen = { git = "ssh://git@github.com/hamkj7hpo/wasm-bindgen.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|aes-gcm-siv =.*|aes-gcm-siv = { git = "ssh://git@github.com/hamkj7hpo/AEADs.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-math =.*|spl-math = { git = "ssh://git@github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|arrayref =.*|arrayref = { git = "ssh://git@github.com/hamkj7hpo/arrayref.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|uint =.*|uint = { git = "ssh://git@github.com/hamkj7hpo/parity-common.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|merlin =.*|merlin = { git = "ssh://git@github.com/hamkj7hpo/merlin.git", branch = "safe-pump-compat" }|' Cargo.toml
end

sed -i '/\[dependencies\]/,/^\[/ s|base64ct =.*|base64ct = { git = "ssh://git@github.com/hamkj7hpo/utils.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|bincode =.*|bincode = { git = "ssh://git@github.com/hamkj7hpo/bincode.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|bytemuck =.*|bytemuck = { git = "ssh://git@github.com/hamkj7hpo/bytemuck.git", branch = "safe-pump-compat", features = ["derive"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|zeroize =.*|zeroize = { git = "ssh://git@github.com/hamkj7hpo/zeroize.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|rand =.*|rand = { git = "ssh://git@github.com/hamkj7hpo/rand.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|sha3 =.*|sha3 = { git = "ssh://git@github.com/hamkj7hpo/hashes.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|merlin =.*|merlin = { git = "ssh://git@github.com/hamkj7hpo/merlin.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|curve25519-dalek =.*|curve25519-dalek = { git = "ssh://git@github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["serde"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-program =.*|solana-program = { git = "ssh://git@github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-pod =.*|spl-pod = { git = "ssh://git@github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-associated-token-account =.*|spl-associated-token-account = { git = "ssh://git@github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-tlv-account-resolution =.*|spl-tlv-account-resolution = { git = "ssh://git@github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-discriminator =.*|spl-discriminator = { git = "ssh://git@github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-2022 =.*|spl-token-2022 = { git = "ssh://git@github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat", package = "spl-token-2022", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-memo =.*|spl-memo = { git = "ssh://git@github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", package = "spl-memo", version = "6.0.0" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-transfer-hook-interface =.*|spl-transfer-hook-interface = { git = "ssh://git@github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat", package = "spl-transfer-hook-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-metadata-interface =.*|spl-token-metadata-interface = { git = "ssh://git@github.com/hamkj7hpo/token-metadata.git", branch = "safe-pump-compat", package = "spl-token-metadata-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-group-interface =.*|spl-token-group-interface = { git = "ssh://git@github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat", package = "spl-token-group-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|anchor-lang =.*|anchor-lang = { git = "ssh://git@github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", features = ["init-if-needed"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|anchor-spl =.*|anchor-spl = { git = "ssh://git@github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|raydium-cp-swap =.*|raydium-cp-swap = { git = "ssh://git@github.com/hamkj7hpo/raydium-cp-swap.git", branch = "safe-pump-compat", package = "raydium-cp-swap", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { git = "ssh://git@github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Update dependencies to safe-pump-compat with SSH URLs" || true
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
