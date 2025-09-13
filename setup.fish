#!/usr/bin/env fish

# setup.fish
echo "setup.fish version 3.16"

# Store the initial working directory
set -x ORIGINAL_PWD (pwd)

# Function to resolve rebase conflicts in a repository
function resolve_rebase_conflicts
    set repo_dir $argv[1]
    set conflicted_file $argv[2]

    cd $repo_dir
    if test -d .git/rebase-merge
        echo "Rebase in progress in $repo_dir, resolving conflict in $conflicted_file..."

        # Backup the original file
        cp $conflicted_file $conflicted_file.bak

        # Apply the desired zeroize dependency
        sed -i '/zeroize/ s/.*/zeroize = { git = "https:\/\/github.com\/hamkj7hpo\/utils.git", branch = "safe-pump-compat", version = "1.3.0" }/' $conflicted_file

        # Mark as resolved
        git add $conflicted_file
        git rebase --continue
        if test $status -ne 0
            echo "Failed to continue rebase in $repo_dir, aborting"
            git rebase --abort
            cd $ORIGINAL_PWD
            exit 1
        end
    else
        echo "No rebase in progress in $repo_dir"
    end
    cd $ORIGINAL_PWD
end

# Function to fix zeroize dependency in Cargo.toml
function fix_zeroize_dependency
    set repo_dir $argv[1]
    set cargo_toml $argv[2]

    echo "Fixing zeroize dependency in $repo_dir/$cargo_toml"
    cd $repo_dir
    if test -f $cargo_toml
        cp $cargo_toml $cargo_toml.bak
        sed -i '/zeroize/ s/.*/zeroize = { git = "https:\/\/github.com\/hamkj7hpo\/utils.git", branch = "safe-pump-compat", version = "1.3.0" }/' $cargo_toml
        git add $cargo_toml
        git commit -m "Fix zeroize dependency in $cargo_toml (version 3.16)" --no-verify
    else
        echo "Warning: $cargo_toml not found, skipping"
    end
    cd $ORIGINAL_PWD
end

# Function to detect correct branch
function get_correct_branch
    set repo_dir $argv[1]
    set default_branch $argv[2]

    cd $repo_dir
    # Ensure repository is valid
    if not test -d .git
        echo "Error: $repo_dir is not a valid git repository"
        cd $ORIGINAL_PWD
        return 1
    end

    # Fetch remote branches
    git fetch origin 2>/dev/null
    if test $status -ne 0
        echo "Error: Failed to fetch remote branches for $repo_dir"
        cd $ORIGINAL_PWD
        return 1
    end

    # List available branches
    set branches (git branch -r | grep -E 'origin/(main|master|safe-pump-compat)' | sed 's/origin\///' | sort -u)
    if contains "safe-pump-compat" $branches
        echo "safe-pump-compat"
    else if contains "main" $branches
        echo "main"
    else if contains "master" $branches
        echo "master"
    else
        echo "unknown"
    end
    cd $ORIGINAL_PWD
end

# Main setup process
echo "Checking git configuration..."
git config --global user.email "safe-pump@example.com"
git config --global user.name "Safe Pump"

echo "Verifying global SSH access to GitHub..."
ssh -T git@github.com 2>/dev/null
if test $status -ne 1
    echo "SSH access to GitHub failed, please configure SSH keys"
    exit 1
end

echo "Committing changes to setup.fish..."
git add setup.fish
git commit -m "Update setup.fish to version 3.16 to fix branch detection and repository validation" --no-verify

# Process solana repository
echo "Processing solana into /tmp/deps/solana..."
mkdir -p /tmp/deps
cd /tmp/deps
if not test -d solana
    git clone ssh://git@github.com/hamkj7hpo/solana.git
    if test $status -ne 0
        echo "Failed to clone solana repository, check SSH access or repository URL"
        cd $ORIGINAL_PWD
        exit 1
    end
end
cd solana

# Clean up any stuck rebase
if test -d .git/rebase-merge
    echo "Cleaning up stuck rebase in solana"
    git rebase --abort
end

# Detect correct branch
set solana_branch (get_correct_branch . "main")
if test "$solana_branch" = "unknown"
    echo "Failed to determine branch for solana, attempting to create safe-pump-compat"
    git checkout -b safe-pump-compat
    git push --set-upstream origin safe-pump-compat
    set solana_branch "safe-pump-compat"
end
git checkout $solana_branch
if test $status -ne 0
    echo "Failed to checkout $solana_branch in solana"
    cd $ORIGINAL_PWD
    exit 1
end

# Update and handle rebase
git fetch origin
git rebase origin/$solana_branch
if test $status -ne 0
    resolve_rebase_conflicts /tmp/deps/solana sdk/program/Cargo.toml
    if test $status -ne 0
        cd $ORIGINAL_PWD
        exit 1
    end
end
git push --force

# Fix zeroize in solana
fix_zeroize_dependency /tmp/deps/solana sdk/program/Cargo.toml

# Process curve25519-dalek
echo "Processing curve25519-dalek into /tmp/deps/curve25519-dalek..."
cd /tmp/deps
if test -d curve25519-dalek
    rm -rf curve25519-dalek
end
git clone ssh://git@github.com/hamkj7hpo/curve25519-dalek.git
if test $status -ne 0
    echo "Failed to clone curve25519-dalek repository"
    cd $ORIGINAL_PWD
    exit 1
end
cd curve25519-dalek
git checkout -b safe-pump-compat-v2
fix_zeroize_dependency /tmp/deps/curve25519-dalek curve25519-dalek/Cargo.toml
fix_zeroize_dependency /tmp/deps/curve25519-dalek ed25519-dalek/Cargo.toml
fix_zeroize_dependency /tmp/deps/curve25519-dalek x25519-dalek/Cargo.toml
git push --set-upstream origin safe-pump-compat-v2
git fetch origin
git rebase origin/safe-pump-compat-v2
if test $status -ne 0
    resolve_rebase_conflicts /tmp/deps/curve25519-dalek curve25519-dalek/Cargo.toml
    if test $status -ne 0
        cd $ORIGINAL_PWD
        exit 1
    end
end
git push --force

# Process spl-type-length-value
echo "Processing spl-type-length-value into /tmp/deps/spl-type-length-value..."
cd /tmp/deps
if test -d spl-type-length-value
    cd spl-type-length-value
    # Check if repository is archived
    git push origin master --dry-run 2>&1 | grep -q "archived" && set archived true || set archived false
    if test "$archived" = "true"
        echo "spl-type-length-value is archived, skipping push"
    else
        set spl_branch (get_correct_branch . "main")
        if test "$spl_branch" = "unknown"
            echo "Failed to determine branch for spl-type-length-value, creating safe-pump-compat"
            git checkout -b safe-pump-compat
            git push --set-upstream origin safe-pump-compat
            set spl_branch "safe-pump-compat"
        end
        git checkout $spl_branch
        git fetch origin
        git rebase origin/$spl_branch
        if test $status -ne 0
            echo "Rebase failed for spl-type-length-value, aborting"
            git rebase --abort
            cd $ORIGINAL_PWD
            exit 1
        end
        git push --force
    end
else
    git clone ssh://git@github.com/hamkj7hpo/spl-type-length-value.git
    if test $status -ne 0
        echo "Failed to clone spl-type-length-value repository"
        cd $ORIGINAL_PWD
        exit 1
    end
    cd spl-type-length-value
    set spl_branch (get_correct_branch . "main")
    if test "$spl_branch" = "unknown"
        echo "Creating safe-pump-compat branch for spl-type-length-value"
        git checkout -b safe-pump-compat
        git push --set-upstream origin safe-pump-compat
        set spl_branch "safe-pump-compat"
    end
    git checkout $spl_branch
end
fix_zeroize_dependency /tmp/deps/spl-type-length-value Cargo.toml

# Fix solana-program dependency in spl-type-length-value
echo "Fixing solana-program dependency in spl-type-length-value..."
cd /tmp/deps/spl-type-length-value
if test -f tlv-account-resolution/Cargo.toml
    cp tlv-account-resolution/Cargo.toml tlv-account-resolution/Cargo.toml.bak
    sed -i '/solana-program/ s/.*/solana-program = { git = "https:\/\/github.com\/hamkj7hpo\/solana.git", branch = "safe-pump-compat" }/' tlv-account-resolution/Cargo.toml
    git add tlv-account-resolution/Cargo.toml
    git commit -m "Fix solana-program dependency in spl-type-length-value (version 3.16)" --no-verify
    if test "$archived" != "true"
        git push --force
    end
end

# Return to main project
cd $ORIGINAL_PWD

# Fix main project Cargo.toml
echo "Patching ./Cargo.toml for dependencies..."
fix_zeroize_dependency . Cargo.toml

# Clean and build
echo "Cleaning and building the project..."
cargo clean
cargo build
if test $status -ne 0
    echo "Build failed, check errors above"
    cargo build --verbose
    exit 1
end

echo "setup.fish version 3.16 completed"
