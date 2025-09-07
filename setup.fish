#!/usr/bin/env fish

# Define existing hamkj7hpo repositories
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
    "curve25519-dalek"

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

# Verify global SSH access to GitHub
echo "Verifying global SSH access to GitHub..."
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
    git commit -m "Update setup.fish to fix wasm-bindgen branch and spl-pod features" || true
    git push origin main || true
end

# Create temporary directory for dependencies
mkdir -p $tmp_dir

# Process existing hamkj7hpo repositories
for repo in $hamkj_repos
    set -l repo_dir $tmp_dir/$repo
    set -l repo_url git@github.com:$github_user/$repo.git
    set -l target_branch (test "$repo" = "curve25519-dalek" && echo "safe-pump-compat-v2" || echo $branch)

    echo "Processing $repo into $repo_dir..."
    # Verify SSH access for this specific repository
    echo "Verifying SSH access for $repo..."
    if not ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
        echo "Warning: SSH access to $repo may not be configured correctly. Attempting to proceed..."
    end

    if test -d $repo_dir
        echo "$repo_dir already exists, updating..."
        cd $repo_dir
        # Ensure remote is set to SSH
        if not git remote get-url origin | grep -q "git@github.com"
            echo "Setting remote to SSH for $repo..."
            git remote set-url origin $repo_url
        end
        git fetch origin
        # Check for uncommitted changes or detached HEAD
        set -l current_commit (git rev-parse HEAD)
        if git status --porcelain | grep -q .
            echo "Uncommitted changes in $repo, stashing..."
            git stash
        end
        echo "Checking out $target_branch for $repo..."
        if git show-ref --verify --quiet refs/remotes/origin/$target_branch
            git checkout $target_branch
            # Merge previous commit if not already included
            if not git merge-base --is-ancestor $current_commit $target_branch
                echo "Merging previous commit $current_commit into $target_branch..."
                git merge --no-ff $current_commit -m "Merge previous commit into $target_branch" || true
            end
            # Push any local commits (e.g., for curve25519-dalek)
            git push origin $target_branch || echo "Failed to push $target_branch for $repo, may need manual setup."
        else
            echo "Branch $target_branch does not exist, creating..."
            git checkout -b $target_branch
            git push origin $target_branch || echo "Failed to push $target_branch for $repo, may need manual setup."
        end
        git pull origin $target_branch || true
        # Update submodules to use SSH for hamkj7hpo repos, HTTPS for others
        if git config -f .gitmodules --get-regexp 'url.*hamkj7hpo' >/dev/null
            echo "Updating submodules to use SSH for hamkj7hpo repositories..."
            git config -f .gitmodules --get-regexp 'url.*hamkj7hpo' | while read -l line
                set -l submodule_url (echo $line | awk '{print $2}')
                set -l submodule_name (echo $line | awk '{print $1}' | sed 's/submodule\.//; s/\.url//')
                set -l ssh_url (echo $submodule_url | sed 's|https://github.com/|git@github.com:|')
                git config -f .gitmodules --replace-all "submodule.$submodule_name.url" $ssh_url
            end
            git submodule sync
            git submodule update --init --recursive || echo "Failed to update submodules for $repo, continuing..."
        end
    else
        echo "Cloning $repo into $repo_dir using SSH..."
        if git clone $repo_url $repo_dir
            cd $repo_dir
            if git show-ref --verify --quiet refs/remotes/origin/$target_branch
                git checkout $target_branch
            else
                git checkout -b $target_branch
                git push origin $target_branch || echo "Failed to push $target_branch for $repo, may need manual setup."
            end
            # Configure submodules for new clones
            if git config -f .gitmodules --get-regexp 'url.*hamkj7hpo' >/dev/null
                echo "Configuring submodules to use SSH for hamkj7hpo repositories..."
                git config -f .gitmodules --get-regexp 'url.*hamkj7hpo' | while read -l line
                    set -l submodule_url (echo $line | awk '{print $2}')
                    set -l submodule_name (echo $line | awk '{print $1}' | sed 's/submodule\.//; s/\.url//')
                    set -l ssh_url (echo $submodule_url | sed 's|https://github.com/|git@github.com:|')
                    git config -f .gitmodules --replace-all "submodule.$submodule_name.url" $ssh_url
                end
                git submodule sync
                git submodule update --init --recursive || echo "Failed to update submodules for $repo, continuing..."
            end
        else
            echo "Failed to clone $repo. Relying on patch.crates-io for $repo."
            continue
        end
    end
end

# Patch dependency Cargo.toml files to pin zeroize to 1.3.0
if test -d /tmp/deps/solana/sdk/program
    echo "Patching /tmp/deps/solana/sdk/program/Cargo.toml..."
    cd /tmp/deps/solana/sdk/program
    sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", default-features = false, features = ["std"] }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin zeroize to 1.3.0 and use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/zk-elgamal-proof
    echo "Patching /tmp/deps/zk-elgamal-proof/Cargo.toml..."
    cd /tmp/deps/zk-elgamal-proof
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["serde"] }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i 's|solana-sdk =.*|solana-sdk = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|aes-gcm-siv =.*|aes-gcm-siv = { git = "https://github.com/RustCrypto/AEADs.git", branch = "master" }|' Cargo.toml
    sed -i 's|base64 =.*|base64 = { git = "https://github.com/marshallpierce/rust-base64.git", branch = "master" }|' Cargo.toml
    sed -i 's|bincode =.*|bincode = "1.3.3"|' Cargo.toml
    sed -i 's|bytemuck =.*|bytemuck = { git = "https://github.com/Lokathor/bytemuck.git", branch = "main", features = ["derive"] }|' Cargo.toml
    sed -i 's|getrandom =.*|getrandom = { git = "https://github.com/rust-random/getrandom.git", branch = "master", features = ["custom"] }|' Cargo.toml
    sed -i 's|lazy_static =.*|lazy_static = { git = "https://github.com/rust-lang-nursery/lazy-static.rs.git", branch = "master" }|' Cargo.toml
    sed -i 's|light-poseidon =.*|light-poseidon = "0.3.0"|' Cargo.toml
    sed -i 's|num =.*|num = { git = "https://github.com/rust-num/num.git", branch = "master" }|' Cargo.toml
    sed -i 's|num-derive =.*|num-derive = { git = "https://github.com/rust-num/num-derive.git", branch = "master" }|' Cargo.toml
    sed -i 's|num-traits =.*|num-traits = { git = "https://github.com/rust-num/num-traits.git", branch = "master" }|' Cargo.toml
    sed -i 's|rand =.*|rand = { git = "https://github.com/rust-random/rand.git", branch = "master" }|' Cargo.toml
    sed -i 's|serde =.*|serde = { git = "https://github.com/serde-rs/serde.git", branch = "master" }|' Cargo.toml
    sed -i 's|sha3 =.*|sha3 = { git = "https://github.com/RustCrypto/hashes.git", branch = "master" }|' Cargo.toml
    sed -i 's|thiserror =.*|thiserror = { git = "https://github.com/dtolnay/thiserror.git", branch = "master" }|' Cargo.toml
    sed -i 's|tiny-bip39 =.*|tiny-bip39 = { git = "https://github.com/maciejhirsz/tiny-bip39.git", branch = "master" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin zeroize to 1.3.0 and use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/zk-elgamal-proof/zk-sdk
    echo "Patching /tmp/deps/zk-elgamal-proof/zk-sdk/Cargo.toml..."
    cd /tmp/deps/zk-elgamal-proof/zk-sdk
    sed -i 's|base64 =.*|base64 = { git = "https://github.com/marshallpierce/rust-base64.git", branch = "master" }|' Cargo.toml
    sed -i 's|bytemuck =.*|bytemuck = { git = "https://github.com/Lokathor/bytemuck.git", branch = "main" }|' Cargo.toml
    sed -i 's|bytemuck_derive =.*|bytemuck_derive = { git = "https://github.com/Lokathor/bytemuck.git", branch = "main" }|' Cargo.toml
    sed -i 's|num-derive =.*|num-derive = { git = "https://github.com/rust-num/num-derive.git", branch = "master" }|' Cargo.toml
    sed -i 's|num-traits =.*|num-traits = { git = "https://github.com/rust-num/num-traits.git", branch = "master" }|' Cargo.toml
    sed -i 's|thiserror =.*|thiserror = { git = "https://github.com/dtolnay/thiserror.git", branch = "master" }|' Cargo.toml
    sed -i 's|aes-gcm-siv =.*|aes-gcm-siv = { git = "https://github.com/RustCrypto/AEADs.git", branch = "master" }|' Cargo.toml
    sed -i 's|bincode =.*|bincode = "1.3.3"|' Cargo.toml
    sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["serde"] }|' Cargo.toml
    sed -i 's|itertools =.*|itertools = { git = "https://github.com/rust-itertools/itertools.git", branch = "master" }|' Cargo.toml
    sed -i 's|merlin =.*|merlin = { git = "https://github.com/dalek-cryptography/merlin.git", branch = "master" }|' Cargo.toml
    sed -i 's|rand =.*|rand = { git = "https://github.com/rust-random/rand.git", branch = "master" }|' Cargo.toml
    sed -i 's|serde =.*|serde = { git = "https://github.com/serde-rs/serde.git", branch = "master" }|' Cargo.toml
    sed -i 's|serde_derive =.*|serde_derive = { git = "https://github.com/serde-rs/serde.git", branch = "master" }|' Cargo.toml
    sed -i 's|serde_json =.*|serde_json = { git = "https://github.com/serde-rs/json.git", branch = "master" }|' Cargo.toml
    sed -i 's|sha3 =.*|sha3 = { git = "https://github.com/RustCrypto/hashes.git", branch = "master" }|' Cargo.toml
    sed -i 's|subtle =.*|subtle = { git = "https://github.com/dalek-cryptography/subtle.git", branch = "main" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i 's|js-sys =.*|js-sys = { git = "https://github.com/rustwasm/wasm-bindgen.git", package = "js-sys" }|' Cargo.toml
    sed -i 's|wasm-bindgen =.*|wasm-bindgen = { git = "https://github.com/rustwasm/wasm-bindgen.git", branch = "main" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin zeroize to 1.3.0 and use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/spl-pod
    echo "Patching /tmp/deps/spl-pod/Cargo.toml..."
    cd /tmp/deps/spl-pod
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin zeroize to 1.3.0 and use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/anchor/spl
    echo "Patching /tmp/deps/anchor/spl/Cargo.toml..."
    cd /tmp/deps/anchor/spl
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/token-2022
    echo "Patching /tmp/deps/token-2022/Cargo.toml..."
    cd /tmp/deps/token-2022
    sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin zeroize to 1.3.0 and use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/associated-token-account
    echo "Patching /tmp/deps/associated-token-account/Cargo.toml..."
    cd /tmp/deps/associated-token-account
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-token =.*|spl-token = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-discriminator =.*|spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-program-error =.*|spl-program-error = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/solana-program-library/libraries/discriminator
    echo "Patching /tmp/deps/solana-program-library/libraries/discriminator/Cargo.toml..."
    cd /tmp/deps/solana-program-library/libraries/discriminator
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/spl-type-length-value
    echo "Patching /tmp/deps/spl-type-length-value/Cargo.toml..."
    cd /tmp/deps/spl-type-length-value
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/token-group
    echo "Patching /tmp/deps/token-group/Cargo.toml..."
    cd /tmp/deps/token-group
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/token-metadata
    echo "Patching /tmp/deps/token-metadata/Cargo.toml..."
    cd /tmp/deps/token-metadata
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/transfer-hook
    echo "Patching /tmp/deps/transfer-hook/Cargo.toml..."
    cd /tmp/deps/transfer-hook
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/memo
    echo "Patching /tmp/deps/memo/Cargo.toml..."
    cd /tmp/deps/memo
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    git add Cargo.toml
    git commit -m "Use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/raydium-cp-swap
    echo "Patching /tmp/deps/raydium-cp-swap/Cargo.toml..."
    cd /tmp/deps/raydium-cp-swap
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin zeroize to 1.3.0 and use HTTPS URLs" || true
    git push origin $branch || true
end

if test -d /tmp/deps/raydium-cp-swap/programs/cp-swap
    echo "Patching /tmp/deps/raydium-cp-swap/programs/cp-swap/Cargo.toml..."
    cd /tmp/deps/raydium-cp-swap/programs/cp-swap
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i 's|spl-token-2022 =.*|spl-token-2022 = { git = "https://github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-math =.*|spl-math = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|arrayref =.*|arrayref = { git = "https://github.com/droundy/arrayref.git", branch = "master" }|' Cargo.toml
    sed -i 's|bytemuck =.*|bytemuck = { git = "https://github.com/Lokathor/bytemuck.git", branch = "main", features = ["derive"] }|' Cargo.toml
    sed -i 's|uint =.*|uint = { git = "https://github.com/paritytech/parity-common.git", branch = "master" }|' Cargo.toml
    sed -i 's|bincode =.*|bincode = "1.3.3"|' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin zeroize to 1.3.0 and use HTTPS URLs" || true
    git push origin $branch || true
end

# Patch the main project's Cargo.toml
echo "Patching $project_dir/Cargo.toml..."
cd $project_dir
if ! grep -q "\[patch.crates-io\]" Cargo.toml
    echo -e "\n[patch.crates-io]" >> Cargo.toml
    echo 'zeroize = "1.3.0"' >> Cargo.toml
    echo 'curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2" }' >> Cargo.toml
    echo 'solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-type-length-value = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-memo = { git = "https://github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", version = "6.0.0" }' >> Cargo.toml
    echo 'spl-token-2022 = { git = "https://github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-transfer-hook-interface = { git = "https://github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-token-metadata-interface = { git = "https://github.com/hamkj7hpo/token-metadata.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-token-group-interface = { git = "https://github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'anchor-lang = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'anchor-spl = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'raydium-cp-swap = { git = "https://github.com/hamkj7hpo/raydium-cp-swap.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'spl-math = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }' >> Cargo.toml
    echo 'arrayref = { git = "https://github.com/droundy/arrayref.git", branch = "master" }' >> Cargo.toml
    echo 'base64 = { git = "https://github.com/marshallpierce/rust-base64.git", branch = "master" }' >> Cargo.toml
    echo 'bincode = "1.3.3"' >> Cargo.toml
    echo 'bytemuck = { git = "https://github.com/Lokathor/bytemuck.git", branch = "main" }' >> Cargo.toml
    echo 'bytemuck_derive = { git = "https://github.com/Lokathor/bytemuck.git", branch = "main" }' >> Cargo.toml
    echo 'getrandom = { git = "https://github.com/rust-random/getrandom.git", branch = "master" }' >> Cargo.toml
    echo 'itertools = { git = "https://github.com/rust-itertools/itertools.git", branch = "master" }' >> Cargo.toml
    echo 'lazy_static = { git = "https://github.com/rust-lang-nursery/lazy-static.rs.git", branch = "master" }' >> Cargo.toml
    echo 'light-poseidon = "0.3.0"' >> Cargo.toml
    echo 'merlin = { git = "https://github.com/dalek-cryptography/merlin.git", branch = "master" }' >> Cargo.toml
    echo 'num = { git = "https://github.com/rust-num/num.git", branch = "master" }' >> Cargo.toml
    echo 'num-derive = { git = "https://github.com/rust-num/num-derive.git", branch = "master" }' >> Cargo.toml
    echo 'num-traits = { git = "https://github.com/rust-num/num-traits.git", branch = "master" }' >> Cargo.toml
    echo 'serde = { git = "https://github.com/serde-rs/serde.git", branch = "master" }' >> Cargo.toml
    echo 'serde_derive = { git = "https://github.com/serde-rs/serde.git", branch = "master" }' >> Cargo.toml
    echo 'serde_json = { git = "https://github.com/serde-rs/json.git", branch = "master" }' >> Cargo.toml
    echo 'sha3 = { git = "https://github.com/RustCrypto/hashes.git", branch = "master" }' >> Cargo.toml
    echo 'subtle = { git = "https://github.com/dalek-cryptography/subtle.git", branch = "main" }' >> Cargo.toml
    echo 'thiserror = { git = "https://github.com/dtolnay/thiserror.git", branch = "master" }' >> Cargo.toml
    echo 'tiny-bip39 = { git = "https://github.com/maciejhirsz/tiny-bip39.git", branch = "master" }' >> Cargo.toml
    echo 'uint = { git = "https://github.com/paritytech/parity-common.git", branch = "master" }' >> Cargo.toml
    echo 'wasm-bindgen = { git = "https://github.com/rustwasm/wasm-bindgen.git", branch = "main" }' >> Cargo.toml
    echo 'js-sys = { git = "https://github.com/rustwasm/wasm-bindgen.git", package = "js-sys" }' >> Cargo.toml
    echo 'aes-gcm-siv = { git = "https://github.com/RustCrypto/AEADs.git", branch = "master" }' >> Cargo.toml
else
    sed -i '/\[patch.crates-io\]/,/^\[/ s|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-associated-token-account =.*|spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-type-length-value =.*|spl-type-length-value = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-memo =.*|spl-memo = { git = "https://github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", version = "6.0.0" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-token-2022 =.*|spl-token-2022 = { git = "https://github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-transfer-hook-interface =.*|spl-transfer-hook-interface = { git = "https://github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-token-metadata-interface =.*|spl-token-metadata-interface = { git = "https://github.com/hamkj7hpo/token-metadata.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-token-group-interface =.*|spl-token-group-interface = { git = "https://github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|anchor-lang =.*|anchor-lang = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|anchor-spl =.*|anchor-spl = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|raydium-cp-swap =.*|raydium-cp-swap = { git = "https://github.com/hamkj7hpo/raydium-cp-swap.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|spl-math =.*|spl-math = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|arrayref =.*|arrayref = { git = "https://github.com/droundy/arrayref.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|base64 =.*|base64 = { git = "https://github.com/marshallpierce/rust-base64.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|bincode =.*|bincode = "1.3.3"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|bytemuck =.*|bytemuck = { git = "https://github.com/Lokathor/bytemuck.git", branch = "main" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|bytemuck_derive =.*|bytemuck_derive = { git = "https://github.com/Lokathor/bytemuck.git", branch = "main" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|getrandom =.*|getrandom = { git = "https://github.com/rust-random/getrandom.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|itertools =.*|itertools = { git = "https://github.com/rust-itertools/itertools.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|lazy_static =.*|lazy_static = { git = "https://github.com/rust-lang-nursery/lazy-static.rs.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|light-poseidon =.*|light-poseidon = "0.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|merlin =.*|merlin = { git = "https://github.com/dalek-cryptography/merlin.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|num =.*|num = { git = "https://github.com/rust-num/num.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|num-derive =.*|num-derive = { git = "https://github.com/rust-num/num-derive.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|num-traits =.*|num-traits = { git = "https://github.com/rust-num/num-traits.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|serde =.*|serde = { git = "https://github.com/serde-rs/serde.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|serde_derive =.*|serde_derive = { git = "https://github.com/serde-rs/serde.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|serde_json =.*|serde_json = { git = "https://github.com/serde-rs/json.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|sha3 =.*|sha3 = { git = "https://github.com/RustCrypto/hashes.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|subtle =.*|subtle = { git = "https://github.com/dalek-cryptography/subtle.git", branch = "main" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|thiserror =.*|thiserror = { git = "https://github.com/dtolnay/thiserror.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|tiny-bip39 =.*|tiny-bip39 = { git = "https://github.com/maciejhirsz/tiny-bip39.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|uint =.*|uint = { git = "https://github.com/paritytech/parity-common.git", branch = "master" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|wasm-bindgen =.*|wasm-bindgen = { git = "https://github.com/rustwasm/wasm-bindgen.git", branch = "main" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|js-sys =.*|js-sys = { git = "https://github.com/rustwasm/wasm-bindgen.git", package = "js-sys" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/ s|aes-gcm-siv =.*|aes-gcm-siv = { git = "https://github.com/RustCrypto/AEADs.git", branch = "master" }|' Cargo.toml
end

# Update dependencies section to pin zeroize and use HTTPS
sed -i '/\[dependencies\]/,/^\[/ s|base64ct =.*|base64ct = { git = "https://github.com/RustCrypto/utils.git", branch = "master" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|bincode =.*|bincode = "1.3.3"|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|bytemuck =.*|bytemuck = { git = "https://github.com/Lokathor/bytemuck.git", branch = "main", features = ["derive"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|rand =.*|rand = { git = "https://github.com/rust-random/rand.git", branch = "master" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|sha3 =.*|sha3 = { git = "https://github.com/RustCrypto/hashes.git", branch = "master" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|merlin =.*|merlin = { git = "https://github.com/dalek-cryptography/merlin.git", branch = "master" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["serde"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-associated-token-account =.*|spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-tlv-account-resolution =.*|spl-tlv-account-resolution = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-discriminator =.*|spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-2022 =.*|spl-token-2022 = { git = "https://github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat", package = "spl-token-2022", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-memo =.*|spl-memo = { git = "https://github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", package = "spl-memo", version = "6.0.0" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-transfer-hook-interface =.*|spl-transfer-hook-interface = { git = "https://github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat", package = "spl-transfer-hook-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-metadata-interface =.*|spl-token-metadata-interface = { git = "https://github.com/hamkj7hpo/token-metadata.git", branch = "safe-pump-compat", package = "spl-token-metadata-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-group-interface =.*|spl-token-group-interface = { git = "https://github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat", package = "spl-token-group-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|anchor-lang =.*|anchor-lang = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", features = ["init-if-needed"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|anchor-spl =.*|anchor-spl = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|raydium-cp-swap =.*|raydium-cp-swap = { git = "https://github.com/hamkj7hpo/raydium-cp-swap.git", branch = "safe-pump-compat", package = "raydium-cp-swap", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat" }|' Cargo.toml
git add Cargo.toml
git commit -m "Pin zeroize to 1.3.0, use HTTPS URLs, fix wasm-bindgen branch and spl-pod features" || true
git push origin main || true

# Clean and build the project
echo "Cleaning and building project..."
cd $project_dir
cargo clean
# Set up git credential helper to avoid HTTPS prompts for non-hamkj7hpo repos
git config --global credential.helper 'cache --timeout=3600'
if cargo build
    echo "Build successful!"
else
    echo "Build failed, check output for errors."
    echo "Generating diagnostic report..."
    cargo build --verbose > /tmp/safe_pump_diagnostic_report.txt 2>&1
    echo "Diagnostic report saved to /tmp/safe_pump_diagnostic_report.txt"
    exit 1
end
