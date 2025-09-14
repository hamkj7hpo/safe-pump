#!/usr/bin/env fish

# setup.fish
echo "setup.fish version 3.48"

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

    if ! cd $repo_dir
        echo "Error: Cannot change to directory $repo_dir"
        return 1
    end
    if test -d .git/rebase-merge
        echo "Rebase in progress in $repo_dir, resolving conflict in $conflicted_file..."
        inspect_file $conflicted_file
        cp $conflicted_file $conflicted_file.bak
        # Remove conflict markers using awk
        awk '/<<<<<<< HEAD/{in_conflict=1; next} /=======/{in_conflict=0; next} />>>>>>>/{in_conflict=0; next} !in_conflict{print}' $conflicted_file > $conflicted_file.tmp
        mv $conflicted_file.tmp $conflicted_file
        # Ensure zeroize and curve25519-dalek dependencies
        set temp_file (mktemp)
        set zeroize_dep "$zeroize_source"
        set curve25519_dep 'curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["std", "serde"] }'
        awk -v zeroize="$zeroize_dep" -v curve25519="$curve25519_dep" '
        BEGIN { in_deps=0; printed_deps=0; deps_content=""; has_zeroize=0; has_curve25519=0 }
        /^\[dependencies\]/ {
            if (!printed_deps) { in_deps=1; deps_content=$0 "\n"; printed_deps=1; next }
            else { in_deps=1; next }
        }
        in_deps && (/^\[/ || /^$/) { 
            in_deps=0; 
            if (!has_zeroize) { deps_content=deps_content zeroize "\n" }
            if (!has_curve25519) { deps_content=deps_content curve25519 "\n" }
            print deps_content; 
            deps_content=""
        }
        in_deps && /^zeroize\s*=/ { has_zeroize=1; deps_content=deps_content zeroize "\n"; next }
        in_deps && /^curve25519-dalek\s*=/ { has_curve25519=1; deps_content=deps_content curve25519 "\n"; next }
        in_deps { deps_content=deps_content $0 "\n" }
        !in_deps { print }
        END { 
            if (printed_deps && deps_content != "") { 
                if (!has_zeroize) { deps_content=deps_content zeroize "\n" }
                if (!has_curve25519) { deps_content=deps_content curve25519 "\n" }
                print deps_content 
            } else if (!printed_deps) { 
                print "\n[dependencies]\n" zeroize "\n" curve25519 
            }
        }
        ' $conflicted_file > $temp_file
        mv $temp_file $conflicted_file
        # Ensure [features] section
        if grep -q '^\[features\]' $conflicted_file && ! grep -q 'zeroize\s*=\s*\["dep:zeroize"\]' $conflicted_file
            echo -e "\nzeroize = [\"dep:zeroize\"]" >> $temp_file
            awk '/^\[features\]/ {print; print "zeroize = [\"dep:zeroize\"]"; next} {print}' $conflicted_file > $temp_file
            mv $temp_file $conflicted_file
        else if ! grep -q '^\[features\]' $conflicted_file
            echo -e "\n[features]\nzeroize = [\"dep:zeroize\"]" >> $conflicted_file
        end
        inspect_file $conflicted_file
        git add $conflicted_file
        git rebase --continue || begin
            echo "Failed to continue rebase in $repo_dir, aborting"
            git rebase --abort
            rm -f $conflicted_file.bak
            cd $ORIGINAL_PWD
            return 1
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

    if ! cd $repo_dir
        echo "Error: Cannot change to directory $repo_dir"
        return 1
    end
    if test -f $cargo_toml
        echo "Fixing zeroize dependency in $repo_dir/$cargo_toml"
        inspect_file $cargo_toml
        cp $cargo_toml $cargo_toml.bak
        # Remove conflict markers using awk
        awk '/<<<<<<< HEAD/{in_conflict=1; next} /=======/{in_conflict=0; next} />>>>>>>/{in_conflict=0; next} !in_conflict{print}' $cargo_toml > $cargo_toml.tmp
        mv $cargo_toml.tmp $cargo_toml
        # Remove duplicate [dependencies] sections and ensure zeroize
        set temp_file (mktemp)
        set zeroize_dep "$zeroize_source"
        set curve25519_dep 'curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", features = ["std", "serde"] }'
        awk -v zeroize="$zeroize_dep" -v curve25519="$curve25519_dep" '
        BEGIN { in_deps=0; printed_deps=0; deps_content=""; has_zeroize=0; has_curve25519=0 }
        /^\[dependencies\]/ {
            if (!printed_deps) { in_deps=1; deps_content=$0 "\n"; printed_deps=1; next }
            else { in_deps=1; next }
        }
        in_deps && (/^\[/ || /^$/) { 
            in_deps=0; 
            if (!has_zeroize) { deps_content=deps_content zeroize "\n" }
            if (!has_curve25519) { deps_content=deps_content curve25519 "\n" }
            print deps_content; 
            deps_content=""
        }
        in_deps && /^zeroize\s*=/ { has_zeroize=1; deps_content=deps_content zeroize "\n"; next }
        in_deps && /^curve25519-dalek\s*=/ { has_curve25519=1; deps_content=deps_content curve25519 "\n"; next }
        in_deps { deps_content=deps_content $0 "\n" }
        !in_deps { print }
        END { 
            if (printed_deps && deps_content != "") { 
                if (!has_zeroize) { deps_content=deps_content zeroize "\n" }
                if (!has_curve25519) { deps_content=deps_content curve25519 "\n" }
                print deps_content 
            } else if (!printed_deps) { 
                print "\n[dependencies]\n" zeroize "\n" curve25519 
            }
        }
        ' $cargo_toml > $temp_file
        mv $temp_file $cargo_toml
        # Ensure [features] section
        if grep -q '^\[features\]' $cargo_toml && ! grep -q 'zeroize\s*=\s*\["dep:zeroize"\]' $cargo_toml
            awk '/^\[features\]/ {print; print "zeroize = [\"dep:zeroize\"]"; next} {print}' $cargo_toml > $temp_file
            mv $temp_file $cargo_toml
        else if ! grep -q '^\[features\]' $cargo_toml
            echo -e "\n[features]\nzeroize = [\"dep:zeroize\"]" >> $cargo_toml
        end
        inspect_file $cargo_toml
        # Validate changes
        set escaped_zeroize (echo "$zeroize_source" | sed 's/[\/.]/\\&/g')
        if ! grep -q "$escaped_zeroize" $cargo_toml
            echo "Error: Failed to add zeroize dependency to $cargo_toml"
            mv $cargo_toml.bak $cargo_toml
            cd $ORIGINAL_PWD
            return 1
        end
        set escaped_curve25519 (echo "$curve25519_dep" | sed 's/[\/.]/\\&/g')
        if ! grep -q "$escaped_curve25519" $cargo_toml
            echo "Error: Failed to add curve25519-dalek dependency to $cargo_toml"
            mv $cargo_toml.bak $cargo_toml
            cd $ORIGINAL_PWD
            return 1
        end
        set target_branch (get_correct_branch $repo_dir "safe-pump-compat")
        if test "$target_branch" = "safe-pump-compat-v2"
            git checkout safe-pump-compat-v2 2>/dev/null || git checkout -b safe-pump-compat-v2
            git push --set-upstream origin safe-pump-compat-v2 2>/dev/null
        else
            git checkout safe-pump-compat 2>/dev/null || git checkout -b safe-pump-compat
            git push --set-upstream origin safe-pump-compat 2>/dev/null
        end
        git add $cargo_toml
        git commit -m "Fix zeroize and curve25519-dalek dependencies in $cargo_toml (version 3.48)" --no-verify
        git push origin $target_branch --force
        rm -f $cargo_toml.bak
    else
        echo "Warning: $cargo_toml not found, skipping"
    end
    cd $ORIGINAL_PWD
end

# Function to reset to safe-pump-compat branch
function reset_to_safe_pump_compat
    set repo_dir $argv[1]
    set target_branch $argv[2]
    if ! cd $repo_dir
        echo "Error: Cannot change to directory $repo_dir"
        return 1
    end
    if git branch | grep -q "$target_branch"
        git checkout $target_branch
        git branch -D master 2>/dev/null
        git push origin --delete master 2>/dev/null
    end
    cd $ORIGINAL_PWD
end

# Function to detect correct branch
function get_correct_branch
    set repo_dir $argv[1]
    set default_branch $argv[2]

    if ! cd $repo_dir
        echo "Error: Cannot change to directory $repo_dir"
        return 1
    end
    if ! test -d .git
        echo "Error: $repo_dir is not a valid git repository"
        cd $ORIGINAL_PWD
        return 1
    end
    git fetch origin 2>/dev/null
    set branches (git branch -r | grep -E 'origin/(main|master|safe-pump-compat|safe-pump-compat-v2)' | sed 's/origin\///' | sort -u)
    if test "$repo_dir" = "/tmp/deps/curve25519-dalek" -o "$repo_dir" = "/home/safe-pump/.cargo/git/checkouts/curve25519-dalek-4e97d8327ec85729/3adcba0"
        if contains "safe-pump-compat-v2" $branches
            echo "safe-pump-compat-v2"
        else
            echo "unknown"
        end
    else
        if contains "safe-pump-compat" $branches
            echo "safe-pump-compat"
        else if contains "main" $branches
            echo "main"
        else if contains "master" $branches
            echo "master"
        else
            echo "unknown"
        end
    end
    cd $ORIGINAL_PWD
end

# Function to reinitialize solana sdk/program/Cargo.toml
function reinitialize_solana_cargo_toml
    set cargo_toml $argv[1]
    echo "Reinitializing $cargo_toml with correct template..."
    mkdir -p (dirname $cargo_toml)
    echo "[package]
name = \"solana-program\"
description = \"Solana Program\"
documentation = \"https://docs.rs/solana-program\"
readme = \"README.md\"
version = { workspace = true }
authors = { workspace = true }
repository = { workspace = true }
homepage = { workspace = true }
license = { workspace = true }
edition = { workspace = true }
rust-version = \"1.72.0\"

[dependencies]
zeroize = { git = \"https://github.com/hamkj7hpo/utils.git\", branch = \"safe-pump-compat\", version = \"1.3.0\", features = [\"alloc\", \"zeroize_derive\"] }
curve25519-dalek = { git = \"https://github.com/hamkj7hpo/curve25519-dalek.git\", branch = \"safe-pump-compat-v2\", features = [\"std\", \"serde\"] }
bincode = { workspace = true }
blake3 = { workspace = true, features = [\"digest\", \"traits-preview\"] }
borsh = { workspace = true }
borsh0-10 = { package = \"borsh\", version = \"0.10.3\" }
borsh0-9 = { package = \"borsh\", version = \"0.9.3\" }
bs58 = { workspace = true }
bv = { workspace = true, features = [\"serde\"] }
bytemuck = { workspace = true, features = [\"derive\"] }
itertools = { workspace = true }
lazy_static = { workspace = true }
log = { workspace = true }
memoffset = { workspace = true }
num-derive = { workspace = true }
num-traits = { workspace = true, features = [\"i128\"] }
rustversion = { workspace = true }
serde = { workspace = true, features = [\"derive\"] }
serde_bytes = { workspace = true }
serde_derive = { workspace = true }
serde_json = { workspace = true }
sha2 = { workspace = true }
sha3 = { workspace = true }
solana-frozen-abi = { workspace = true }
solana-frozen-abi-macro = { workspace = true }
solana-sdk-macro = { workspace = true }
thiserror = { workspace = true }

[target.'cfg(target_os = \"solana\")'.dependencies]
getrandom = { version = \"0.2.15\", features = [\"custom\"] }

[target.'cfg(not(target_os = \"solana\"))'.dependencies]
ark-bn254 = { workspace = true }
ark-ec = { workspace = true }
ark-ff = { workspace = true }
ark-serialize = { workspace = true }
base64 = { workspace = true, features = [\"alloc\", \"std\"] }
bitflags = { workspace = true }
itertools = { workspace = true }
libc = { workspace = true, features = [\"extra_traits\"] }
libsecp256k1 = { workspace = true }
light-poseidon = { workspace = true }
num-bigint = { workspace = true }
rand = { workspace = true }
tiny-bip39 = { version = \"0.8.0\" }
wasm-bindgen = { workspace = true }

[target.'cfg(not(target_os = \"solana\"))'.dev-dependencies]
solana-logger = { workspace = true }

[target.'cfg(target_arch = \"wasm32\")'.dependencies]
console_error_panic_hook = { workspace = true }
console_log = { workspace = true }
getrandom = { version = \"0.2.15\", features = [\"custom\"] }
js-sys = { workspace = true }

[target.'cfg(not(target_pointer_width = \"64\"))'.dependencies]
parking_lot = { workspace = true }

[dev-dependencies]
anyhow = { workspace = true }
array-bytes = { workspace = true }
assert_matches = { workspace = true }
serde_json = { workspace = true }
static_assertions = { workspace = true }

[build-dependencies]
rustc_version = { workspace = true }

[target.'cfg(any(unix, windows))'.build-dependencies]
cc = { workspace = true, features = [\"jobserver\", \"parallel\"] }

[package.metadata.docs.rs]
targets = [\"x86_64-unknown-linux-gnu\"]

[lib]
crate-type = [\"cdylib\", \"rlib\"]

[features]
zeroize = [\"dep:zeroize\"]
default = []" > $cargo_toml
    inspect_file $cargo_toml
end

# Function to fix tlv-account-resolution/Cargo.toml
function fix_tlv_account_resolution
    set cargo_toml $argv[1]
    echo "Fixing $cargo_toml with correct dependencies..."
    mkdir -p (dirname $cargo_toml)
    echo "[package]
name = \"spl-tlv-account-resolution\"
version = \"0.6.0\"
description = \"Solana Program Library TLV Account Resolution\"
edition = \"2021\"
license = \"Apache-2.0\"
repository = \"https://github.com/hamkj7hpo/spl-type-length-value\"

[lib]
crate-type = [\"cdylib\", \"lib\"]

[dependencies]
solana-program = { git = \"https://github.com/hamkj7hpo/solana.git\", branch = \"safe-pump-compat\" }
spl-pod = { git = \"https://github.com/hamkj7hpo/spl-pod.git\", branch = \"safe-pump-compat\" }
zeroize = { git = \"https://github.com/hamkj7hpo/utils.git\", branch = \"safe-pump-compat\", version = \"1.3.0\", features = [\"alloc\", \"zeroize_derive\"] }
curve25519-dalek = { git = \"https://github.com/hamkj7hpo/curve25519-dalek.git\", branch = \"safe-pump-compat-v2\", features = [\"std\", \"serde\"] }
bytemuck = { version = \"1.18.0\", features = [\"derive\"] }

[features]
zeroize = [\"dep:zeroize\"]" > $cargo_toml
    inspect_file $cargo_toml
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
git commit -m "Update setup.fish to version 3.48 to fix multiple zeroize detection" --no-verify
git push origin safe-pump-compat

# Fix main project Cargo.toml
echo "Patching ./Cargo.toml for dependencies..."
if test -f Cargo.toml
    inspect_file Cargo.toml
    cp Cargo.toml Cargo.toml.bak
    # Remove conflict markers using awk
    awk '/<<<<<<< HEAD/{in_conflict=1; next} /=======/{in_conflict=0; next} />>>>>>>/{in_conflict=0; next} !in_conflict{print}' Cargo.toml > Cargo.toml.tmp
    mv Cargo.toml.tmp Cargo.toml
    # Remove duplicate [dependencies] and zeroize entries
    set temp_file (mktemp)
    set zeroize_source 'zeroize = { git = "https://github.com/hamkj7hpo/utils.git", branch = "safe-pump-compat", version = "1.3.0", features = ["alloc", "zeroize_derive"] }'
    awk -v zeroize="$zeroize_source" '
    BEGIN { in_deps=0; printed_deps=0; deps_content=""; has_zeroize=0 }
    /^\[dependencies\]/ {
        if (!printed_deps) { in_deps=1; deps_content=$0 "\n"; printed_deps=1; next }
        else { in_deps=1; next }
    }
    in_deps && (/^\[/ || /^$/) { 
        in_deps=0; 
        if (!has_zeroize) { deps_content=deps_content zeroize "\n" }
        print deps_content; 
        deps_content=""
    }
    in_deps && /^zeroize\s*=/ { has_zeroize=1; deps_content=deps_content zeroize "\n"; next }
    in_deps { deps_content=deps_content $0 "\n" }
    !in_deps { print }
    END { 
        if (printed_deps && deps_content != "") { 
            if (!has_zeroize) { deps_content=deps_content zeroize "\n" }
            print deps_content 
        } else if (!printed_deps) { 
            print "\n[dependencies]\n" zeroize 
        }
    }
    ' Cargo.toml > $temp_file
    mv $temp_file Cargo.toml
    # Ensure [features] section
    if grep -q '^\[features\]' Cargo.toml && ! grep -q 'zeroize\s*=\s*\["dep:zeroize"\]' Cargo.toml
        awk '/^\[features\]/ {print; print "zeroize = [\"dep:zeroize\"]"; next} {print}' Cargo.toml > $temp_file
        mv $temp_file Cargo.toml
    else if ! grep -q '^\[features\]' Cargo.toml
        echo -e "\n[features]\nzeroize = [\"dep:zeroize\"]\ncpi = []" >> Cargo.toml
    end
    # Add [patch.crates-io] section
    if ! grep -q '^\[patch.crates-io\]' Cargo.toml
        echo -e "\n[patch.crates-io]\nzeroize = { git = \"https://github.com/hamkj7hpo/utils.git\", branch = \"safe-pump-compat\" }\ncurve25519-dalek = { git = \"https://github.com/hamkj7hpo/curve25519-dalek.git\", branch = \"safe-pump-compat-v2\" }\nsolana-program = { git = \"https://github.com/hamkj7hpo/solana.git\", branch = \"safe-pump-compat\" }\nspl-pod = { git = \"https://github.com/hamkj7hpo/spl-pod.git\", branch = \"safe-pump-compat\" }\nspl-tlv-account-resolution = { git = \"https://github.com/hamkj7hpo/spl-type-length-value.git\", branch = \"safe-pump-compat\" }" >> Cargo.toml
    end
    inspect_file Cargo.toml
    # Validate changes
    set has_feature (grep -q 'zeroize\s*=\s*\["dep:zeroize"\]' Cargo.toml && echo 1 || echo 0)
    set has_dep (awk '/^\[dependencies\]/ {in_deps=1} /^\[/ && !/^\[dependencies\]/ {in_deps=0} in_deps && /^zeroize\s*=/ {print 1; exit} END {print 0}' Cargo.toml)
    if test $has_feature -eq 1 -a $has_dep -eq 0
        echo "Error: zeroize feature defined but no zeroize dependency in [dependencies]"
        mv Cargo.toml.bak Cargo.toml
        exit 1
    end
    set zeroize_count (awk '/^\[dependencies\]/ {in_deps=1} /^\[/ && !/^\[dependencies\]/ {in_deps=0} in_deps && /^zeroize\s*=/ {count++} END {print count+0}' Cargo.toml)
    if test $zeroize_count -gt 1
        echo "Error: Multiple zeroize entries detected in Cargo.toml"
        mv Cargo.toml.bak Cargo.toml
        exit 1
    end
    git add Cargo.toml
    git commit -m "Fix multiple zeroize detection in Cargo.toml (version 3.48)" --no-verify
    git push origin safe-pump-compat
    rm -f Cargo.toml.bak
else
    echo "Error: Cargo.toml not found"
    exit 1
end

# Validate utils repository
echo "Validating utils repository for zeroize..."
if ! cd /tmp/deps
    echo "Error: Cannot change to directory /tmp/deps"
    exit 1
end
if ! test -d utils
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
        reset_to_safe_pump_compat /tmp/deps/utils safe-pump-compat
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
    reset_to_safe_pump_compat /tmp/deps/utils safe-pump-compat
    cd $ORIGINAL_PWD
end

# Process solana repository
echo "Processing solana into /tmp/deps/solana..."
mkdir -p /tmp/deps
if ! cd /tmp/deps
    echo "Error: Cannot change to directory /tmp/deps"
    exit 1
end
if ! test -d solana
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
# Validate sdk/program/Cargo.toml
if test -f sdk/program/Cargo.toml
    if ! grep -q '^\[package\]' sdk/program/Cargo.toml || grep -q '<<<<<<< HEAD' sdk/program/Cargo.toml || grep -q '^\[dependencies\].*\[dependencies\]' sdk/program/Cargo.toml || grep -q '^\[dependencies\]\s*$' sdk/program/Cargo.toml
        echo "Warning: sdk/program/Cargo.toml is malformed or contains conflict markers, reinitializing"
        reinitialize_solana_cargo_toml sdk/program/Cargo.toml
        git checkout safe-pump-compat 2>/dev/null || git checkout -b safe-pump-compat
        git add sdk/program/Cargo.toml
        git commit -m "Reinitialize sdk/program/Cargo.toml to fix malformed state (version 3.48)" --no-verify
    end
else
    echo "Warning: sdk/program/Cargo.toml not found, reinitializing"
    reinitialize_solana_cargo_toml sdk/program/Cargo.toml
    git checkout safe-pump-compat 2>/dev/null || git checkout -b safe-pump-compat
    git add sdk/program/Cargo.toml
    git commit -m "Initialize sdk/program/Cargo.toml (version 3.48)" --no-verify
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
    resolve_rebase_conflicts /tmp/deps/solana sdk/program/Cargo.toml "$zeroize_source"
    if test $status -ne 0
        cd $ORIGINAL_PWD
        exit 1
    end
end
git checkout $solana_branch
git push --force
reset_to_safe_pump_compat /tmp/deps/solana safe-pump-compat
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
# Fix malformed Cargo.toml files
for cargo_toml in curve25519-dalek/Cargo.toml ed25519-dalek/Cargo.toml x25519-dalek/Cargo.toml
    if test -f $cargo_toml
        cp $cargo_toml $cargo_toml.bak
        awk '/^\[dependencies\]\s*$/{next} /^\s*\]\s*}/d {print}' $cargo_toml > $cargo_toml.tmp
        mv $cargo_toml.tmp $cargo_toml
    end
end
fix_zeroize_dependency /tmp/deps/curve25519-dalek curve25519-dalek/Cargo.toml "$zeroize_source"
fix_zeroize_dependency /tmp/deps/curve25519-dalek ed25519-dalek/Cargo.toml "$zeroize_source"
fix_zeroize_dependency /tmp/deps/curve25519-dalek x25519-dalek/Cargo.toml "$zeroize_source"
# Fix cached Cargo.toml files
set cached_dir /home/safe-pump/.cargo/git/checkouts/curve25519-dalek-4e97d8327ec85729/3adcba0
if test -d $cached_dir
    echo "Fixing cached curve25519-dalek Cargo.toml files..."
    for cargo_toml in $cached_dir/ed25519-dalek/Cargo.toml $cached_dir/x25519-dalek/Cargo.toml
        if test -f $cargo_toml
            cp $cargo_toml $cargo_toml.bak
            awk '/^\[dependencies\]\s*$/{next} /^\s*\]\s*}/d {print}' $cargo_toml > $cargo_toml.tmp
            mv $cargo_toml.tmp $cargo_toml
        end
    end
    fix_zeroize_dependency $cached_dir ed25519-dalek/Cargo.toml "$zeroize_source"
    fix_zeroize_dependency $cached_dir x25519-dalek/Cargo.toml "$zeroize_source"
end
git remote set-url origin ssh://git@github.com/hamkj7hpo/curve25519-dalek.git
git checkout safe-pump-compat-v2
git fetch origin
if git ls-remote --heads origin safe-pump-compat-v2 | grep -q safe-pump-compat-v2
    git rebase origin/safe-pump-compat-v2
    if test $status -ne 0
        resolve_rebase_conflicts /tmp/deps/curve25519-dalek Cargo.toml "$zeroize_source"
        if test $status -ne 0
            cd $ORIGINAL_PWD
            exit 1
        end
    end
    git push origin safe-pump-compat-v2 --force
else
    git push --set-upstream origin safe-pump-compat-v2
end
reset_to_safe_pump_compat /tmp/deps/curve25519-dalek safe-pump-compat-v2

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
    fix_tlv_account_resolution tlv-account-resolution/Cargo.toml
    git checkout $spl_branch
    git add tlv-account-resolution/Cargo.toml
    git commit -m "Fix solana-program and zeroize dependencies in spl-type-length-value/tlv-account-resolution (version 3.48)" --no-verify
    git push origin $spl_branch --force
    reset_to_safe_pump_compat /tmp/deps/spl-type-length-value safe-pump-compat
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
    fix_tlv_account_resolution tlv-account-resolution/Cargo.toml
    git checkout $spl_branch
    git add tlv-account-resolution/Cargo.toml
    git commit -m "Initialize tlv-account-resolution/Cargo.toml with correct dependencies (version 3.48)" --no-verify
    git push origin $spl_branch --force
    reset_to_safe_pump_compat /tmp/deps/spl-type-length-value safe-pump-compat
end
cd $ORIGINAL_PWD

# Clean up untracked .bak and .cargo-ok files
echo "Cleaning up untracked .bak and .cargo-ok files..."
find . -name "*.bak" -delete 2>/dev/null || echo "Warning: Failed to delete some .bak files"
find /tmp/deps -name "*.bak" -delete 2>/dev/null || echo "Warning: Failed to delete some .bak files in /tmp/deps"
find . -name ".cargo-ok" -delete 2>/dev/null || echo "Warning: Failed to delete some .cargo-ok files"
find /tmp/deps -name ".cargo-ok" -delete 2>/dev/null || echo "Warning: Failed to delete some .cargo-ok files in /tmp/deps"
find /home/safe-pump/.cargo -name ".cargo-ok" -delete 2>/dev/null || echo "Warning: Failed to delete some .cargo-ok files in /home/safe-pump/.cargo"

# Clean and build
echo "Cleaning and building the project..."
cargo clean
cargo build --locked
if test $status -ne 0
    echo "Build failed, check errors above"
    cargo build --locked --verbose
    exit 1
end

echo "setup.fish version 3.48 completed"
