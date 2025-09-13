#!/usr/bin/env fish

# Define hamkj7hpo repositories
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
    "utils" \
    "formats"

# Additional repositories with potential zeroize dependencies
set -l additional_repos \
    "aes-gcm-siv" \
    "merlin" \
    "tiny-bip39" \
    "arrayref" \
    "base64" \
    "bincode" \
    "borsh" \
    "bytemuck" \
    "bytemuck_derive" \
    "getrandom" \
    "itertools" \
    "lazy_static" \
    "num" \
    "num-derive" \
    "num-traits" \
    "rand" \
    "serde" \
    "serde_derive" \
    "serde_json" \
    "subtle" \
    "thiserror" \
    "wasm-bindgen"

set -l tmp_dir /tmp/deps
set -l project_dir /var/www/html/program/safe_pump
set -l branch safe-pump-compat
set -l github_user hamkj7hpo
set -l openbook_commit c85e56deeaead43abbc33b7301058838b9c5136d
set -l zeroize_fork https://github.com/$github_user/utils.git
set -l zeroize_branch safe-pump-compat

echo "setup.fish version 3.9"

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
    echo "Warning: SSH key not set up correctly for GitHub. Falling back to HTTPS for hamkj7hpo repos."
end

# Remove untracked files
cd $project_dir
if git status --porcelain | grep -q "setup.fish.save"
    echo "Removing untracked setup.fish.save files..."
    rm -f setup.fish.save*
end

# Commit any changes to setup.fish
if git status --porcelain | grep -q "setup.fish"
    echo "Committing changes to setup.fish..."
    git add setup.fish
    git commit -m "Update setup.fish to version 3.9 to fix curve25519-dalek zeroize dependency and submodule issues" || true
    git push origin $branch || true
end

# Create temporary directory for dependencies
mkdir -p $tmp_dir

# Process hamkj7hpo repositories
for repo in $hamkj_repos
    set -l repo_dir $tmp_dir/$repo
    set -l repo_url (test "$repo" = "curve25519-dalek" && echo "https://github.com/$github_user/curve25519-dalek.git" || echo "git@github.com:$github_user/$repo.git")
    set -l target_branch (test "$repo" = "curve25519-dalek" && echo "safe-pump-compat-v2" || test "$repo" = "formats" && echo "master" || echo $branch)

    echo "Processing $repo into $repo_dir..."
    echo "Verifying SSH access for $repo..."
    if test "$repo_url" = "git@github.com:$github_user/$repo.git"
        if not ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
            echo "Warning: SSH access to $repo may not be configured correctly. Using HTTPS..."
            set repo_url https://github.com/$github_user/$repo.git
        end
    end

    # Force re-clone for anchor, curve25519-dalek, zk-elgamal-proof, utils, and formats
    if test "$repo" = "anchor" -o "$repo" = "curve25519-dalek" -o "$repo" = "zk-elgamal-proof" -o "$repo" = "utils" -o "$repo" = "formats"
        echo "Removing existing $repo_dir to ensure clean clone..."
        rm -rf $repo_dir
    end

    if test -d $repo_dir
        echo "$repo_dir already exists, updating..."
        cd $repo_dir
        if not git remote get-url origin | grep -q "$repo_url"
            echo "Setting remote to $repo_url for $repo..."
            git remote set-url origin $repo_url
        end
        git fetch origin
        git reset --hard origin/$target_branch || git reset --hard origin/main || git reset --hard origin/master
        git clean -fd
    else
        echo "Cloning $repo into $repo_dir..."
        git clone $repo_url $repo_dir
    end

    cd $repo_dir
    set -l default_branch (git remote show origin | sed -n '/HEAD branch/s/.*: //p')
    git checkout $default_branch || git checkout main || git checkout master
    if git branch -r | grep -q " origin/$target_branch\$ "
        echo "Checking out $target_branch for $repo..."
        git checkout $target_branch
        git pull origin $target_branch --rebase || true
    else
        echo "Creating new branch $target_branch for $repo..."
        git checkout -b $target_branch
        # Skip pushing to avoid non-fast-forward issues for local development
    end

    # Fix and verify zeroize in utils fork
    if test "$repo" = "utils"
        if test -f zeroize/Cargo.toml
            if not grep -q 'version = "1.3.0"' zeroize/Cargo.toml
                echo "Fixing zeroize version to 1.3.0 in $repo_dir/zeroize/Cargo.toml..."
                sed -i 's/version = "[0-9.]*"/version = "1.3.0"/' zeroize/Cargo.toml
                git add zeroize/Cargo.toml
                git commit -m "Pin zeroize to version 1.3.0 on $target_branch (version 3.9)" || true
            end
        else
            echo "Error: zeroize/Cargo.toml not found in $repo_dir/zeroize."
            exit 1
        end
    end

    # Fix TOML syntax in curve25519-dalek sub-crates
    if test "$repo" = "curve25519-dalek"
        for subcrate in curve25519-dalek ed25519-dalek x25519-dalek
            if test -f $subcrate/Cargo.toml
                echo "Fixing TOML syntax in $repo_dir/$subcrate/Cargo.toml..."
                # Ensure zeroize dependency is present
                if not grep -q 'zeroize = {' $subcrate/Cargo.toml
                    echo "Adding zeroize dependency to $subcrate/Cargo.toml..."
                    sed -i '/\[dependencies\]/a zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0", optional = true }' $subcrate/Cargo.toml
                else
                    sed -i '/zeroize = {/d' $subcrate/Cargo.toml
                    sed -i '/\[dependencies\]/a zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0", optional = true }' $subcrate/Cargo.toml
                end
                # Fix feature definitions
                sed -i 's|zeroize?/alloc|zeroize/alloc|' $subcrate/Cargo.toml
                if ! grep -q 'std = \["alloc", "rand_core/std"\]' $subcrate/Cargo.toml
                    sed -i '/\[features\]/a std = ["alloc", "rand_core/std"]' $subcrate/Cargo.toml
                end
                git add $subcrate/Cargo.toml
                git commit -m "Fix zeroize dependency and features in $subcrate (version 3.9)" || true
            end
        end
    end

    # Patch solana-zk-sdk to use zeroize v1.3.0
    if test "$repo" = "zk-elgamal-proof"
        # Patch workspace Cargo.toml
        if test -f Cargo.toml
            echo "Patching $repo_dir/Cargo.toml for zeroize..."
            # Remove existing zeroize entries to avoid duplicates
            sed -i '/\[workspace.dependencies.zeroize\]/,/^\[/d' Cargo.toml
            # Ensure edition is set correctly
            if ! grep -q 'edition = "2021"' Cargo.toml
                sed -i '/\[workspace.package\]/a edition = "2021"' Cargo.toml
            end
            # Add zeroize dependency
            sed -i '/\[workspace.dependencies\]/a zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }' Cargo.toml
            git add Cargo.toml
            git commit -m "Pin zeroize to utils fork in zk-elgamal-proof workspace (version 3.9)" || true
        end
        # Patch solana-zk-sdk Cargo.toml
        for cargo_file in (find . -name Cargo.toml)
            if grep -q 'name = "solana-zk-sdk"' $cargo_file
                echo "Patching $cargo_file for zeroize..."
                sed -i '/\[dependencies.zeroize\]/,/^\[/d' $cargo_file
                sed -i 's|zeroize = { workspace = true, features = \["zeroize_derive"\] }|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
                sed -i 's|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", package = "zeroize".*}|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
                sed -i 's|zeroize = { version = "[0-9.]*".*}|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
                sed -i 's|zeroize = "^[0-9.]*"|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
                sed -i 's|zeroize = "[0-9.]*"|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
                git add $cargo_file
                git commit -m "Pin zeroize to utils fork in solana-zk-sdk (version 3.9)" || true
            end
        end
    end

    # Handle submodules for anchor repository
    if test "$repo" = "anchor"
        echo "Fixing submodules for anchor..."
        echo "Cleaning submodule state..."
        git submodule deinit -f --all 2>/dev/null || true
        if test -d .git/modules
            rm -rf .git/modules/*
        end
        rm -rf tests/cfo/deps examples/cfo/deps
        git rm -r --cached tests/cfo/deps 2>/dev/null || true

        echo "Creating/Updating .gitmodules for anchor submodules..."
        if test -f .gitmodules
            rm -f .gitmodules
        end
        echo "[submodule \"examples/cfo/deps/openbook-dex\"]" > .gitmodules
        echo "    path = examples/cfo/deps/openbook-dex" >> .gitmodules
        echo "    url = https://github.com/openbook-dex/program.git" >> .gitmodules
        echo "    branch = master" >> .gitmodules
        echo "[submodule \"examples/cfo/deps/stake\"]" >> .gitmodules
        echo "    path = examples/cfo/deps/stake" >> .gitmodules
        echo "    url = https://github.com/project-serum/stake.git" >> .gitmodules
        echo "    branch = master" >> .gitmodules
        echo "[submodule \"examples/cfo/deps/swap\"]" >> .gitmodules
        echo "    path = examples/cfo/deps/swap" >> .gitmodules
        echo "    url = https://github.com/project-serum/swap.git" >> .gitmodules
        echo "    branch = master" >> .gitmodules
        echo "[submodule \"examples/cfo/deps/serum-dex\"]" >> .gitmodules
        echo "    path = examples/cfo/deps/serum-dex" >> .gitmodules
        echo "    url = https://github.com/project-serum/serum-dex.git" >> .gitmodules
        echo "    branch = master" >> .gitmodules
        git add .gitmodules
        git commit -m "Configure submodules for openbook-dex, stake, swap, and serum-dex (version 3.9)" || true

        echo "Verifying SSH access for openbook-dex..."
        if not ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
            echo "Warning: Cannot access git@github.com:openbook-dex/program.git. Using HTTPS..."
            sed -i 's|url = git@github.com:openbook-dex/program.git|url = https://github.com/openbook-dex/program.git|' .gitmodules
            git add .gitmodules
            git commit -m "Switch openbook-dex submodule to HTTPS (version 3.9)" || true
        end

        echo "Checking for master branch in openbook-dex..."
        set -l branch_exists (git ls-remote --heads https://github.com/openbook-dex/program.git master | wc -l)
        if test $branch_exists -eq 0
            echo "Warning: master branch not found in openbook-dex/program. Using commit $openbook_commit..."
        end

        echo "Synchronizing and initializing submodules..."
        git submodule sync --recursive
        git submodule init
        mkdir -p examples/cfo/deps
        for submodule in openbook-dex stake swap serum-dex
            git submodule add -f https://github.com/project-serum/$submodule.git examples/cfo/deps/$submodule 2>/dev/null || true
            cd examples/cfo/deps/$submodule
            git checkout master || git checkout $openbook_commit
            cd $repo_dir
            git add examples/cfo/deps/$submodule
            git commit -m "Initialize $submodule submodule (version 3.9)" || true
        end
        git submodule update --init --recursive
    end
end

# Process additional repositories
for repo in $additional_repos
    set -l repo_dir $tmp_dir/$repo
    set -l repo_url (test "$repo" = "aes-gcm-siv" && echo "https://github.com/RustCrypto/AEADs.git" || \
                     test "$repo" = "merlin" && echo "https://github.com/dalek-cryptography/merlin.git" || \
                     test "$repo" = "tiny-bip39" && echo "https://github.com/maciejhirsz/tiny-bip39.git" || \
                     test "$repo" = "arrayref" && echo "https://github.com/droundy/arrayref.git" || \
                     test "$repo" = "base64" && echo "https://github.com/marshallpierce/rust-base64.git" || \
                     test "$repo" = "bincode" && echo "https://github.com/bincode-org/bincode.git" || \
                     test "$repo" = "borsh" && echo "https://github.com/near/borsh-rs.git" || \
                     test "$repo" = "bytemuck" && echo "https://github.com/Lokathor/bytemuck.git" || \
                     test "$repo" = "bytemuck_derive" && echo "https://github.com/Lokathor/bytemuck.git" || \
                     test "$repo" = "getrandom" && echo "https://github.com/rust-random/getrandom.git" || \
                     test "$repo" = "itertools" && echo "https://github.com/rust-itertools/itertools.git" || \
                     test "$repo" = "lazy_static" && echo "https://github.com/rust-lang-nursery/lazy-static.rs.git" || \
                     test "$repo" = "num" && echo "https://github.com/rust-num/num.git" || \
                     test "$repo" = "num-derive" && echo "https://github.com/rust-num/num-derive.git" || \
                     test "$repo" = "num-traits" && echo "https://github.com/rust-num/num-traits.git" || \
                     test "$repo" = "rand" && echo "https://github.com/rust-random/rand.git" || \
                     test "$repo" = "serde" && echo "https://github.com/serde-rs/serde.git" || \
                     test "$repo" = "serde_derive" && echo "https://github.com/serde-rs/serde.git" || \
                     test "$repo" = "serde_json" && echo "https://github.com/serde-rs/json.git" || \
                     test "$repo" = "subtle" && echo "https://github.com/dalek-cryptography/subtle.git" || \
                     test "$repo" = "thiserror" && echo "https://github.com/dtolnay/thiserror.git" || \
                     test "$repo" = "wasm-bindgen" && echo "https://github.com/rustwasm/wasm-bindgen.git")
    set -l target_branch (test "$repo" = "bytemuck" -o "$repo" = "bytemuck_derive" && echo "main" || echo "master")

    echo "Processing $repo into $repo_dir..."
    if test -d $repo_dir
        echo "$repo_dir already exists, updating..."
        cd $repo_dir
        git remote set-url origin $repo_url 2>/dev/null || git remote add origin $repo_url
        git fetch origin || echo "Fetch failed for $repo; continuing..."
        echo "Checking out $target_branch for $repo..."
        git reset --hard origin/$target_branch || git reset --hard origin/main || git reset --hard origin/master
        git clean -fd
        git checkout $target_branch || git checkout -b $target_branch origin/$target_branch || git checkout -b $target_branch
        git pull origin $target_branch --rebase || true
    else
        echo "Cloning $repo into $repo_dir..."
        git clone $repo_url $repo_dir
        cd $repo_dir
        git checkout $target_branch || git checkout -b $target_branch origin/$target_branch || git checkout -b $target_branch
    end
end

# Patch dependency Cargo.toml files
if test -d /tmp/deps/curve25519-dalek
    echo "Patching /tmp/deps/curve25519-dalek/curve25519-dalek/Cargo.toml..."
    cd /tmp/deps/curve25519-dalek
    for subcrate in curve25519-dalek ed25519-dalek x25519-dalek
        if test -f $subcrate/Cargo.toml
            echo "Patching /tmp/deps/curve25519-dalek/$subcrate/Cargo.toml for zeroize..."
            # Ensure zeroize dependency is present
            if not grep -q 'zeroize = {' $subcrate/Cargo.toml
                sed -i '/\[dependencies\]/a zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0", optional = true }' $subcrate/Cargo.toml
            else
                sed -i '/zeroize = {/d' $subcrate/Cargo.toml
                sed -i '/\[dependencies\]/a zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0", optional = true }' $subcrate/Cargo.toml
            end
            # Fix feature definitions
            sed -i 's|zeroize?/alloc|zeroize/alloc|' $subcrate/Cargo.toml
            if ! grep -q 'std = \["alloc", "rand_core/std"\]' $subcrate/Cargo.toml
                sed -i '/\[features\]/a std = ["alloc", "rand_core/std"]' $subcrate/Cargo.toml
            end
            git add $subcrate/Cargo.toml
            git commit -m "Pin zeroize to utils fork in $subcrate, ensure std feature (version 3.9)" || true
        end
    end
end

if test -d /tmp/deps/solana
    echo "Patching /tmp/deps/solana/Cargo.toml..."
    cd /tmp/deps/solana
    if not grep -q 'zeroize = {' Cargo.toml
        sed -i '/\[dependencies\]/a zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0", default-features = false }' Cargo.toml
    else
        sed -i '/zeroize = {/d' Cargo.toml
        sed -i '/\[dependencies\]/a zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0", default-features = false }' Cargo.toml
    end
    git add Cargo.toml
    git commit -m "Pin zeroize to utils fork in solana (version 3.9)" || true
end

# Patch other dependency Cargo.toml files
for repo in $hamkj_repos $additional_repos
    set -l repo_dir $tmp_dir/$repo
    if test -d $repo_dir
        cd $repo_dir
        for cargo_file in (find . -name Cargo.toml)
            echo "Patching $cargo_file for zeroize..."
            if grep -q 'zeroize = {' $cargo_file
                sed -i '/zeroize = {/d' $cargo_file
            end
            sed -i '/\[workspace.dependencies.zeroize\]/,/^\[/d' $cargo_file
            sed -i 's|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", package = "zeroize".*}|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
            sed -i 's|zeroize = { version = "[0-9.]*".*}|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
            sed -i 's|zeroize = "^[0-9.]*"|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
            sed -i 's|zeroize = "[0-9.]*"|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
            sed -i 's|zeroize = \["dep:zeroize"\]|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
            sed -i 's|zeroize = { workspace = true, features = \["zeroize_derive"\] }|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' $cargo_file
            git add $cargo_file
            git commit -m "Pin zeroize to utils fork in $repo (version 3.9)" || true
        end
    end
end

# Patch the main project's Cargo.toml
echo "Patching $project_dir/Cargo.toml..."
cd $project_dir
sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|anchor-lang =.*|anchor-lang = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", package = "anchor-lang", features = ["init-if-needed"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|anchor-spl =.*|anchor-spl = { path = "/tmp/deps/anchor/spl", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-2022 =.*|spl-token-2022 = { git = "https://github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat", package = "spl-token-2022", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-associated-token-account =.*|spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat", package = "spl-associated-token-account" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-discriminator =.*|spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat", package = "spl-discriminator" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-tlv-account-resolution =.*|spl-tlv-account-resolution = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat", package = "spl-tlv-account-resolution" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-group-interface =.*|spl-token-group-interface = { git = "https://github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat", package = "spl-token-group-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-token-metadata-interface =.*|spl-token-metadata-interface = { git = "https://github.com/hamkj7hpo/token-metadata.git", branch = "safe-pump-compat", package = "spl-token-metadata-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-transfer-hook-interface =.*|spl-transfer-hook-interface = { git = "https://github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat", package = "spl-transfer-hook-interface" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|spl-memo =.*|spl-memo = { git = "https://github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", package = "spl-memo", version = "6.0.0" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|raydium-cp-swap =.*|raydium-cp-swap = { git = "https://github.com/hamkj7hpo/raydium-cp-swap.git", branch = "safe-pump-compat", package = "raydium-cp-swap", default-features = false }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { path = "/tmp/deps/zk-elgamal-proof/zk-sdk", package = "solana-zk-sdk" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|curve25519-dalek =.*|curve25519-dalek = { path = "/tmp/deps/curve25519-dalek/curve25519-dalek", features = ["std", "serde"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|zeroize =.*|zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|wasm-bindgen =.*|wasm-bindgen = "=0.2.93"|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|js-sys =.*|js-sys = "=0.3.70"|' Cargo.toml
echo "Current solana-zk-sdk in $project_dir/Cargo.toml:"
grep 'solana-zk-sdk' Cargo.toml || echo "No solana-zk-sdk dependency found"
echo "Current curve25519-dalek in $project_dir/Cargo.toml:"
grep 'curve25519-dalek' Cargo.toml || echo "No curve25519-dalek dependency found"
git add Cargo.toml
git commit -m "Pin zeroize to utils fork, update dependencies to use local paths for curve25519-dalek and solana-zk-sdk (version 3.9)" || true
git push origin $branch || true

# Verify zeroize usage across all dependencies
echo "Verifying zeroize versions across all Cargo.toml files..."
grep -r 'zeroize =' $tmp_dir/*/Cargo.toml $tmp_dir/*/*/Cargo.toml $project_dir/Cargo.toml > /tmp/zeroize_versions.txt || true
if grep -v "zeroize = { git = \"$zeroize_fork\", branch = \"$zeroize_branch\", version = \"1.3.0\" }" /tmp/zeroize_versions.txt | grep -q 'zeroize ='
    echo "Warning: Found unexpected zeroize versions:"
    grep -v "zeroize = { git = \"$zeroize_fork\", branch = \"$zeroize_branch\", version = \"1.3.0\" }" /tmp/zeroize_versions.txt
    echo "Please review /tmp/zeroize_versions.txt for details."
end

# Clean and build the project
echo "Cleaning and building project..."
cd $project_dir
cargo clean
rm -f Cargo.lock
rm -rf ~/.cargo/registry/cache ~/.cargo/git
git config --global credential.helper 'cache --timeout=3600'
if cargo build --locked
    echo "Build successful!"
    if command -v cargo-tree >/dev/null
        echo "Generating dependency tree..."
        cargo tree > /tmp/safe_pump_dependency_tree.txt
        echo "Dependency tree saved to /tmp/safe_pump_dependency_tree.txt"
    else
        echo "cargo-tree not installed. Install with 'cargo install cargo-tree' to generate dependency tree."
    end
else
    echo "Build failed, check output for errors."
    echo "Generating diagnostic report..."
    cargo build --locked --verbose > /tmp/safe_pump_diagnostic_report.txt 2>&1
    echo "Diagnostic report saved to /tmp/safe_pump_diagnostic_report.txt"
    if command -v cargo-tree >/dev/null
        echo "Generating dependency tree for debugging..."
        cargo tree > /tmp/safe_pump_dependency_tree.txt
        echo "Dependency tree saved to /tmp/safe_pump_dependency_tree.txt"
    else
        echo "cargo-tree not installed. Install with 'cargo install cargo-tree' to generate dependency tree."
    end
    exit 1
end

echo "setup.fish version 3.9 completed"
