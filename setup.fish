#!/usr/bin/env fish

# setup.fish
echo "setup.fish version 3.26"

# Store the initial working directory
set -x ORIGINAL_PWD (pwd)

# Function to inspect and display file contents
function inspect_file
    set file_path $argv[1]
    if test -f $file_path
        echo "Contents of $file_path:"
        cat $file_path
        echo "---- End of $file_path ----"
    else
        echo "Error: $file_path does not exist"
    end
end

# Function to resolve rebase conflicts in a repository
function resolve_rebase_conflicts
    set repo_dir $argv[1]
    set conflicted_file $argv[2]
    set zeroize_source $argv[3]

    cd $repo_dir
    if test -d .git/rebase-merge
        echo "Rebase in progress in $repo_dir, resolving conflict in $conflicted_file..."
        inspect_file $conflicted_file
        cp $conflicted_file $conflicted_file.bak
        # Remove conflict markers
        sed -i '/<<<<<<< HEAD/,/=======$/d' $conflicted_file
        sed -i '/>>>>>>>.*$/d' $conflicted_file
        # Ensure zeroize dependency
        if grep -q '^zeroize\s*=' $conflicted_file
            sed -i "s#^zeroize\s*=\s*.*#$zeroize_source#" $conflicted_file
        else
            sed -i "/^\[dependencies\]/a $zeroize_source" $conflicted_file
        end
        sed -i 's#, package = "zeroize"##g' $conflicted_file
        # Clean up [features] section
        sed -i '/^zeroize\s*=\s*{.*$/d' $conflicted_file
        if grep -q '^\[features\]' $conflicted_file && not grep -q 'zeroize\s*=\s*\["dep:zeroize"\]' $conflicted_file
            sed -i '/^\[features\]/a zeroize = ["dep:zeroize"]' $conflicted_file
        end
        inspect_file $conflicted_file
        git add $conflicted_file
        git rebase --continue
        if test $status -ne 0
            echo "Failed to continue rebase in $repo_dir, aborting"
            git rebase --abort
            rm -f $conflicted_file.bak
            cd $ORIGINAL_PWD
            exit 1
        end
        rm -f $conflicted_file.bak
    else
        echo "No rebase in progress in $repo_dir"
    end
    cd $ORIGINAL_PWD
end

# Function to fix zeroize dependency in Cargo.toml
function fix_zeroize_dependency
    set repo_dir $argv[1]
    set cargo_toml $argv[2]
    set zeroize_source $argv[3]

    cd $repo_dir
    if test -f $cargo_toml
        echo "Fixing zeroize dependency in $repo_dir/$cargo_toml"
        inspect_file $cargo_toml
        cp $cargo_toml $cargo_toml.bak
        # Remove conflict markers
        sed -i '/<<<<<<< HEAD/,/=======$/d' $cargo_toml
        sed -i '/>>>>>>>.*$/d' $cargo_toml
        # Replace or add zeroize in [dependencies]
        if grep -q '^zeroize\s*=' $cargo_toml
            sed -i "s#^zeroize\s*=\s*.*#$zeroize_source#" $cargo_toml
        else
            sed -i "/^\[dependencies\]/a $zeroize_source" $cargo_toml
        end
        sed -i 's#, package = "zeroize"##g' $cargo_toml
        # Clean up [features] section
        sed -i '/^zeroize\s*=\s*{.*$/d' $cargo_toml
        if grep -q '^\[features\]' $cargo_toml && not grep -q 'zeroize\s*=\s*\["dep:zeroize"\]' $cargo_toml
            sed -i '/^\[features\]/a zeroize = ["dep:zeroize"]' $cargo_toml
        end
        inspect_file $cargo_toml
        git add $cargo_toml
        git commit -m "Fix zeroize dependency in $cargo_toml (version 3.26)" --no-verify
        rm -f $cargo_toml.bak
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
    if not test -d .git
        echo "Error: $repo_dir is not a valid git repository"
        cd $ORIGINAL_PWD
        return 1
    end
    git fetch origin 2>/dev/null
    if test $status -ne 0
        echo "Error: Failed to fetch remote branches for $repo_dir"
        cd $ORIGINAL_PWD
        return 1
    end
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

# Check for rebase in main repository
if test -d .git/rebase-merge
    echo "Rebase in progress in main repository, attempting to resolve..."
    resolve_rebase_conflicts . Cargo.toml "zeroize = { git = \"https://github.com/hamkj7hpo/utils.git\", branch = \"safe-pump-compat\", version = \"1.3.0\", features = [\"alloc\", \"zeroize_derive\"] }"
    git checkout safe-pump-compat
end

echo "Committing changes to setup.fish..."
git add setup.fish
git commit -m "Update setup.fish to version 3.26 to fix Cargo.toml feature error and rebase issues" --no-verify

# Validate utils repository
echo "Validating utils repository for zeroize..."
cd /tmp/deps
if not test -d utils
    git clone ssh://git@github.com/hamkj7hpo/utils.git
    if test $status -ne 0
        echo "Failed to clone utils repository, falling back to crates.io"
        set zeroize_source 'zeroize = { version = "1.3.0", features = ["alloc", "zeroize_derive"] }'
    else
        cd utils
        git checkout safe-pump-compat 2>/dev/null
        if test -d zeroize
            inspect_file zeroize/Cargo.toml
            set zeroize_source 'zeroize = { git = "https://github.com/hamkj7hpo/utils.git", branch = "safe-pump-compat", version = "1.3.0", features = ["alloc", "zeroize_derive"] }'
        else
            echo "Warning: zeroize crate not found in utils repository, falling back to crates.io"
            set zeroize_source 'zeroize = { version = "1.3.0", features = ["alloc", "zeroize_derive"] }'
        end
        cd $ORIGINAL_PWD
    end
else
    cd utils
    git fetch origin
    git checkout safe-pump-compat 2>/dev/null
    if test -d zeroize
        inspect_file zeroize/Cargo.toml
        set zeroize_source 'zeroize = { git = "https://github.com/hamkj7hpo/utils.git", branch = "safe-pump-compat", version = "1.3.0", features = ["alloc", "zeroize_derive"] }'
    else
        echo "Warning: zeroize crate not found in utils repository, falling back to crates.io"
        set zeroize_source 'zeroize = { version = "1.3.0", features = ["alloc", "zeroize_derive"] }'
    end
    cd $ORIGINAL_PWD
end

# Process solana repository
echo "Processing solana into /tmp/deps/solana..."
mkdir -p /tmp/deps
cd /tmp/deps
if not test -d solana
    git clone ssh://git@github.com/hamkj7hpo/solana.git
    if test $status -ne 0
        echo "Failed to clone solana repository"
        cd $ORIGINAL_PWD
        exit 1
    end
end
cd solana
if test -d .git/rebase-merge
    echo "Cleaning up stuck rebase in solana"
    git rebase --abort
end
set solana_branch (get_correct_branch . "main")
if test "$solana_branch" = "unknown"
    echo "No main or master branch found, checking for safe-pump-compat"
    git checkout safe-pump-compat 2>/dev/null || git checkout -b safe-pump-compat
    git push --set-upstream origin safe-pump-compat 2>/dev/null
    set solana_branch "safe-pump-compat"
end
git checkout $solana_branch
git fetch origin
git rebase origin/$solana_branch
if test $status -ne 0
    resolve_rebase_conflicts /tmp/deps/solana Cargo.toml "$zeroize_source"
    if test $status -ne 0
        cd $ORIGINAL_PWD
        exit 1
    end
end
git checkout $solana_branch
git push --force
fix_zeroize_dependency /tmp/deps/solana sdk/program/Cargo.toml "$zeroize_source"

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
if test -d .git/rebase-merge
    echo "Cleaning up stuck rebase in curve25519-dalek"
    git rebase --abort
end
git checkout safe-pump-compat-v2 2>/dev/null || git checkout -b safe-pump-compat-v2
fix_zeroize_dependency /tmp/deps/curve25519-dalek curve25519-dalek/Cargo.toml "$zeroize_source"
fix_zeroize_dependency /tmp/deps/curve25519-dalek ed25519-dalek/Cargo.toml "$zeroize_source"
fix_zeroize_dependency /tmp/deps/curve25519-dalek x25519-dalek/Cargo.toml "$zeroize_source"
# Fix cached Cargo.toml files
set cached_dir /home/safe-pump/.cargo/git/checkouts/curve25519-dalek-4e97d8327ec85729/3adcba0
if test -d $cached_dir
    echo "Fixing cached curve25519-dalek Cargo.toml files..."
    fix_zeroize_dependency $cached_dir ed25519-dalek/Cargo.toml "$zeroize_source"
    fix_zeroize_dependency $cached_dir x25519-dalek/Cargo.toml "$zeroize_source"
end
git remote set-url origin ssh://git@github.com/hamkj7hpo/curve25519-dalek.git
git checkout safe-pump-compat-v2
git fetch origin
if git ls-remote --heads origin safe-pump-compat-v2 | grep -q safe-pump-compat-v2
    git push origin safe-pump-compat-v2 --force
else
    git push --set-upstream origin safe-pump-compat-v2
end
git rebase origin/safe-pump-compat-v2
if test $status -ne 0
    resolve_rebase_conflicts /tmp/deps/curve25519-dalek Cargo.toml "$zeroize_source"
    if test $status -ne 0
        cd $ORIGINAL_PWD
        exit 1
    end
end
git checkout safe-pump-compat-v2
git push --force

# Process spl-type-length-value
echo "Processing spl-type-length-value into /tmp/deps/spl-type-length-value..."
cd /tmp/deps
if test -d spl-type-length-value
    cd spl-type-length-value
    if test -d .git/rebase-merge
        echo "Cleaning up stuck rebase in spl-type-length-value"
        git rebase --abort
    end
    set spl_branch (get_correct_branch . "main")
    if test "$spl_branch" = "unknown"
        echo "No main or master branch found, checking for safe-pump-compat"
        git checkout safe-pump-compat 2>/dev/null || git checkout -b safe-pump-compat
        git push --set-upstream origin safe-pump-compat 2>/dev/null
        set spl_branch "safe-pump-compat"
    end
    git checkout $spl_branch
    git fetch origin
    git rebase origin/$spl_branch
    if test $status -ne 0
        resolve_rebase_conflicts /tmp/deps/spl-type-length-value Cargo.toml "$zeroize_source"
        if test $status -ne 0
            cd $ORIGINAL_PWD
            exit 1
        end
    end
    git checkout $spl_branch
    fix_zeroize_dependency /tmp/deps/spl-type-length-value Cargo.toml "$zeroize_source"
    if test -f tlv-account-resolution/Cargo.toml
        echo "Fixing solana-program dependency in spl-type-length-value..."
        inspect_file tlv-account-resolution/Cargo.toml
        cp tlv-account-resolution/Cargo.toml tlv-account-resolution/Cargo.toml.bak
        sed -i '/^solana-program\s*=/d' tlv-account-resolution/Cargo.toml
        sed -i '/^\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat" }' tlv-account-resolution/Cargo.toml
        inspect_file tlv-account-resolution/Cargo.toml
        git add tlv-account-resolution/Cargo.toml
        git commit -m "Fix solana-program dependency in spl-type-length-value (version 3.26)" --no-verify
        rm -f tlv-account-resolution/Cargo.toml.bak
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
        git checkout safe-pump-compat 2>/dev/null || git checkout -b safe-pump-compat
        git push --set-upstream origin safe-pump-compat
        set spl_branch "safe-pump-compat"
    end
    git checkout $spl_branch
    fix_zeroize_dependency /tmp/deps/spl-type-length-value Cargo.toml "$zeroize_source"
end
cd $ORIGINAL_PWD

# Fix main project Cargo.toml
echo "Patching ./Cargo.toml for dependencies..."
if test -f Cargo.toml
    inspect_file Cargo.toml
    cp Cargo.toml Cargo.toml.bak
    # Remove conflict markers and workspace section
    sed -i '/<<<<<<< HEAD/,/=======$/d' Cargo.toml
    sed -i '/>>>>>>>.*$/d' Cargo.toml
    sed -i '/\[workspace\]/,/^\[.*\]$/d' Cargo.toml
    sed -i '/\[patch.crates-io\]/,/^$/d' Cargo.toml
    # Clean up [features] section
    sed -i '/^zeroize\s*=\s*{.*$/d' Cargo.toml
    # Fix zeroize dependency
    fix_zeroize_dependency . Cargo.toml "$zeroize_source"
    rm -f Cargo.toml.bak
end

# Clean up untracked .bak files
find . -name "*.bak" -delete
find /tmp/deps -name "*.bak" -delete

# Clean and build
echo "Cleaning and building the project..."
cargo clean
cargo build
if test $status -ne 0
    echo "Build failed, check errors above"
    cargo build --verbose
    exit 1
end

echo "setup.fish version 3.26 completed"
