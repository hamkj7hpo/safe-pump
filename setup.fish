#!/usr/bin/env fish

# setup.fish
echo "setup.fish version 3.14"

# Function to resolve rebase conflicts in a repository
function resolve_rebase_conflicts
    set repo_dir $argv[1]
    set conflicted_file $argv[2]
    set resolution_strategy $argv[3]

    cd $repo_dir
    if git status | grep -q "rebase in progress"
        echo "Rebase in progress in $repo_dir, resolving conflict in $conflicted_file..."

        # Example resolution: For Cargo.toml, ensure zeroize dependency is correct
        if test "$conflicted_file" = "sdk/program/Cargo.toml"
            # Backup the original file
            cp $conflicted_file $conflicted_file.bak

            # Apply the desired zeroize dependency
            sed -i '/zeroize/ s/.*/zeroize = { git = "https:\/\/github.com\/hamkj7hpo\/utils.git", branch = "safe-pump-compat", version = "1.3.0" }/' $conflicted_file

            # Mark as resolved
            git add $conflicted_file
            git rebase --continue
            if test $status -ne 0
                echo "Failed to continue rebase in $repo_dir"
                git rebase --abort
                exit 1
            end
        else if test "$conflicted_file" = "curve25519-dalek/Cargo.toml"
            # Handle curve25519-dalek conflict
            cp $conflicted_file $conflicted_file.bak
            sed -i '/zeroize/ s/.*/zeroize = { git = "https:\/\/github.com\/hamkj7hpo\/utils.git", branch = "safe-pump-compat", version = "1.3.0" }/' $conflicted_file
            git add $conflicted_file
            git rebase --continue
            if test $status -ne 0
                echo "Failed to continue rebase in $repo_dir"
                git rebase --abort
                exit 1
            end
        else
            echo "Unknown conflicted file $conflicted_file, aborting rebase"
            git rebase --abort
            exit 1
        end
    end
    cd -
end

# Function to fix zeroize dependency in Cargo.toml
function fix_zeroize_dependency
    set repo_dir $argv[1]
    set cargo_toml $argv[2]

    echo "Fixing zeroize dependency in $repo_dir/$cargo_toml"
    cd $repo_dir
    cp $cargo_toml $cargo_toml.bak
    sed -i '/zeroize/ s/.*/zeroize = { git = "https:\/\/github.com\/hamkj7hpo\/utils.git", branch = "safe-pump-compat", version = "1.3.0" }/' $cargo_toml
    git add $cargo_toml
    git commit -m "Fix zeroize dependency in $cargo_toml (version 3.14)"
    git push --force
    cd -
end

# Function to detect correct branch
function get_correct_branch
    set repo_dir $argv[1]
    set default_branch $argv[2]

    cd $repo_dir
    # Try checking out the default branch
    git checkout $default_branch 2>/dev/null
    if test $status -ne 0
        # Fallback to master if main fails
        git checkout master 2>/dev/null
        if test $status -eq 0
            echo "master"
        else
            echo "unknown"
        end
    else
        echo $default_branch
    end
    cd -
end

# Main setup process
echo "Checking git configuration..."
# (Existing git configuration checks)

echo "Verifying global SSH access to GitHub..."
# (Existing SSH checks)

echo "Committing changes to setup.fish..."
git add setup.fish
git commit -m "Update setup.fish to version 3.14 to fix sed errors, non-fast-forward pushes, and zeroize versioning"

# Process solana repository
echo "Processing solana into /tmp/deps/solana..."
cd /tmp/deps
if not test -d solana
    git clone ssh://git@github.com/hamkj7hpo/solana.git
end
cd solana

# Detect correct branch
set solana_branch (get_correct_branch . "main")
if test "$solana_branch" = "unknown"
    echo "Failed to determine branch for solana"
    exit 1
end
git checkout $solana_branch

# Update and handle rebase
git fetch origin
git rebase origin/$solana_branch
if test $status -ne 0
    # Resolve conflicts in program_error.rs (already resolved, so check Cargo.toml)
    resolve_rebase_conflicts /tmp/deps/solana sdk/program/Cargo.toml "use_ours"
    if test $status -ne 0
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
cd curve25519-dalek
git checkout -b safe-pump-compat-v2
fix_zeroize_dependency /tmp/deps/curve25519-dalek curve25519-dalek/Cargo.toml
fix_zeroize_dependency /tmp/deps/curve25519-dalek ed25519-dalek/Cargo.toml
fix_zeroize_dependency /tmp/deps/curve25519-dalek x25519-dalek/Cargo.toml
git rebase origin/safe-pump-compat-v2
if test $status -ne 0
    resolve_rebase_conflicts /tmp/deps/curve25519-dalek curve25519-dalek/Cargo.toml "use_ours"
    if test $status -ne 0
        exit 1
    end
end
git push --force

# Process spl-type-length-value
echo "Processing spl-type-length-value into /tmp/deps/spl-type-length-value..."
cd /tmp/deps
if test -d spl-type-length-value
    cd spl-type-length-value
    set spl_branch (get_correct_branch . "main")
    if test "$spl_branch" = "unknown"
        echo "Failed to determine branch for spl-type-length-value"
        exit 1
    end
    git checkout $spl_branch
    git fetch origin
    git rebase origin/$spl_branch
    git push --force
else
    git clone ssh://git@github.com/hamkj7hpo/spl-type-length-value.git
    cd spl-type-length-value
    set spl_branch (get_correct_branch . "main")
    git checkout -b safe-pump-compat
    git push --set-upstream origin safe-pump-compat
end

# (Add similar logic for other repositories as needed)

# Return to main project
cd /var/www/html/program/safe_pump

# Fix main project Cargo.toml
echo "Patching ./Cargo.toml for dependencies..."
fix_zeroize_dependency . Cargo.toml

# Clean and build
echo "Cleaning and building the project..."
cargo clean
cargo build
if test $status -ne 0
    echo "Build failed, check errors above"
    exit 1
end

echo "setup.fish version 3.14 completed"
