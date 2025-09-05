#!/usr/bin/env fish

set -l repos \
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
    "raydium-cp-swap"

set -l tmp_dir /tmp/deps
set -l project_dir /var/www/html/program/safe_pump
set -l branch safe-pump-compat

# Ensure git is configured
echo "Checking git configuration..."
if not git config user.name >/dev/null || not git config user.email >/dev/null
    echo "Git user.name or user.email not set. Please configure git:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
    exit 1
end

# Create temporary directory if it doesn't exist
mkdir -p $tmp_dir

# Step 1: Clone repositories and ensure safe-pump-compat branch
for repo in $repos
    set -l repo_url https://github.com/hamkj7hpo/$repo.git
    set -l target_dir $tmp_dir/$repo
    echo "Processing $repo into $target_dir..."

    # Clone or update repository
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
    end
    cd -
end

# Step 2: Patch solana-program in each repository
# Patch solana/sdk/program/Cargo.toml
set -l solana_toml $tmp_dir/solana/sdk/program/Cargo.toml
if test -f $solana_toml
    echo "Patching $solana_toml for curve25519-dalek..."
    sed -i '/curve25519-dalek/d' $solana_toml
    sed -i '/zeroize/d' $solana_toml
    sed -i '/\[dependencies\]/a curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2", package = "curve25519-dalek", features = ["serde"] }' $solana_toml
    sed -i '/\[dependencies\]/a zeroize = "1.3.0"' $solana_toml
    cd $tmp_dir/solana
    git add sdk/program/Cargo.toml
    git commit -m "Update solana-program to use curve25519-dalek from safe-pump-compat-v2 and zeroize 1.3.0" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to solana"
        exit 1
    end
    set solana_rev (git rev-parse HEAD)
    cd -
else
    echo "Error: $solana_toml not found"
    exit 1
end

# Patch spl-pod/Cargo.toml
set -l spl_pod_toml $tmp_dir/spl-pod/Cargo.toml
if test -f $spl_pod_toml
    echo "Patching $spl_pod_toml for solana-program..."
    sed -i '/solana-program/d' $spl_pod_toml
    sed -i '/zeroize/d' $spl_pod_toml
    sed -i '/solana-zk-sdk/d' $spl_pod_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $spl_pod_toml
    sed -i '/\[dependencies\]/a solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat", package = "solana-zk-sdk" }' $spl_pod_toml
    sed -i '/\[dependencies\]/a zeroize = "1.3.0"' $spl_pod_toml
    cd $tmp_dir/spl-pod
    git add Cargo.toml
    git commit -m "Update solana-program, solana-zk-sdk, and zeroize to safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to spl-pod"
        exit 1
    end
    set pod_rev (git rev-parse HEAD)
    cd -
else
    echo "Error: $spl_pod_toml not found"
    exit 1
end

# Patch anchor/spl/Cargo.toml
set -l anchor_spl_toml $tmp_dir/anchor/spl/Cargo.toml
if test -f $anchor_spl_toml
    echo "Patching $anchor_spl_toml for solana-program..."
    sed -i '/solana-program/d' $anchor_spl_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $anchor_spl_toml
    cd $tmp_dir/anchor
    git add spl/Cargo.toml
    git commit -m "Update anchor-spl to use solana-program from safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to anchor"
        exit 1
    end
    cd -
else
    echo "Error: $anchor_spl_toml not found"
    exit 1
end

# Patch zk-elgamal-proof/Cargo.toml
set -l zk_sdk_toml $tmp_dir/zk-elgamal-proof/Cargo.toml
if test -f $zk_sdk_toml
    echo "Patching $zk_sdk_toml for solana-program and zeroize..."
    sed -i '/solana-program/d' $zk_sdk_toml
    sed -i '/zeroize/d' $zk_sdk_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $zk_sdk_toml
    sed -i '/\[dependencies\]/a zeroize = "1.3.0"' $zk_sdk_toml
    cd $tmp_dir/zk-elgamal-proof
    git add Cargo.toml
    git commit -m "Update solana-zk-sdk and zeroize to 1.3.0 for safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to zk-elgamal-proof"
        exit 1
    end
    set zk_rev (git rev-parse HEAD)
    cd -
else
    echo "Error: $zk_sdk_toml not found"
    exit 1
end

# Patch token-2022/Cargo.toml
set -l token_2022_toml $tmp_dir/token-2022/Cargo.toml
if test -f $token_2022_toml
    echo "Patching $token_2022_toml for solana-zk-sdk and solana-program..."
    sed -i '/solana-zk-sdk/d' $token_2022_toml
    sed -i '/solana-program/d' $token_2022_toml
    sed -i '/zeroize/d' $token_2022_toml
    sed -i '/\[dependencies\]/a solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat", package = "solana-zk-sdk" }' $token_2022_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $token_2022_toml
    sed -i '/\[dependencies\]/a zeroize = "1.3.0"' $token_2022_toml
    cd $tmp_dir/token-2022
    git add Cargo.toml
    git commit -m "Update solana-zk-sdk, solana-program, and zeroize to safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to token-2022"
        exit 1
    end
    set token_rev (git rev-parse HEAD)
    cd -
else
    echo "Error: $token_2022_toml not found"
    exit 1
end

# Patch associated-token-account/Cargo.toml
set -l assoc_token_toml $tmp_dir/associated-token-account/Cargo.toml
if test -f $assoc_token_toml
    echo "Patching $assoc_token_toml for solana-program..."
    sed -i '/solana-program/d' $assoc_token_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $assoc_token_toml
    cd $tmp_dir/associated-token-account
    git add Cargo.toml
    git commit -m "Update solana-program to safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to associated-token-account"
        exit 1
    end
    cd -
else
    echo "Error: $assoc_token_toml not found"
    exit 1
end

# Patch solana-program-library/libraries/discriminator/Cargo.toml and handle uncommitted changes
set -l spl_discriminator_toml $tmp_dir/solana-program-library/libraries/discriminator/Cargo.toml
if test -f $spl_discriminator_toml
    echo "Patching $spl_discriminator_toml for solana-program..."
    sed -i '/solana-program/d' $spl_discriminator_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $spl_discriminator_toml
    cd $tmp_dir/solana-program-library
    git add libraries/discriminator/Cargo.toml
    git add program-error/Cargo.toml
    git commit -m "Update spl-discriminator to use solana-program from safe-pump-compat branch and commit program-error changes" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to solana-program-library"
        exit 1
    end
    cd -
else
    echo "Error: $spl_discriminator_toml not found"
    exit 1
end

# Patch spl-type-length-value/Cargo.toml
set -l spl_tlv_toml $tmp_dir/spl-type-length-value/Cargo.toml
if test -f $spl_tlv_toml
    echo "Patching $spl_tlv_toml for solana-program..."
    sed -i '/solana-program/d' $spl_tlv_toml
    sed -i '/spl-pod/d' $spl_tlv_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $spl_tlv_toml
    sed -i '/\[dependencies\]/a spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat", package = "spl-pod" }' $spl_tlv_toml
    cd $tmp_dir/spl-type-length-value
    git add Cargo.toml
    git commit -m "Update spl-tlv-account-resolution to use solana-program and spl-pod from safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to spl-type-length-value"
        exit 1
    end
    cd -
else
    echo "Error: $spl_tlv_toml not found"
    exit 1
end

# Patch token-group/Cargo.toml
set -l token_group_toml $tmp_dir/token-group/Cargo.toml
if test -f $token_group_toml
    echo "Patching $token_group_toml for solana-program..."
    sed -i '/solana-program/d' $token_group_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $token_group_toml
    cd $tmp_dir/token-group
    git add Cargo.toml
    git commit -m "Update solana-program to safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to token-group"
        exit 1
    end
    cd -
else
    echo "Error: $token_group_toml not found"
    exit 1
end

# Patch token-metadata/Cargo.toml
set -l token_metadata_toml $tmp_dir/token-metadata/Cargo.toml
if test -f $token_metadata_toml
    echo "Patching $token_metadata_toml for solana-program..."
    sed -i '/solana-program/d' $token_metadata_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $token_metadata_toml
    cd $tmp_dir/token-metadata
    git add Cargo.toml
    git commit -m "Update solana-program to safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to token-metadata"
        exit 1
    end
    cd -
else
    echo "Error: $token_metadata_toml not found"
    exit 1
end

# Patch transfer-hook/Cargo.toml
set -l transfer_hook_toml $tmp_dir/transfer-hook/Cargo.toml
if test -f $transfer_hook_toml
    echo "Patching $transfer_hook_toml for solana-program..."
    sed -i '/solana-program/d' $transfer_hook_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $transfer_hook_toml
    cd $tmp_dir/transfer-hook
    git add Cargo.toml
    git commit -m "Update solana-program to safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to transfer-hook"
        exit 1
    end
    cd -
else
    echo "Error: $transfer_hook_toml not found"
    exit 1
end

# Patch memo/Cargo.toml
set -l memo_toml $tmp_dir/memo/Cargo.toml
if test -f $memo_toml
    echo "Patching $memo_toml for solana-program..."
    sed -i '/solana-program/d' $memo_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $memo_toml
    cd $tmp_dir/memo
    git add Cargo.toml
    git commit -m "Update solana-program to safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to memo"
        exit 1
    end
    cd -
else
    echo "Error: $memo_toml not found"
    exit 1
end

# Patch raydium-cp-swap/Cargo.toml (fix syntax error)
set -l raydium_toml $tmp_dir/raydium-cp-swap/Cargo.toml
if test -f $raydium_toml
    echo "Patching $raydium_toml for solana-program and fixing syntax..."
    sed -i '/\[profile.release\]/d' $raydium_toml
    sed -i '/overflow-checks =/d' $raydium_toml
    sed -i '/lto =/d' $raydium_toml
    sed -i '/codegen-units =/d' $raydium_toml
    sed -i '/\[profile.release.build-override\]/d' $raydium_toml
    sed -i '/opt-level =/d' $raydium_toml
    sed -i '/incremental =/d' $raydium_toml
    sed -i '/codegen-units =/d' $raydium_toml
    sed -i '/codegen-units = 1\[patch.crates-io\]/d' $raydium_toml
    sed -i '/solana-program/d' $raydium_toml
    sed -i '/zeroize/d' $raydium_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $raydium_toml
    sed -i '/\[dependencies\]/a zeroize = "1.3.0"' $raydium_toml
    echo -e "\n[profile.release]\noverflow-checks = true\nlto = \"fat\"\ncodegen-units = 1" >> $raydium_toml
    echo -e "\n[profile.release.build-override]\nopt-level = 3\nincremental = false\ncodegen-units = 1" >> $raydium_toml
    cd $tmp_dir/raydium-cp-swap
    git add Cargo.toml
    git commit -m "Fix syntax in Cargo.toml and update solana-program to safe-pump-compat branch" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to raydium-cp-swap"
        exit 1
    end
    cd -
else
    echo "Error: $raydium_toml not found"
    exit 1
end

# Patch raydium-cp-swap/programs/cp-swap/Cargo.toml for solana-program, solana-zk-sdk, and zeroize
set -l raydium_program_toml $tmp_dir/raydium-cp-swap/programs/cp-swap/Cargo.toml
if test -f $raydium_program_toml
    echo "Patching $raydium_program_toml for solana-program, solana-zk-sdk, and zeroize..."
    sed -i '/solana-program/d' $raydium_program_toml
    sed -i '/solana-zk-sdk/d' $raydium_program_toml
    sed -i '/zeroize/d' $raydium_program_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $raydium_program_toml
    sed -i '/\[dependencies\]/a solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat", package = "solana-zk-sdk" }' $raydium_program_toml
    sed -i '/\[dependencies\]/a zeroize = "1.3.0"' $raydium_program_toml
    cd $tmp_dir/raydium-cp-swap
    git add programs/cp-swap/Cargo.toml
    git commit -m "Update solana-program, solana-zk-sdk, and zeroize to 1.3.0 in raydium-cp-swap to resolve dependency conflict" || true
    git push origin $branch
    if test $status -ne 0
        echo "Failed to push changes to raydium-cp-swap"
        exit 1
    end
    set raydium_rev (git rev-parse HEAD)
    cd -
else
    echo "Error: $raydium_program_toml not found"
    exit 1
end

# Step 3: Update safe_pump Cargo.toml and handle uncommitted changes
set -l project_toml $project_dir/Cargo.toml
if test -f $project_toml
    echo "Patching $project_toml for dependencies..."
    # Update dependencies
    sed -i '/anchor-lang =/d' $project_toml
    sed -i '/solana-program =/d' $project_toml
    sed -i '/spl-memo =/d' $project_toml
    sed -i '/spl-token-group-interface =/d' $project_toml
    sed -i '/spl-token-metadata-interface =/d' $project_toml
    sed -i '/spl-transfer-hook-interface =/d' $project_toml
    sed -i '/spl-type-length-value =/d' $project_toml
    sed -i '/raydium-cp-swap =/d' $project_toml
    sed -i '/anchor-spl =/d' $project_toml
    sed -i '/spl-pod =/d' $project_toml
    sed -i '/solana-zk-sdk =/d' $project_toml
    sed -i '/spl-token-2022 =/d' $project_toml
    sed -i '/spl-associated-token-account =/d' $project_toml
    sed -i '/spl-discriminator =/d' $project_toml
    sed -i '/spl-tlv-account-resolution =/d' $project_toml
    sed -i '/zeroize =/d' $project_toml
    sed -i '/solana-sdk =/d' $project_toml
    sed -i '/spki =/d' $project_toml
    sed -i '/curve25519-dalek =/d' $project_toml
    sed -i '/\[dependencies\]/a anchor-lang = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", features = ["init-if-needed"] }' $project_toml
    sed -i '/\[dependencies\]/a solana-program = { git = "https://github.com/hamkj7hpo/solana.git", branch = "safe-pump-compat", package = "solana-program" }' $project_toml
    sed -i '/\[dependencies\]/a spl-memo = { git = "https://github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", package = "spl-memo", version = "6.0.0" }' $project_toml
    sed -i '/\[dependencies\]/a spl-token-group-interface = { git = "https://github.com/hamkj7hpo/token-group.git", branch = "safe-pump-compat", package = "spl-token-group-interface" }' $project_toml
    sed -i '/\[dependencies\]/a spl-token-metadata-interface = { git = "https://github.com/hamkj7hpo/token-metadata.git", branch = "safe-pump-compat", package = "spl-token-metadata-interface" }' $project_toml
    sed -i '/\[dependencies\]/a spl-transfer-hook-interface = { git = "https://github.com/hamkj7hpo/transfer-hook.git", branch = "safe-pump-compat", package = "spl-transfer-hook-interface" }' $project_toml
    sed -i '/\[dependencies\]/a spl-type-length-value = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat", package = "spl-type-length-value" }' $project_toml
    sed -i "/\[dependencies\]/a raydium-cp-swap = { git = \"https://github.com/hamkj7hpo/raydium-cp-swap.git\", rev = \"$raydium_rev\", package = \"raydium-cp-swap\", default-features = false }" $project_toml
    sed -i '/\[dependencies\]/a anchor-spl = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", default-features = false }' $project_toml
    sed -i '/\[dependencies\]/a spl-pod = { git = "https://github.com/hamkj7hpo/spl-pod.git", branch = "safe-pump-compat", default-features = false }' $project_toml
    sed -i '/\[dependencies\]/a solana-zk-sdk = { git = "https://github.com/hamkj7hpo/zk-elgamal-proof.git", branch = "safe-pump-compat", package = "solana-zk-sdk" }' $project_toml
    sed -i '/\[dependencies\]/a spl-token-2022 = { git = "https://github.com/hamkj7hpo/token-2022.git", branch = "safe-pump-compat", package = "spl-token-2022", default-features = false }' $project_toml
    sed -i '/\[dependencies\]/a spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat", default-features = false }' $project_toml
    sed -i '/\[dependencies\]/a spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat", package = "spl-discriminator" }' $project_toml
    sed -i '/\[dependencies\]/a spl-tlv-account-resolution = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat", package = "spl-tlv-account-resolution" }' $project_toml
    sed -i '/\[dependencies\]/a zeroize = "1.3.0"' $project_toml
    # Update patch section
    sed -i '/anchor-spl =.*}/d' $project_toml
    sed -i '/spl-pod =.*}/d' $project_toml
    sed -i '/solana-zk-sdk =.*}/d' $project_toml
    sed -i '/spl-token-2022 =.*}/d' $project_toml
    sed -i '/spl-associated-token-account =.*}/d' $project_toml
    sed -i '/spl-discriminator =.*}/d' $project_toml
    sed -i '/spl-tlv-account-resolution =.*}/d' $project_toml
    sed -i '/solana-program =.*}/d' $project_toml
    sed -i '/spl-memo =.*}/d' $project_toml
    sed -i '/spl-type-length-value =.*}/d' $project_toml
    sed -i '/spki =.*}/d' $project_toml
    sed -i '/curve25519-dalek =.*}/d' $project_toml
    sed -i '/solana-sdk =.*}/d' $project_toml
    sed -i '/\[patch.crates-io\]/a anchor-spl = { git = "https://github.com/hamkj7hpo/anchor.git", branch = "safe-pump-compat", default-features = false }' $project_toml
    sed -i "/\[patch.crates-io\]/a spl-pod = { git = \"https://github.com/hamkj7hpo/spl-pod.git\", rev = \"$pod_rev\", default-features = false }" $project_toml
    sed -i "/\[patch.crates-io\]/a solana-zk-sdk = { git = \"https://github.com/hamkj7hpo/zk-elgamal-proof.git\", rev = \"$zk_rev\", package = \"solana-zk-sdk\" }" $project_toml
    sed -i "/\[patch.crates-io\]/a spl-token-2022 = { git = \"https://github.com/hamkj7hpo/token-2022.git\", rev = \"$token_rev\", package = \"spl-token-2022\", default-features = false }" $project_toml
    sed -i '/\[patch.crates-io\]/a spl-associated-token-account = { git = "https://github.com/hamkj7hpo/associated-token-account.git", branch = "safe-pump-compat", default-features = false }' $project_toml
    sed -i '/\[patch.crates-io\]/a spl-discriminator = { git = "https://github.com/hamkj7hpo/solana-program-library.git", branch = "safe-pump-compat", package = "spl-discriminator" }' $project_toml
    sed -i '/\[patch.crates-io\]/a spl-tlv-account-resolution = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat", package = "spl-tlv-account-resolution" }' $project_toml
    sed -i "/\[patch.crates-io\]/a solana-program = { git = \"https://github.com/hamkj7hpo/solana.git\", rev = \"$solana_rev\", package = \"solana-program\" }" $project_toml
    sed -i '/\[patch.crates-io\]/a spl-memo = { git = "https://github.com/hamkj7hpo/memo.git", branch = "safe-pump-compat", package = "spl-memo", version = "6.0.0" }' $project_toml
    sed -i '/\[patch.crates-io\]/a spl-type-length-value = { git = "https://github.com/hamkj7hpo/spl-type-length-value.git", branch = "safe-pump-compat", package = "spl-type-length-value" }' $project_toml
    sed -i '/\[patch.crates-io\]/a spki = { git = "https://github.com/hamkj7hpo/formats.git", branch = "safe-pump-compat", package = "spki" }' $project_toml
    sed -i '/\[patch.crates-io\]/a curve25519-dalek = { git = "https://github.com/hamkj7hpo/curve25519-dalek.git", branch = "safe-pump-compat-v2" }' $project_toml
    # Commit and push changes, including uncommitted setup.fish
    cd $project_dir
    git add Cargo.toml setup.fish
    git commit -m "Update dependencies to use safe-pump-compat branches for zeroize compatibility and commit setup.fish changes" || true
    git push origin main
    if test $status -ne 0
        echo "Failed to push changes to safe_pump"
        exit 1
    end
    cd -
else
    echo "Error: $project_toml not found"
    exit 1
end

# Step 4: Clean and build
echo "Cleaning and building project..."
cd $project_dir
rm -rf Cargo.lock target
cargo clean
cargo update -v
cargo build
if test $status -eq 0
    echo "Build successful!"
else
    echo "Build failed, check output for errors."
    # Generate diagnostic report
    echo "Generating diagnostic report..."
    cargo tree --invert curve25519-dalek > /tmp/safe_pump_diagnostic_report.txt
    cargo tree >> /tmp/safe_pump_diagnostic_report.txt
    echo "Diagnostic report saved to /tmp/safe_pump_diagnostic_report.txt"
    exit 1
end
