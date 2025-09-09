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
set -l openbook_commit c85e56deeaead43abbc33b7301058838b9c5136d

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
    git commit -m "Update setup.fish to fix js-sys patch conflict, wasm-bindgen-shared conflict, submodule issues, curve25519-dalek, and getrandom dependencies" || true
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
    echo "Verifying SSH access for $repo..."
    if not ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
        echo "Warning: SSH access to $repo may not be configured correctly. Attempting to proceed..."
    end

    # Force re-clone for anchor and curve25519-dalek to ensure clean state
    if test "$repo" = "anchor" -o "$repo" = "curve25519-dalek"
        echo "Removing existing $repo_dir to ensure clean clone..."
        rm -rf $repo_dir
    end

    if test -d $repo_dir
        echo "$repo_dir already exists, updating..."
        cd $repo_dir
        if not git remote get-url origin | grep -q "git@github.com"
            echo "Setting remote to SSH for $repo..."
            git remote set-url origin $repo_url
        end
        git fetch origin
        echo "Checking out $target_branch for $repo..."
        git checkout $target_branch || git checkout -b $target_branch
        git pull origin $target_branch || true
    else
        echo "Cloning $repo into $repo_dir using SSH..."
        git clone $repo_url $repo_dir
        cd $repo_dir
        git checkout $target_branch || git checkout -b $target_branch
        git push origin $target_branch --set-upstream || true
    end

    # Handle submodules for anchor repository
    if test "$repo" = "anchor"
        echo "Fixing submodules for anchor..."
        # Clean stale submodule state
        echo "Cleaning submodule state..."
        git submodule deinit -f --all 2>/dev/null || true
        if test -d .git/modules
            rm -rf .git/modules/*
        end
        rm -rf tests/cfo/deps examples/cfo/deps
        git rm -r --cached tests/cfo/deps 2>/dev/null || true

        # Create or update .gitmodules
        echo "Creating/Updating .gitmodules for openbook-dex..."
        if test -f .gitmodules
            sed -i '/\[submodule.*\]/,/^\[/d' .gitmodules
        end
        echo "[submodule \"examples/cfo/deps/openbook-dex\"]" > .gitmodules
        echo "    path = examples/cfo/deps/openbook-dex" >> .gitmodules
        echo "    url = git@github.com:openbook-dex/program.git" >> .gitmodules
        echo "    branch = safe-pump-compat" >> .gitmodules
        git add .gitmodules
        git commit -m "Configure openbook-dex submodule at examples/cfo/deps/openbook-dex" || true
        git push origin $target_branch || true

        # Verify SSH access for openbook-dex
        echo "Verifying SSH access for openbook-dex..."
        if not ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
            echo "Error: Cannot access git@github.com:openbook-dex/program.git. Check SSH key permissions."
            exit 1
        end

        # Check if safe-pump-compat branch exists
        echo "Checking for safe-pump-compat branch in openbook-dex..."
        set -l branch_exists (git ls-remote --heads git@github.com:openbook-dex/program.git safe-pump-compat | wc -l)
        if test $branch_exists -eq 0
            echo "Warning: safe-pump-compat branch not found in openbook-dex/program. Using commit $openbook_commit..."
        end

        # Synchronize and initialize submodules
        echo "Synchronizing and initializing submodules..."
        git submodule sync --recursive
        git submodule init
        mkdir -p examples/cfo/deps
        git submodule add -f git@github.com:openbook-dex/program.git examples/cfo/deps/openbook-dex 2>/dev/null || true
        if not git submodule update --init --recursive examples/cfo/deps/openbook-dex
            echo "Failed to initialize openbook-dex submodule, attempting manual clone..."
            rm -rf examples/cfo/deps/openbook-dex
            cd examples/cfo/deps
            git clone git@github.com:openbook-dex/program.git openbook-dex
            cd openbook-dex
            git checkout $openbook_commit
            cd $repo_dir
            git add examples/cfo/deps/openbook-dex
            git commit -m "Manually initialize openbook-dex submodule at commit $openbook_commit" || true
            git push origin $target_branch || true
        end

        # Fix openbook-dex submodule to valid commit
        if test -d examples/cfo/deps/openbook-dex
            cd examples/cfo/deps/openbook-dex
            echo "Fixing openbook-dex submodule to valid commit..."
            git fetch origin
            git checkout $openbook_commit
            cd $repo_dir
            git add examples/cfo/deps/openbook-dex
            git commit -m "Pin openbook-dex submodule to commit $openbook_commit" || true
            git push origin $target_branch || true
        else
            echo "Error: openbook-dex submodule not found at examples/cfo/deps/openbook-dex after initialization"
            exit 1
        end
    end

    # Verify anchor-spl package for anchor repository
    if test "$repo" = "anchor"
        if test -f spl/Cargo.toml
            echo "Verifying anchor-spl package in $repo_dir/spl/Cargo.toml..."
            if grep -q 'name = "anchor-spl"' spl/Cargo.toml
                echo "anchor-spl package found in $repo_dir/spl/Cargo.toml."
            else
                echo "Error: anchor-spl package not found in $repo_dir/spl/Cargo.toml."
                exit 1
            end
        else
            echo "Error: spl/Cargo.toml not found in $repo_dir."
            exit 1
        end
    end
end

# Patch dependency Cargo.toml files
if test -d /tmp/deps/curve25519-dalek
    echo "Patching /tmp/deps/curve25519-dalek/Cargo.toml to ensure valid workspace manifest..."
    cd /tmp/deps/curve25519-dalek
    sed -i '/\[features\]/,/^\[/{d}' Cargo.toml
    git add Cargo.toml
    git commit -m "Remove invalid [features] section from workspace Cargo.toml" || true
    git push origin safe-pump-compat-v2 || true
    if ! grep -q 'std = \["alloc", "rand_core/std"\]' curve25519-dalek/Cargo.toml
        echo "Adding std feature to curve25519-dalek/Cargo.toml..."
        sed -i '/\[features\]/a std = ["alloc", "rand_core/std"]' curve25519-dalek/Cargo.toml
        git add curve25519-dalek/Cargo.toml
        git commit -m "Ensure std feature in curve25519-dalek for safe-pump compatibility" || true
        git push origin safe-pump-compat-v2 || true
    end
end

if test -d /tmp/deps/solana/sdk/program
    echo "Patching /tmp/deps/solana/sdk/program/Cargo.toml..."
    cd /tmp/deps/solana/sdk/program
    sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["std"] }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i 's|getrandom =.*|getrandom = { version = "0.2.15", features = ["custom"] }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin curve25519-dalek to fork with std feature, zeroize to 1.3.0, getrandom to 0.2.15 with custom feature, remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/zk-elgamal-proof
    echo "Patching /tmp/deps/zk-elgamal-proof/Cargo.toml..."
    cd /tmp/deps/zk-elgamal-proof
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["std", "serde"] }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i 's|getrandom =.*|getrandom = { version = "0.2.15", features = ["custom"] }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/zk-elgamal-proof/zk-sdk
    echo "Patching /tmp/deps/zk-elgamal-proof/zk-sdk/Cargo.toml..."
    cd /tmp/deps/zk-elgamal-proof/zk-sdk
    sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["std", "serde"] }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i 's|getrandom =.*|getrandom = { version = "0.2.15", features = ["custom"] }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/spl-pod
    echo "Patching /tmp/deps/spl-pod/Cargo.toml..."
    cd /tmp/deps/spl-pod
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat", package = "solana-zk-sdk" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/anchor/spl
    echo "Patching /tmp/deps/anchor/spl/Cargo.toml..."
    cd /tmp/deps/anchor/spl
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|openbook-dex =.*|openbook-dex = { git = "https://github.com/openbook-dex/program.git", rev = "c85e56deeaead43abbc33b7301058838b9c5136d", optional = true, features = ["no-entrypoint"] }|' Cargo.toml
    sed -i '/spl-token-2022 =/d' Cargo.toml
    sed -i '/\[dependencies\]/a spl-token-2022 = { git = "https://github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat", package = "spl-token-2022", optional = true }' Cargo.toml
    sed -i '/spl-associated-token-account =/d' Cargo.toml
    sed -i '/\[dependencies\]/a spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat", package = "spl-associated-token-account", optional = true }' Cargo.toml
    sed -i '/spl-token-group-interface =/d' Cargo.toml
    sed -i '/\[dependencies\]/a spl-token-group-interface = { git = "https://github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat", package = "spl-token-group-interface", optional = true }' Cargo.toml
    sed -i '/spl-transfer-hook-interface =/d' Cargo.toml
    sed -i '/\[dependencies\]/a spl-transfer-hook-interface = { git = "https://github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat", package = "spl-transfer-hook-interface", optional = true }' Cargo.toml
    sed -i '/spl-memo =/d' Cargo.toml
    sed -i '/\[dependencies\]/a spl-memo = { git = "https://github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", package = "spl-memo", version = "6.0.0", optional = true }' Cargo.toml
    sed -i 's|anchor-lang =.*|anchor-lang = { path = "../lang", version = "0.31.1" }|' Cargo.toml
    sed -i 's|default = \["token", "associated-token", "dex"\]|default = ["token", "associated-token"]|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Fix optional dependencies, pin openbook-dex to valid commit, disable dex feature, remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/anchor/examples/cfo/deps/openbook-dex/dex
    echo "Patching /tmp/deps/anchor/examples/cfo/deps/openbook-dex/dex/Cargo.toml..."
    cd /tmp/deps/anchor/examples/cfo/deps/openbook-dex/dex
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-token =.*|spl-token = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat", package = "spl-token", features = ["no-entrypoint"] }|' Cargo.toml
    sed -i 's|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["std"] }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    # Skip pushing to openbook-dex due to permission issues
end

if test -d /tmp/deps/token-2022/program
    echo "Patching /tmp/deps/token-2022/program/Cargo.toml..."
    cd /tmp/deps/token-2022/program
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-discriminator =.*|spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat", package = "spl-discriminator" }|' Cargo.toml
    sed -i 's|spl-memo =.*|spl-memo = { git = "https://github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", package = "spl-memo", version = "6.0.0" }|' Cargo.toml
    sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat", default-features = false }|' Cargo.toml
    sed -i 's|spl-token-group-interface =.*|spl-token-group-interface = { git = "https://github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat", package = "spl-token-group-interface" }|' Cargo.toml
    sed -i 's|spl-token-metadata-interface =.*|spl-token-metadata-interface = { git = "https://github.com/hamkj7hpo/token-metadata.git", branch = "safe-pump-compat", package = "spl-token-metadata-interface" }|' Cargo.toml
    sed -i 's|spl-transfer-hook-interface =.*|spl-transfer-hook-interface = { git = "https://github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat", package = "spl-transfer-hook-interface" }|' Cargo.toml
    sed -i 's|spl-type-length-value =.*|spl-type-length-value = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat", package = "spl-type-length-value" }|' Cargo.toml
    sed -i 's|spl-tlv-account-resolution =.*|spl-tlv-account-resolution = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat", package = "spl-tlv-account-resolution" }|' Cargo.toml
    sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat", package = "solana-zk-sdk" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/associated-token-account/program
    echo "Patching /tmp/deps/associated-token-account/program/Cargo.toml..."
    cd /tmp/deps/associated-token-account/program
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-token =.*|spl-token = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat", package = "spl-token", features = ["no-entrypoint"] }|' Cargo.toml
    sed -i 's|spl-discriminator =.*|spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat", package = "spl-discriminator" }|' Cargo.toml
    sed -i 's|spl-program-error =.*|spl-program-error = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat", package = "spl-program-error" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/solana-program-library
    echo "Patching /tmp/deps/solana-program-library/Cargo.toml..."
    cd /tmp/deps/solana-program-library
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/solana-program-library/libraries/discriminator
    echo "Patching /tmp/deps/solana-program-library/libraries/discriminator/Cargo.toml..."
    cd /tmp/deps/solana-program-library/libraries/discriminator
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/spl-type-length-value
    echo "Patching /tmp/deps/spl-type-length-value/Cargo.toml..."
    cd /tmp/deps/spl-type-length-value
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/token-group
    echo "Patching /tmp/deps/token-group/Cargo.toml..."
    cd /tmp/deps/token-group
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-discriminator =.*|spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat", package = "spl-discriminator" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/token-metadata
    echo "Patching /tmp/deps/token-metadata/Cargo.toml..."
    cd /tmp/deps/token-metadata
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|spl-pod =.*|spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/transfer-hook
    echo "Patching /tmp/deps/transfer-hook/Cargo.toml..."
    cd /tmp/deps/transfer-hook
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/memo
    echo "Patching /tmp/deps/memo/Cargo.toml..."
    cd /tmp/deps/memo
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/raydium-cp-swap
    echo "Patching /tmp/deps/raydium-cp-swap/Cargo.toml..."
    cd /tmp/deps/raydium-cp-swap
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat", package = "solana-zk-sdk" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
end

if test -d /tmp/deps/raydium-cp-swap/programs/cp-swap
    echo "Patching /tmp/deps/raydium-cp-swap/programs/cp-swap/Cargo.toml..."
    cd /tmp/deps/raydium-cp-swap/programs/cp-swap
    sed -i 's|solana-program =.*|solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }|' Cargo.toml
    sed -i 's|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat", package = "solana-zk-sdk" }|' Cargo.toml
    sed -i 's|spl-token-2022 =.*|spl-token-2022 = { git = "https://github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat", package = "spl-token-2022" }|' Cargo.toml
    sed -i 's|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
    git add Cargo.toml
    git commit -m "Pin dependencies and remove patch.crates-io" || true
    git push origin $branch || true
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
sed -i '/\[dependencies\]/,/^\[/ s|solana-zk-sdk =.*|solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat", package = "solana-zk-sdk" }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|curve25519-dalek =.*|curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["std", "serde"] }|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|zeroize =.*|zeroize = "1.3.0"|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|wasm-bindgen =.*|wasm-bindgen = "0.2.93"|' Cargo.toml
sed -i '/\[dependencies\]/,/^\[/ s|js-sys =.*|js-sys = "0.3.70"|' Cargo.toml
sed -i '/\[patch.crates-io\]/,/^\[/d' Cargo.toml
echo -e "\n[patch.crates-io]\nwasm-bindgen = { version = \"=0.2.93\" }\njs-sys = { version = \"=0.3.70\" }" >> Cargo.toml
git add Cargo.toml
git commit -m "Pin wasm-bindgen and js-sys to exact versions, remove conflicting patch.crates-io" || true
git push origin main || true

# Clean and build the project
echo "Cleaning and building project..."
cd $project_dir
cargo clean
rm -f Cargo.lock
rm -rf ~/.cargo/registry/cache ~/.cargo/git
git config --global credential.helper 'cache --timeout=3600'
if cargo build
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
    cargo build --verbose > /tmp/safe_pump_diagnostic_report.txt 2>&1
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

# setup.fish version 2.2
