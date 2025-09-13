#!/usr/bin/env fish

set -q use_https || set use_https false
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
    "utils"

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
set -l zeroize_fork ssh://git@github.com/$github_user/utils.git
set -l zeroize_branch safe-pump-compat

echo "setup.fish version 3.13"

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
    echo "Warning: SSH key not set up correctly for GitHub. Falling back to HTTPS..."
    set zeroize_fork https://github.com/$github_user/utils.git
    set -l use_https true
else
    set -l use_https false
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
    git commit -m "Update setup.fish to version 3.13 to fix duplicate zeroize, map/sequence errors, and add remote pushes" || true
    git push origin $branch || true
end

# Create temporary directory for dependencies
mkdir -p $tmp_dir

# Process hamkj7hpo repositories
for repo in $hamkj_repos
    set -l repo_dir $tmp_dir/$repo
    set -l repo_url (test $use_https = true && echo "https://github.com/$github_user/$repo.git" || echo "ssh://git@github.com/$github_user/$repo.git")
    set -l target_branch (test "$repo" = "curve25519-dalek" && echo "safe-pump-compat-v2" || echo $branch)

    echo "Processing $repo into $repo_dir..."
    echo "Verifying SSH access for $repo..."
    if test $use_https = false && not ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
        echo "Warning: SSH access to $repo failed. Using HTTPS for $repo..."
        set repo_url https://github.com/$github_user/$repo.git
    end

    # Force re-clone for anchor, curve25519-dalek, zk-elgamal-proof, utils
    if test "$repo" = "anchor" -o "$repo" = "curve25519-dalek" -o "$repo" = "zk-elgamal-proof" -o "$repo" = "utils"
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
    end

    # Fix and verify zeroize in utils fork
    if test "$repo" = "utils"
        if test -f zeroize/Cargo.toml
            if not grep -q 'version = "1.3.0"' zeroize/Cargo.toml
                echo "Fixing zeroize version to 1.3.0 in $repo_dir/zeroize/Cargo.toml..."
                sed -i 's/version = "[0-9.]*"/version = "1.3.0"/' zeroize/Cargo.toml
                git add zeroize/Cargo.toml
                git commit -m "Pin zeroize to version 1.3.0 on $target_branch (version 3.13)" || true
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
                # Remove any bad zeroize maps in [dependencies]
                sed -i '/\[dependencies\]/,/^$/ s/zeroize = {.*}//' $subcrate/Cargo.toml
                # Remove any bad zeroize arrays in [dependencies] (from previous bugs)
                sed -i '/\[dependencies\]/,/^$/ s/zeroize = \[.*\]//' $subcrate/Cargo.toml
                # Add the git map to [dependencies] if zeroize feature exists
                if grep -q 'zeroize = ' $subcrate/Cargo.toml
                    sed -i '/\[dependencies\]/a zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0", optional = true }' $subcrate/Cargo.toml
                end
                # Fix any maps in [features] to arrays
                sed -i '/\[features\]/,/^$/ s/zeroize = {.*}/zeroize = \["dep:zeroize", "curve25519-dalek\/zeroize"\]/' $subcrate/Cargo.toml
                # For curve25519-dalek subcrate specifically, adjust array (no self-ref)
                if test $subcrate = "curve25519-dalek"
                    sed -i '/\[features\]/,/^$/ s/zeroize = \[.*\]/zeroize = \["dep:zeroize"\]/' $subcrate/Cargo.toml
                else
                    sed -i '/\[features\]/,/^$/ s/zeroize = \[.*\]/zeroize = \["dep:zeroize", "curve25519-dalek\/zeroize"\]/' $subcrate/Cargo.toml
                end
                # Ensure std feature if missing
                if ! grep -q 'std = ' $subcrate/Cargo.toml
                    sed -i '/\[features\]/a std = ["alloc", "rand_core/std"]' $subcrate/Cargo.toml
                end
                git add $subcrate/Cargo.toml
                git commit -m "Fix zeroize dependency and features in $subcrate on safe-pump-compat-v2 (version 3.13)" || true
            end
        end
    end

    # Patch solana-zk-sdk and solana-program to use zeroize v1.3.0
    if test "$repo" = "zk-elgamal-proof"
        # Patch workspace Cargo.toml
        if test -f Cargo.toml
            echo "Patching $repo_dir/Cargo.toml for zeroize..."
            sed -i '/\[workspace.dependencies.zeroize\]/,/^\[/d' Cargo.toml
            if ! grep -q 'edition = "2021"' Cargo.toml
                sed -i '/\[workspace.package\]/a edition = "2021"' Cargo.toml
            end
            sed -i '/\[workspace.dependencies\]/a zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0" }' Cargo.toml
            git add Cargo.toml
            git commit -m "Pin zeroize to utils fork in zk-elgamal-proof workspace (version 3.13)" || true
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
                git commit -m "Pin zeroize to utils fork in solana-zk-sdk (version 3.13)" || true
            end
        end
    end

    # Patch solana-program in solana and other repos
    if test "$repo" = "solana" -o "$repo" = "spl-type-length-value" -o "$repo" = "solana-program-library"
        for cargo_file in (find . -name Cargo.toml)
            if grep -q 'solana-program =' $cargo_file
                echo "Patching $cargo_file for solana-program..."
                sed -i 's|solana-program = { git = "https://github.com/solana-labs/solana.git".*}|solana-program = { git = "'$repo_url'", branch = "'$branch'" }|' $cargo_file
                git add $cargo_file
                git commit -m "Pin solana-program to hamkj7hpo fork in $repo (version 3.13)" || true
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
        echo "    url = ssh://git@github.com/openbook-dex/program.git" >> .gitmodules
        echo "    branch = master" >> .gitmodules
        echo "[submodule \"examples/cfo/deps/stake\"]" >> .gitmodules
        echo "    path = examples/cfo/deps/stake" >> .gitmodules
        echo "    url = ssh://git@github.com/project-serum/stake.git" >> .gitmodules
        echo "    branch = master" >> .gitmodules
        echo "[submodule \"examples/cfo/deps/swap\"]" >> .gitmodules
        echo "    path = examples/cfo/deps/swap" >> .gitmodules
        echo "    url = ssh://git@github.com/project-serum/swap.git" >> .gitmodules
        echo "    branch = master" >> .gitmodules
        echo "[submodule \"examples/cfo/deps/serum-dex\"]" >> .gitmodules
        echo "    path = examples/cfo/deps/serum-dex" >> .gitmodules
        echo "    url = ssh://git@github.com/project-serum/serum-dex.git" >> .gitmodules
        echo "    branch = master" >> .gitmodules
        git add .gitmodules
        git commit -m "Configure submodules for openbook-dex, stake, swap, and serum-dex (version 3.13)" || true

        echo "Verifying SSH access for submodules..."
        for submodule in openbook-dex stake swap serum-dex
            if test $use_https = true || not ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
                echo "Warning: Cannot access ssh://git@github.com/project-serum/$submodule.git. Using HTTPS..."
                sed -i "s|url = ssh://git@github.com/project-serum/$submodule.git|url = https://github.com/project-serum/$submodule.git|" .gitmodules
                sed -i "s|url = ssh://git@github.com/openbook-dex/program.git|url = https://github.com/openbook-dex/program.git|" .gitmodules
                git add .gitmodules
                git commit -m "Switch $submodule submodule to HTTPS (version 3.13)" || true
            end
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
            set -l submodule_url (grep "url = " .gitmodules | grep "$submodule" | cut -d'=' -f2 | tr -d ' ')
            git submodule add -f $submodule_url examples/cfo/deps/$submodule 2>/dev/null || true
            cd examples/cfo/deps/$submodule
            git checkout master || git checkout $openbook_commit
            # Patch submodule Cargo.toml files
            for cargo_file in (find . -name Cargo.toml)
                echo "Patching $cargo_file in $submodule for zeroize..."
                sed -i '/\[dependencies\]/,/^$/ s/zeroize = {.*}/zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0", optional = true }/' $cargo_file
                sed -i '/\[dependencies\]/,/^$/ s/zeroize = "\[0-9.]*"/zeroize = { git = "'$zeroize_fork'", branch = "'$zeroize_branch'", version = "1.3.0", optional = true }/' $cargo_file
                sed -i '/\[features\]/,/^$/ s/zeroize = {.*}/zeroize = \["dep:zeroize"\]/' $cargo_file
                git add $cargo_file
                git commit -m "Pin zeroize to utils fork in $submodule (version 3.13)" || true
                # No push for non-fork submodules
            end
            cd $repo_dir
            git add examples/cfo/deps/$submodule
            git commit -m "Initialize $submodule submodule (version 3.13)" || true
        end
        git submodule update --init --recursive
    end

    # Push changes to remote fork
    git push origin $target_branch || true
end

# Process additional repositories (no push, as these are not forks)
for repo in $additional_repos
    # ... (keep the existing code for cloning/updating, but no push)
end

# Patch dependency Cargo.toml files (keep existing, but since pushes are now done, remotes are fixed)

# Patch the main project's Cargo.toml (keep existing)

# Verify zeroize usage across all dependencies (update to ignore features arrays)
echo "Verifying zeroize versions across all Cargo.toml files..."
grep -r 'zeroize = {' $tmp_dir/*/Cargo.toml $tmp_dir/*/*/Cargo.toml $project_dir/Cargo.toml > /tmp/zeroize_versions.txt || true
if grep -v "zeroize = { git = \"$zeroize_fork\", branch = \"$zeroize_branch\", version = \"1.3.0\"" /tmp/zeroize_versions.txt | grep -q 'zeroize = {'
    echo "Warning: Found unexpected zeroize dependency versions (ignoring features):"
    grep -v "zeroize = { git = \"$zeroize_fork\", branch = \"$zeroize_branch\", version = \"1.3.0\"" /tmp/zeroize_versions.txt
    echo "Please review /tmp/zeroize_versions.txt for details."
end

# Clean and build the project (keep existing)

echo "setup.fish version 3.13 completed"
