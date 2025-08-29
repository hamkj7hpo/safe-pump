#!/usr/bin/env fish

set -l repos \
    "anchor" \
    "solana" \
    "associated-token-account" \
    "solana-program-library" \
    "memo" \
    "spl-pod" \
    "token-2022" \
    "spl-type-length-value" \
    "raydium-cp-swap" \
    "zk-elgamal-proof" \
    "token-group" \
    "token-metadata" \
    "transfer-hook"

set -l tmp_dir /tmp
set -l project_dir /var/www/html/program/safe_pump
set -l branch safe-pump-compat

# Ensure git is configured for pushing
echo "Checking git configuration..."
if not git config user.name >/dev/null || not git config user.email >/dev/null
    echo "Git user.name or user.email not set. Please configure git:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
    exit 1
end

# Step 1: Clone repositories and ensure safe-pump-compat branch
for repo in $repos
    set -l repo_url https://github.com/hamkj7hpo/$repo.git
    set -l target_dir $tmp_dir/$repo
    echo "Processing $repo into $target_dir..."

    # Clone if not exists
    if test -d $target_dir
        echo "$target_dir already exists, updating..."
        cd $target_dir
        git fetch origin
    else
        echo "Cloning $repo_url..."
        git clone $repo_url $target_dir
        if test $status -ne 0
            echo "Failed to clone $repo_url"
            exit 1
        end
        cd $target_dir
    end

    # Check for safe-pump-compat branch
    if git rev-parse --verify origin/$branch >/dev/null 2>&1
        echo "Checking out existing $branch for $repo..."
        git checkout $branch
        git pull origin $branch
    else
        echo "Creating new $branch for $repo..."
        git checkout -b $branch
        git push origin $branch
        if test $status -ne 0
            echo "Failed to push $branch to $repo_url"
            exit 1
        end
    end
    cd -
end

# Step 2: Find and patch solana-program-library Cargo.toml for spl-token
set -l spl_dir $tmp_dir/solana-program-library
set -l spl_token_toml ""
if test -f $spl_dir/token/program/Cargo.toml
    set spl_token_toml $spl_dir/token/program/Cargo.toml
else if test -f $spl_dir/token/Cargo.toml
    set spl_token_toml $spl_dir/token/Cargo.toml
else
    echo "Error: Could not find spl-token Cargo.toml in $spl_dir/token/program or $spl_dir/token"
    exit 1
end
echo "Found spl-token Cargo.toml at $spl_token_toml"

# Add no-entrypoint feature
echo "Patching $spl_token_toml for no-entrypoint feature..."
if not grep -q 'no-entrypoint =' $spl_token_toml
    echo "Adding no-entrypoint feature..."
    if not grep -q "\[features\]" $spl_token_toml
        echo -e "\n[features]\nno-entrypoint = []" >> $spl_token_toml
    else
        sed -i '/\[features\]/a no-entrypoint = []' $spl_token_toml
    end
    # Commit and push changes
    cd $spl_dir
    git add token/Cargo.toml
    git commit -m "Add no-entrypoint feature to spl-token" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to solana-program-library"
        exit 1
    end
    cd -
else
    echo "no-entrypoint feature already present in $spl_token_toml"
end

# Step 3: Patch anchor/spl/Cargo.toml
set -l anchor_spl_toml $tmp_dir/anchor/spl/Cargo.toml
if test -f $anchor_spl_toml
    echo "Patching $anchor_spl_toml to add no-entrypoint feature for spl-token..."
    if not grep -q 'spl-token =.*no-entrypoint' $anchor_spl_toml
        set -l current_line (grep 'spl-token =' $anchor_spl_toml)
        if test -n "$current_line"
            sed -i "s|$current_line|spl-token = { git = \"https://github.com/hamkj7hpo/solana-program-library.git\", branch = \"$branch\", package = \"spl-token\", features = [\"no-entrypoint\"] }|" $anchor_spl_toml
        else
            echo "spl-token = { git = \"https://github.com/hamkj7hpo/solana-program-library.git\", branch = \"$branch\", package = \"spl-token\", features = [\"no-entrypoint\"] }" >> $anchor_spl_toml
        end
        # Commit and push changes
        cd $tmp_dir/anchor
        git add spl/Cargo.toml
        git commit -m "Add no-entrypoint feature to spl-token in anchor-spl" || true
        git push origin $branch
        if test $status -ne 0
            echo "Failed to push changes to anchor"
            exit 1
        end
        cd -
    else
        echo "spl-token already has no-entrypoint feature in $anchor_spl_toml"
    end
else
    echo "Error: $anchor_spl_toml not found"
    exit 1
end

# Step 4: Patch project Cargo.toml
set -l project_toml $project_dir/Cargo.toml
if test -f $project_toml
    echo "Patching $project_toml for spl-token and anchor-spl..."
    # Remove spl-token from [patch.crates-io]
    sed -i '/spl-token = {.*solana-program-library.*}/d' $project_toml
    # Update anchor-spl to disable default-features
    sed -i 's|anchor-spl = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat" }|anchor-spl = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", default-features = false }|' $project_toml
    sed -i '/\[patch.crates-io\]/a anchor-spl = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", default-features = false }' $project_toml
    # Ensure [patch."https://github.com/hamkj7hpo/solana-program-library.git"] exists
    if not grep -q "\[patch.\"https://github.com/hamkj7hpo/solana-program-library.git\"\]" $project_toml
        echo -e "\n[patch.\"https://github.com/hamkj7hpo/solana-program-library.git\"]\nspl-token = { git = \"https://github.com/hamkj7hpo/solana-program-library.git\", branch = \"$branch\", package = \"spl-token\", features = [\"no-entrypoint\"] }" >> $project_toml
    else if not grep -q "spl-token =.*no-entrypoint" $project_toml
        sed -i "/\[patch.\"https:\/\/github.com\/hamkj7hpo\/solana-program-library.git\"\]/a spl-token = { git = \"https://github.com/hamkj7hpo/solana-program-library.git\", branch = \"$branch\", package = \"spl-token\", features = [\"no-entrypoint\"] }" $project_toml
    else
        echo "spl-token patch with no-entrypoint already exists in $project_toml"
    end
    # Commit and push changes
    cd $project_dir
    # Stage all changes, including untracked files
    git add Cargo.toml
    git add -A
    git commit -m "Update Cargo.toml to fix spl-token patch and disable anchor-spl default features" || true
    git push origin main
    if test $status -ne 0
        echo "Failed to push changes to safe_pump project"
        exit 1
    end
    cd -
else
    echo "Error: $project_toml not found"
    exit 1
end

# Step 5: Clean and build with verbose output
echo "Cleaning and building project..."
cd $project_dir
rm -rf Cargo.lock target ~/.cargo/git/checkouts/*
cargo clean
cargo update -v
set -x RUST_LOG debug
cargo build-sbf -- --release
if test $status -eq 0
    echo "Build successful!"
else
    echo "Build failed, check output for errors."
    exit 1
end
