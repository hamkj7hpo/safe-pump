use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::AssociatedToken,
    token::{self, Mint, Token, TokenAccount, MintTo, Transfer, Burn},
};
use solana_program::{program::invoke, clock::Clock};
use raydium_cp_swap::cpi::{accounts::CreatePool, create_pool};
use raydium_cp_swap::instruction::SwapBaseInput;

declare_id!("AymD4HzxTN2SK6UDrCcXD2uAFk4RptvQKzMT5P9GSr32");

const GLOBAL_TAX: u64 = 100; // 1% in basis points
const GLOBAL_LP_TAX: u64 = 50; // 0.5% in basis points
const SWAPPER_REWARD_TAX: u64 = 40; // 0.4% in basis points
const BADGE_REWARD_TAX: u64 = 10; // 0.1% in basis points
const MAX_BADGE_HOLDERS: usize = 100; // Limit to 100 badge holders
const BUY_SWAPS_FOR_BADGE: u64 = 1000; // Trigger badge after 1000 buy swaps
const ANTI_SNIPER_COOLDOWN: i64 = 120; // 120 seconds, applied only on bonding
const MAX_SUPPLY: u64 = 1_000_000_000_000_000_000; // 1T tokens (9 decimals)
const MAX_BUY_PERCENT: u64 = 10; // 0.1% of supply (initial, overridden by dynamic cap)
const MAX_SELL_PERCENT: u64 = 100; // 1% of holdings per 24 hours
const SELL_COOLDOWN: i64 = 86_400; // 24 hours in seconds
const REWARD_DISTRIBUTION_PERIOD: i64 = 86_400; // 24 hours
const POOL_SOL_AMOUNT: u64 = 1_000_000_000; // 1 SOL in lamports
const INITIAL_VAULT_AMOUNT: u64 = 100_000_000_000; // 100 SafePump tokens (9 decimals)
const MAX_FRIENDS_WALLETS: usize = 4; // Max 4 friends
const MAX_ALLOCATION_PERCENT: u64 = 5100; // 51% max for deployer + friends
const LIQUIDITY_THRESHOLDS: [u64; 5] = [
    5_000_000_000,    // $5,000 in lamports (~5 SOL at $100/SOL)
    10_000_000_000,   // $10,000
    15_000_000_000,   // $15,000
    20_000_000_000,   // $20,000
    24_000_000_000,   // $24,000
];
const BUY_CAP_PERCENTAGES: [u64; 5] = [10, 15, 20, 22, 25]; // 0.1%, 0.15%, 0.2%, 0.22%, 0.25% in basis points
const LAMPORTS_PER_SOL: u64 = 1_000_000_000;
const MARKET_CAP_THRESHOLD_START: u64 = 24_000_000_000; // $24,000 in lamports
const MARKET_CAP_THRESHOLD_END: u64 = 10_000_000_000_000_000; // $10M in lamports
const BUY_CAP_START: u64 = 25; // 0.25% at $24,000
const BUY_CAP_END: u64 = 100; // 1% at $10M

#[program]
pub mod safe_pump {
    use super::*;

    pub fn initialize_contract(
        ctx: Context<InitializeContract>,
        total_supply: u64,
        treasury_wallet: Pubkey,
        burn_percentage: u8,
        lp_percentage: u8,
        friends_wallets: Vec<Pubkey>,
        friends_amounts: Vec<u64>,
        deployer_amount: u64,
    ) -> Result<()> {
        require!(total_supply <= MAX_SUPPLY, SafePumpError::InvalidSupply);
        require!(burn_percentage <= 100, SafePumpError::InvalidBurnPercentage);
        require!(lp_percentage <= 100, SafePumpError::InvalidLpPercentage);
        require!(
            friends_wallets.len() <= MAX_FRIENDS_WALLETS,
            SafePumpError::InvalidFriendsAllocation
        );
        require!(
            friends_wallets.len() == friends_amounts.len(),
            SafePumpError::InvalidFriendsAllocation
        );

        // Validate allocation: Up to 51% for deployer + friends
        let total_allocation = deployer_amount
            .checked_add(friends_amounts.iter().sum::<u64>())
            .ok_or(SafePumpError::MathError)?;
        let allocation_percent = (total_allocation * 10_000)
            .checked_div(total_supply)
            .ok_or(SafePumpError::MathError)?; // In basis points
        require!(
            allocation_percent <= MAX_ALLOCATION_PERCENT,
            SafePumpError::InvalidFriendsAllocation
        );
        require!(
            lp_percentage == 100 - (allocation_percent / 100),
            SafePumpError::InvalidLpPercentage
        );

        let contract = &mut ctx.accounts.contract;
        require!(!contract.is_initialized, SafePumpError::AlreadyInitialized);

        contract.is_initialized = true;
        contract.total_supply = total_supply;
        contract.treasury_wallet = treasury_wallet;
        contract.swap_count = 0;
        contract.total_swapped = 0;
        contract.bond_timestamp = 0;
        contract.vault_sol_balance = POOL_SOL_AMOUNT;
        contract.vault_token_balance = (total_supply * lp_percentage as u64) / 100;
        contract.burned_tokens = 0;
        contract.burn_percentage = burn_percentage;
        contract.buy_cap_percentage = BUY_CAP_PERCENTAGES[0]; // Start at 0.1%
        contract.sell_lock_active = true; // Lock sells initially
        contract.liquidity_threshold_index = 0; // Start at first step
        contract.friends_wallets = {
            let mut arr = [Pubkey::default(); MAX_FRIENDS_WALLETS];
            for (i, &wallet) in friends_wallets.iter().enumerate() {
                arr[i] = wallet;
            }
            arr
        };
        contract.friends_amounts = {
            let mut arr = [0u64; MAX_FRIENDS_WALLETS];
            for (i, &amount) in friends_amounts.iter().enumerate() {
                arr[i] = amount;
            }
            arr
        };
        contract.deployer_amount = deployer_amount;
        contract.bump = ctx.bumps.contract;

        // Mint allocation to deployer and friends
        let allocation_after_burn = if burn_percentage > 0 {
            let burn_amount = total_allocation * burn_percentage as u64 / 100;
            total_allocation - burn_amount
        } else {
            total_allocation
        };
        let deployer_allocation = (deployer_amount * (100 - burn_percentage as u64)) / 100;

        // Mint to deployer
        token::mint_to(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                MintTo {
                    mint: ctx.accounts.mint.to_account_info(),
                    to: ctx.accounts.deployer_ata.to_account_info(),
                    authority: ctx.accounts.contract.to_account_info(),
                },
                &[&[b"contract", ctx.accounts.owner.key().as_ref(), &[contract.bump]]],
            ),
            deployer_allocation,
        )?;
        msg!("Minted {} SafePump tokens to deployer", deployer_allocation);

        // Mint to friends
        for (i, (wallet, &amount)) in friends_wallets.iter().zip(friends_amounts.iter()).enumerate() {
            let friend_allocation = (amount * (100 - burn_percentage as u64)) / 100;
            let friend_ata = get_associated_token_address(wallet, &ctx.accounts.mint.key());
            invoke(
                &spl_associated_token_account::instruction::create_associated_token_account(
                    &ctx.accounts.owner.key(),
                    wallet,
                    &ctx.accounts.mint.key(),
                    &spl_token::ID,
                ),
                &[
                    ctx.accounts.owner.to_account_info(),
                    friend_ata.to_account_info(),
                    ctx.accounts.token_program.to_account_info(),
                    ctx.accounts.system_program.to_account_info(),
                    ctx.accounts.mint.to_account_info(),
                ],
            )?;
            token::mint_to(
                CpiContext::new_with_signer(
                    ctx.accounts.token_program.to_account_info(),
                    MintTo {
                        mint: ctx.accounts.mint.to_account_info(),
                        to: friend_ata.to_account_info(),
                        authority: ctx.accounts.contract.to_account_info(),
                    },
                    &[&[b"contract", ctx.accounts.owner.key().as_ref(), &[contract.bump]]],
                ),
                friend_allocation,
            )?;
            msg!("Minted {} tokens to friend[{}]: {}", friend_allocation, i, wallet);
        }

        // Mint lp_percentage% to token0_vault
        let pool_token_amount = (total_supply * lp_percentage as u64) / 100;
        token::mint_to(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                MintTo {
                    mint: ctx.accounts.mint.to_account_info(),
                    to: ctx.accounts.vault.to_account_info(),
                    authority: ctx.accounts.contract.to_account_info(),
                },
                &[&[b"contract", ctx.accounts.owner.key().as_ref(), &[contract.bump]]],
            ),
            pool_token_amount,
        )?;
        msg!("Minted {} tokens to vault", pool_token_amount);

        // Burn tokens from vault if specified
        if burn_percentage > 0 {
            let burn_amount = pool_token_amount * burn_percentage as u64 / 100;
            token::burn(
                CpiContext::new(
                    ctx.accounts.token_program.to_account_info(),
                    Burn {
                        mint: ctx.accounts.mint.to_account_info(),
                        from: ctx.accounts.vault.to_account_info(),
                        authority: ctx.accounts.owner.to_account_info(),
                    },
                ),
                burn_amount,
            )?;
            contract.vault_token_balance -= burn_amount;
            contract.burned_tokens = burn_amount;
            msg!("Burned {}% of vault tokens: {}", burn_percentage, burn_amount);
        }

        // Initialize badge vault with 100 SafePump tokens
        token::mint_to(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                MintTo {
                    mint: ctx.accounts.mint.to_account_info(),
                    to: ctx.accounts.badge_vault.to_account_info(),
                    authority: ctx.accounts.contract.to_account_info(),
                },
                &[&[b"contract", ctx.accounts.owner.key().as_ref(), &[contract.bump]]],
            ),
            INITIAL_VAULT_AMOUNT,
        )?;

        // Initialize swap rewards vault with 100 SafePump tokens
        token::mint_to(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                MintTo {
                    mint: ctx.accounts.mint.to_account_info(),
                    to: ctx.accounts.swap_rewards_vault.to_account_info(),
                    authority: ctx.accounts.contract.to_account_info(),
                },
                &[&[b"contract", ctx.accounts.owner.key().as_ref(), &[contract.bump]]],
            ),
            INITIAL_VAULT_AMOUNT,
        )?;

        // Fund WSOL ATA with 1 SOL
        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.owner_wsol_ata.to_account_info(),
                    to: ctx.accounts.sol_vault.to_account_info(),
                    authority: ctx.accounts.owner.to_account_info(),
                },
            ),
            POOL_SOL_AMOUNT,
        )?;
        msg!("Transferred {} lamports to vault SOL account", POOL_SOL_AMOUNT);

        // Bond to Raydium CPMM
        let cpi_accounts = CreatePool {
            pool_state: ctx.accounts.pool_state.to_account_info(),
            token0_vault: ctx.accounts.vault.to_account_info(),
            token1_vault: ctx.accounts.sol_vault.to_account_info(),
            lp_mint: ctx.accounts.lp_mint.to_account_info(),
            amm_config: ctx.accounts.amm_config.to_account_info(),
            authority: ctx.accounts.authority.to_account_info(),
            observation_state: ctx.accounts.observation_state.to_account_info(),
            create_pool_fee: ctx.accounts.create_pool_fee.to_account_info(),
            token_program: ctx.accounts.token_program.to_account_info(),
            system_program: ctx.accounts.system_program.to_account_info(),
            rent: ctx.accounts.rent.to_account_info(),
        };
        let cpi_program = ctx.accounts.raydium_program.to_account_info();
        create_pool(
            CpiContext::new_with_signer(
                cpi_program,
                cpi_accounts,
                &[&[b"contract", ctx.accounts.owner.key().as_ref(), &[contract.bump]]],
            ),
        )?;

        // Burn LP tokens if specified
        if burn_percentage > 0 {
            let burn_amount = ctx.accounts.lp_vault.amount * burn_percentage as u64 / 100;
            token::burn(
                CpiContext::new(
                    ctx.accounts.token_program.to_account_info(),
                    Burn {
                        mint: ctx.accounts.lp_mint.to_account_info(),
                        from: ctx.accounts.lp_vault.to_account_info(),
                        authority: ctx.accounts.owner.to_account_info(),
                    },
                ),
                burn_amount,
            )?;
            msg!("Burned {}% of LP tokens: {}", burn_percentage, burn_amount);
        }

        contract.bond_timestamp = Clock::get()?.unix_timestamp;
        msg!(
            "Initialized SafePump contract: supply={}, treasury={}, lp_percentage={}, bonded to Raydium",
            total_supply,
            treasury_wallet,
            lp_percentage
        );
        Ok(())
    }

    pub fn initialize_badge_holders(ctx: Context<InitializeBadgeHolders>) -> Result<()> {
        let badge_holders = &mut ctx.accounts.badge_holders;
        badge_holders.holders = [Pubkey::default(); MAX_BADGE_HOLDERS];
        badge_holders.buy_swap_count = [(Pubkey::default(), 0); MAX_BADGE_HOLDERS];
        badge_holders.holder_count = 0;
        badge_holders.bump = ctx.bumps.badge_holders;
        msg!("Initialized badge holders for mint: {}", ctx.accounts.mint.key());
        Ok(())
    }

    pub fn register_meme_coin(ctx: Context<RegisterMemeCoin>, program_id: Pubkey) -> Result<()> {
        let registry = &mut ctx.accounts.meme_coin_registry;
        let deployer = ctx.accounts.deployer.key();

        require!(
            !registry.meme_coins.iter().any(|(pid, _)| *pid == program_id),
            SafePumpError::MemeCoinAlreadyRegistered
        );

        registry.meme_coins[registry.meme_coin_count as usize] = (program_id, deployer);
        registry.meme_coin_count += 1;
        registry.bump = ctx.bumps.meme_coin_registry;
        msg!("Registered meme coin: program_id={}, deployer={}", program_id, deployer);
        Ok(())
    }

    pub fn global_tax_swap(ctx: Context<GlobalTaxSwap>, amount: u64, is_buy: bool, meme_program_id: Pubkey) -> Result<()> {
        let contract = &mut ctx.accounts.contract;
        let badge_holders = &mut ctx.accounts.badge_holders;
        let user_swap_data = &mut ctx.accounts.user_swap_data;
        let clock = Clock::get()?;

        require!(contract.is_initialized, SafePumpError::NotInitialized);

        if contract.swap_count == 0 {
            require!(
                clock.unix_timestamp - contract.bond_timestamp >= ANTI_SNIPER_COOLDOWN,
                SafePumpError::AntiSniperCooldown
            );
        }

        let registry = &ctx.accounts.meme_coin_registry;
        let is_safepump_swap = meme_program_id == ctx.accounts.safepump_mint.key();
        require!(
            is_safepump_swap || registry.meme_coins.iter().any(|(pid, _)| *pid == meme_program_id),
            SafePumpError::MemeCoinNotRegistered
        );

        // Update buy cap based on liquidity and market cap
        let pool_sol_amount = ctx.accounts.sol_vault.amount; // SOL balance in lamports
        let pool_token_amount = ctx.accounts.vault.amount; // Token balance in lamports
        let current_liquidity = pool_sol_amount; // SOL balance in lamports

        // Update buy cap based on liquidity thresholds
        let current_index = contract.liquidity_threshold_index as usize;
        if current_index < LIQUIDITY_THRESHOLDS.len() - 1 && current_liquidity >= LIQUIDITY_THRESHOLDS[current_index + 1] {
            contract.liquidity_threshold_index += 1;
            contract.buy_cap_percentage = BUY_CAP_PERCENTAGES[contract.liquidity_threshold_index as usize];
            msg!("Updated buy cap to {} bp at liquidity {} lamports", contract.buy_cap_percentage, current_liquidity);
        }

        // Estimate market cap: (pool_sol_amount / pool_token_amount) * total_supply
        let market_cap = if pool_token_amount > 0 {
            (pool_sol_amount as u128)
                .checked_mul(contract.total_supply as u128)
                .ok_or(SafePumpError::MathError)?
                .checked_div(pool_token_amount as u128)
                .ok_or(SafePumpError::MathError)?
                as u64
        } else {
            0
        };

        // Scale buy cap from 0.25% to 1% between $24,000 and $10M market cap
        if market_cap > MARKET_CAP_THRESHOLD_START {
            let market_cap_range = MARKET_CAP_THRESHOLD_END - MARKET_CAP_THRESHOLD_START;
            let buy_cap_range = BUY_CAP_END - BUY_CAP_START;
            let market_cap_progress = market_cap.saturating_sub(MARKET_CAP_THRESHOLD_START);
            let buy_cap_increase = (market_cap_progress as u128)
                .checked_mul(buy_cap_range as u128)
                .ok_or(SafePumpError::MathError)?
                .checked_div(market_cap_range as u128)
                .ok_or(SafePumpError::MathError)?
                as u64;
            contract.buy_cap_percentage = BUY_CAP_START + buy_cap_increase;
            if contract.buy_cap_percentage > BUY_CAP_END {
                contract.buy_cap_percentage = BUY_CAP_END; // Cap at 1%
            }
            msg!("Updated buy cap to {} bp at market cap {} lamports", contract.buy_cap_percentage, market_cap);
        }

        // Unlock sells when buy cap reaches or exceeds 0.25% (25 bp)
        if contract.buy_cap_percentage >= 25 && contract.sell_lock_active {
            contract.sell_lock_active = false;
            msg!("Sell lock lifted: buy_cap={} bp, market_cap={} lamports", contract.buy_cap_percentage, market_cap);
        }

        // Enforce buy cap
        let max_buy_amount = contract.total_supply * contract.buy_cap_percentage / 10_000;
        require!(amount <= max_buy_amount, SafePumpError::ExceedsMaxBuy);

        // Enforce sell lock if buy cap is below 0.25% (25 bp)
        if !is_buy {
            require!(!contract.sell_lock_active, SafePumpError::SellLockActive);
            let user_balance = ctx.accounts.user_ata.amount;
            require!(amount <= user_balance * MAX_SELL_PERCENT / 10_000, SafePumpError::ExceedsMaxSell);
            require!(
                clock.unix_timestamp - user_swap_data.last_sell_timestamp >= SELL_COOLDOWN,
                SafePumpError::SellCooldownNotMet
            );
            user_swap_data.last_sell_timestamp = clock.unix_timestamp;
        }

        let total_tax = amount.checked_mul(GLOBAL_TAX).ok_or(SafePumpError::MathError)? / 10_000;
        let lp_tax = total_tax.checked_mul(GLOBAL_LP_TAX).ok_or(SafePumpError::MathError)? / GLOBAL_TAX;
        let swapper_tax = total_tax.checked_mul(SWAPPER_REWARD_TAX).ok_or(SafePumpError::MathError)? / GLOBAL_TAX;
        let badge_tax = total_tax.checked_mul(BADGE_REWARD_TAX).ok_or(SafePumpError::MathError)? / GLOBAL_TAX;
        let lp_amount = amount.checked_sub(total_tax).ok_or(SafePumpError::MathError)?;

        if is_buy {
            let user_key = ctx.accounts.user.key();
            let index = badge_holders.buy_swap_count.iter().position(|(pubkey, _)| *pubkey == user_key);
            if let Some(idx) = index {
                badge_holders.buy_swap_count[idx].1 += 1;
            } else if badge_holders.holder_count < MAX_BADGE_HOLDERS as u64 {
                badge_holders.buy_swap_count[badge_holders.holder_count as usize] = (user_key, 1);
                badge_holders.holder_count += 1;
            }
            msg!("Updated buy swap count for user {}: {}", user_key, badge_holders.buy_swap_count[index.unwrap_or(badge_holders.holder_count as usize - 1)].1);
        }

        let reward_dist = &mut ctx.accounts.reward_distribution;
        if reward_dist.swap_count < MAX_BADGE_HOLDERS as u64 {
            reward_dist.swapper_rewards[reward_dist.swap_count as usize] = (ctx.accounts.user.key(), swapper_tax);
            reward_dist.swap_count += 1;
        }
        reward_dist.badge_rewards += badge_tax;
        if reward_dist.last_distribution_timestamp == 0 {
            reward_dist.last_distribution_timestamp = clock.unix_timestamp;
        }

        if is_safepump_swap {
            if is_buy {
                let cpi_accounts = raydium_cp_swap::cpi::accounts::SwapBaseIn {
                    pool_state: ctx.accounts.pool_state.to_account_info(),
                    user_source_token: ctx.accounts.user_ata.to_account_info(),
                    user_destination_token: ctx.accounts.user_safepump_ata.to_account_info(),
                    token_0_vault: ctx.accounts.vault.to_account_info(),
                    token_1_vault: ctx.accounts.sol_vault.to_account_info(),
                    token_program: ctx.accounts.token_program.to_account_info(),
                    remaining_accounts: ctx.remaining_accounts.to_vec(),
                };
                let cpi_program = ctx.accounts.raydium_program.to_account_info();
                let instruction = SwapBaseInput {
                    amount: lp_amount,
                    minimum_amount_out: 0,
                };
                let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
                raydium_cp_swap::cpi::swap_base_in(cpi_ctx, instruction)?;
                msg!("Performed SafePump swap: amount={} lamports to LP", lp_amount);

                token::transfer(
                    CpiContext::new(
                        ctx.accounts.token_program.to_account_info(),
                        Transfer {
                            from: ctx.accounts.user_ata.to_account_info(),
                            to: ctx.accounts.sol_vault.to_account_info(),
                            authority: ctx.accounts.user.to_account_info(),
                        },
                    ),
                    total_tax,
                )?;
                contract.vault_sol_balance += total_tax;
                msg!("Transferred {} lamports (tax) to SafePump sol_vault", total_tax);
            } else {
                let cpi_accounts = raydium_cp_swap::cpi::accounts::SwapBaseIn {
                    pool_state: ctx.accounts.pool_state.to_account_info(),
                    user_source_token: ctx.accounts.user_safepump_ata.to_account_info(),
                    user_destination_token: ctx.accounts.user_ata.to_account_info(),
                    token_0_vault: ctx.accounts.vault.to_account_info(),
                    token_1_vault: ctx.accounts.sol_vault.to_account_info(),
                    token_program: ctx.accounts.token_program.to_account_info(),
                    remaining_accounts: ctx.remaining_accounts.to_vec(),
                };
                let cpi_program = ctx.accounts.raydium_program.to_account_info();
                let instruction = SwapBaseInput {
                    amount,
                    minimum_amount_out: 0,
                };
                let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
                raydium_cp_swap::cpi::swap_base_in(cpi_ctx, instruction)?;
                msg!("Performed SafePump sell: amount={} tokens", amount);

                token::transfer(
                    CpiContext::new(
                        ctx.accounts.token_program.to_account_info(),
                        Transfer {
                            from: ctx.accounts.user_safepump_ata.to_account_info(),
                            to: ctx.accounts.sol_vault.to_account_info(),
                            authority: ctx.accounts.user.to_account_info(),
                        },
                    ),
                    total_tax,
                )?;
                contract.vault_sol_balance += total_tax;
                msg!("Transferred {} lamports (tax) to SafePump sol_vault", total_tax);
            }

            if lp_tax > 0 {
                token::transfer(
                    CpiContext::new(
                        ctx.accounts.token_program.to_account_info(),
                        Transfer {
                            from: ctx.accounts.user_ata.to_account_info(),
                            to: ctx.accounts.lp_vault.to_account_info(),
                            authority: ctx.accounts.user.to_account_info(),
                        },
                    ),
                    lp_tax,
                )?;
                msg!("Transferred {} lamports to SafePump LP vault", lp_tax);
            }
        } else {
            let meme_coin_data = ctx.accounts.meme_coin_data.load()?;
            if meme_coin_data.bond_timestamp > 0 {
                let cpi_accounts = raydium_cp_swap::cpi::accounts::SwapBaseIn {
                    pool_state: ctx.accounts.pool_state.to_account_info(),
                    user_source_token: ctx.accounts.user_ata.to_account_info(),
                    user_destination_token: ctx.accounts.user_safepump_ata.to_account_info(),
                    token_0_vault: ctx.accounts.vault.to_account_info(),
                    token_1_vault: ctx.accounts.sol_vault.to_account_info(),
                    token_program: ctx.accounts.token_program.to_account_info(),
                    remaining_accounts: ctx.remaining_accounts.to_vec(),
                };
                let cpi_program = ctx.accounts.raydium_program.to_account_info();
                let instruction = SwapBaseInput {
                    amount: lp_amount,
                    minimum_amount_out: 0,
                };
                let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
                raydium_cp_swap::cpi::swap_base_in(cpi_ctx, instruction)?;
                msg!("Performed meme coin swap: amount={} lamports to meme coin LP", lp_amount);
            } else {
                token::transfer(
                    CpiContext::new(
                        ctx.accounts.token_program.to_account_info(),
                        Transfer {
                            from: ctx.accounts.user_ata.to_account_info(),
                            to: ctx.accounts.vault.to_account_info(),
                            authority: ctx.accounts.user.to_account_info(),
                        },
                    ),
                    lp_amount,
                )?;
                msg!("Transferred {} lamports to pre-bonded meme coin vault", lp_amount);
            }

            token::transfer(
                CpiContext::new(
                    ctx.accounts.token_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.user_ata.to_account_info(),
                        to: ctx.accounts.sol_vault.to_account_info(),
                        authority: ctx.accounts.user.to_account_info(),
                    },
                ),
                total_tax,
            )?;
            contract.vault_sol_balance += total_tax;
            msg!("Transferred {} lamports (tax) to SafePump sol_vault from meme coin", total_tax);

            if lp_tax > 0 {
                token::transfer(
                    CpiContext::new(
                        ctx.accounts.token_program.to_account_info(),
                        Transfer {
                            from: ctx.accounts.user_ata.to_account_info(),
                            to: ctx.accounts.lp_vault.to_account_info(),
                            authority: ctx.accounts.user.to_account_info(),
                        },
                    ),
                    lp_tax,
                )?;
                msg!("Transferred {} lamports to SafePump LP vault from meme coin", lp_tax);
            }
        }

        contract.total_swapped = contract.total_swapped.checked_add(amount).ok_or(SafePumpError::MathError)?;
        contract.swap_count = contract.swap_count.checked_add(1).ok_or(SafePumpError::MathError)?;

        Ok(())
    }

    pub fn distribute_rewards(ctx: Context<DistributeRewards>) -> Result<()> {
        let reward_dist = &mut ctx.accounts.reward_distribution;
        let badge_holders = &ctx.accounts.badge_holders;
        let clock = Clock::get()?;

        require!(
            clock.unix_timestamp - reward_dist.last_distribution_timestamp >= REWARD_DISTRIBUTION_PERIOD,
            SafePumpError::DistributionPeriodNotMet
        );

        let mut remaining_swapper_rewards = [(Pubkey::default(), 0); MAX_BADGE_HOLDERS];
        let mut new_count = 0;
        for (user, amount) in reward_dist.swapper_rewards.iter() {
            if amount > 0 {
                invoke(
                    &solana_program::system_instruction::transfer(
                        &ctx.accounts.sol_vault.key(),
                        user,
                        *amount,
                    ),
                    &[
                        ctx.accounts.sol_vault.to_account_info(),
                        ctx.accounts.user.to_account_info(),
                        ctx.accounts.system_program.to_account_info(),
                    ],
                )?;
                msg!("Distributed {} lamports to swapper: {}", amount, user);
            } else {
                remaining_swapper_rewards[new_count] = (*user, *amount);
                new_count += 1;
            }
        }
        reward_dist.swapper_rewards = remaining_swapper_rewards;
        reward_dist.swap_count = new_count as u64;

        if badge_holders.holder_count > 0 && reward_dist.badge_rewards > 0 {
            let reward_per_holder = reward_dist.badge_rewards
                .checked_div(badge_holders.holder_count)
                .ok_or(SafePumpError::MathError)?;
            
            for holder in badge_holders.holders.iter().take(badge_holders.holder_count as usize) {
                if reward_per_holder > 0 && *holder != Pubkey::default() {
                    invoke(
                        &solana_program::system_instruction::transfer(
                            &ctx.accounts.sol_vault.key(),
                            holder,
                            reward_per_holder,
                        ),
                        &[
                            ctx.accounts.sol_vault.to_account_info(),
                            ctx.accounts.system_program.to_account_info(),
                        ],
                    )?;
                    msg!("Distributed {} lamports to badge holder: {}", reward_per_holder, holder);
                }
            }
            reward_dist.badge_rewards = 0;
        }

        reward_dist.last_distribution_timestamp = clock.unix_timestamp;
        reward_dist.swap_count = 0;
        msg!("Distributed rewards: swapper_rewards={}, badge_rewards={}", reward_dist.swap_count, reward_dist.badge_rewards);
        Ok(())
    }

    pub fn add_badge_holder(ctx: Context<AddBadgeHolder>) -> Result<()> {
        let badge_holders = &mut ctx.accounts.badge_holders;
        let user_key = ctx.accounts.user.key();
        let index = badge_holders.buy_swap_count.iter().position(|(pubkey, _)| *pubkey == user_key);

        require!(
            index.is_some() && badge_holders.buy_swap_count[index.unwrap()].1 >= BUY_SWAPS_FOR_BADGE,
            SafePumpError::InsufficientBuySwaps
        );
        require!(
            !badge_holders.holders.iter().any(|h| *h == user_key),
            SafePumpError::AlreadyBadgeHolder
        );
        require!(
            badge_holders.holder_count < MAX_BADGE_HOLDERS as u64,
            SafePumpError::BadgeHolderLimitReached
        );

        badge_holders.holders[badge_holders.holder_count as usize] = user_key;
        badge_holders.buy_swap_count[index.unwrap()].1 = 0;
        badge_holders.holder_count += 1;
        msg!("Added badge holder: {}", user_key);
        Ok(())
    }
}

#[derive(Accounts, Bumps)]
pub struct InitializeContract<'info> {
    #[account(
        init,
        payer = owner,
        space = 8 + 1 + 8 + 32 + 8 + 8 + 8 + 8 + 1 + 8 + 1 + 1 + 1 + 4 + (4 + MAX_FRIENDS_WALLETS * 32) + (4 + MAX_FRIENDS_WALLETS * 8) + 8, // Updated for deployer_amount
        seeds = [b"contract", owner.key().as_ref()],
        bump
    )]
    pub contract: Account<'info, TokenContract>,
    #[account(mut)]
    pub owner: Signer<'info>,
    #[account(mut)]
    pub mint: Account<'info, Mint>,
    #[account(mut)]
    pub vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub badge_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub swap_rewards_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub lp_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub sol_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub lp_mint: Account<'info, Mint>,
    #[account(mut)]
    pub owner_wsol_ata: Account<'info, TokenAccount>,
    #[account(
        init_if_needed,
        payer = owner,
        associated_token::mint = mint,
        associated_token::authority = owner
    )]
    pub deployer_ata: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool_state: AccountInfo<'info>,
    #[account(mut)]
    pub observation_state: AccountInfo<'info>,
    #[account(mut)]
    pub amm_config: AccountInfo<'info>,
    #[account(mut)]
    pub authority: AccountInfo<'info>,
    #[account(mut)]
    pub create_pool_fee: AccountInfo<'info>,
    #[account(address = raydium_cp_swap::id())]
    pub raydium_program: Program<'info, raydium_cp_swap::program::RaydiumCpSwap>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts, Bumps)]
pub struct InitializeBadgeHolders<'info> {
    #[account(
        mut,
        seeds = [b"contract", owner.key().as_ref()],
        bump
    )]
    pub contract: Account<'info, TokenContract>,
    #[account(mut)]
    pub owner: Signer<'info>,
    #[account(
        init,
        payer = owner,
        space = 8 + (32 * MAX_BADGE_HOLDERS) + (40 * MAX_BADGE_HOLDERS) + 8 + 1,
        seeds = [b"badge-holders", mint.key().as_ref()],
        bump
    )]
    pub badge_holders: Account<'info, BadgeHolders>,
    #[account(mut)]
    pub mint: Account<'info, Mint>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts, Bumps)]
pub struct RegisterMemeCoin<'info> {
    #[account(
        mut,
        seeds = [b"contract", owner.key().as_ref()],
        bump
    )]
    pub contract: Account<'info, TokenContract>,
    #[account(
        init_if_needed,
        payer = deployer,
        space = 8 + 4 + (64 * 1000) + 1,
        seeds = [b"meme-coin-registry", contract.key().as_ref()],
        bump
    )]
    pub meme_coin_registry: Account<'info, MemeCoinRegistry>,
    #[account(mut)]
    pub deployer: Signer<'info>,
    #[account(mut)]
    pub owner: Signer<'info>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts, Bumps)]
pub struct GlobalTaxSwap<'info> {
    #[account(
        mut,
        seeds = [b"contract", owner.key().as_ref()],
        bump
    )]
    pub contract: Account<'info, TokenContract>,
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(mut)]
    pub user_ata: Account<'info, TokenAccount>,
    #[account(mut)]
    pub vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub badge_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub swap_rewards_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub lp_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub sol_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub mint: Account<'info, Mint>,
    #[account(mut)]
    pub owner: Signer<'info>,
    #[account(
        mut,
        seeds = [b"badge-holders", mint.key().as_ref()],
        bump
    )]
    pub badge_holders: Account<'info, BadgeHolders>,
    #[account(mut)]
    pub user_safepump_ata: Account<'info, TokenAccount>,
    #[account(mut)]
    pub safepump_mint: Account<'info, Mint>,
    #[account(
        init_if_needed,
        payer = user,
        space = 8 + 8 + 1,
        seeds = [b"user-swap-data", user.key().as_ref(), mint.key().as_ref()],
        bump
    )]
    pub user_swap_data: Account<'info, UserSwapData>,
    #[account(
        init_if_needed,
        payer = user,
        space = 8 + (40 * MAX_BADGE_HOLDERS) + 8 + 8 + 1,
        seeds = [b"reward-distribution", mint.key().as_ref()],
        bump
    )]
    pub reward_distribution: Account<'info, RewardDistribution>,
    #[account(
        seeds = [b"meme-coin-registry", contract.key().as_ref()],
        bump
    )]
    pub meme_coin_registry: Account<'info, MemeCoinRegistry>,
    #[account(mut)]
    pub meme_coin_data: AccountLoader<'info, TokenContract>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
    #[account(mut)]
    pub pool_state: AccountInfo<'info>,
    #[account(address = raydium_cp_swap::id())]
    pub raydium_program: Program<'info, raydium_cp_swap::program::RaydiumCpSwap>,
}

#[derive(Accounts, Bumps)]
pub struct DistributeRewards<'info> {
    #[account(
        mut,
        seeds = [b"contract", owner.key().as_ref()],
        bump
    )]
    pub contract: Account<'info, TokenContract>,
    #[account(mut)]
    pub owner: Signer<'info>,
    #[account(mut)]
    pub user: AccountInfo<'info>,
    #[account(mut)]
    pub badge_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub swap_rewards_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub sol_vault: Account<'info, TokenAccount>,
    #[account(mut)]
    pub safepump_mint: Account<'info, Mint>,
    #[account(
        mut,
        seeds = [b"badge-holders", safepump_mint.key().as_ref()],
        bump
    )]
    pub badge_holders: Account<'info, BadgeHolders>,
    #[account(
        mut,
        seeds = [b"reward-distribution", safepump_mint.key().as_ref()],
        bump
    )]
    pub reward_distribution: Account<'info, RewardDistribution>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts, Bumps)]
pub struct AddBadgeHolder<'info> {
    #[account(
        mut,
        seeds = [b"contract", owner.key().as_ref()],
        bump
    )]
    pub contract: Account<'info, TokenContract>,
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(
        mut,
        seeds = [b"badge-holders", mint.key().as_ref()],
        bump
    )]
    pub badge_holders: Account<'info, BadgeHolders>,
    #[account(mut)]
    pub mint: Account<'info, Mint>,
    pub system_program: Program<'info, System>,
}

#[account]
#[derive(Copy, Clone)]
#[zero_copy]
pub struct TokenContract {
    pub is_initialized: bool,
    pub total_supply: u64,
    pub treasury_wallet: Pubkey,
    pub swap_count: u64,
    pub total_swapped: u64,
    pub vault_sol_balance: u64,
    pub vault_token_balance: u64,
    pub burned_tokens: u64,
    pub burn_percentage: u8,
    pub bond_timestamp: i64,
    pub buy_cap_percentage: u64, // Current buy cap in basis points (e.g., 10 = 0.1%)
    pub sell_lock_active: bool, // True until buy cap reaches 0.25% (25 bp)
    pub liquidity_threshold_index: u8, // Tracks current step (0 to 4)
    pub friends_wallets: [Pubkey; MAX_FRIENDS_WALLETS], // Fixed-size array for friends
    pub friends_amounts: [u64; MAX_FRIENDS_WALLETS], // Fixed-size array for amounts
    pub deployer_amount: u64, // Deployer allocation
    pub bump: u8,
}

#[account]
pub struct BadgeHolders {
    pub holders: [Pubkey; MAX_BADGE_HOLDERS],
    pub buy_swap_count: [(Pubkey, u64); MAX_BADGE_HOLDERS],
    pub holder_count: u64,
    pub bump: u8,
}

#[account]
pub struct MemeCoinRegistry {
    pub meme_coins: [(Pubkey, Pubkey); 1000],
    pub meme_coin_count: u64,
    pub bump: u8,
}

#[account]
pub struct UserSwapData {
    pub last_sell_timestamp: i64,
    pub bump: u8,
}

#[account]
pub struct RewardDistribution {
    pub swapper_rewards: [(Pubkey, u64); MAX_BADGE_HOLDERS],
    pub badge_rewards: u64,
    pub swap_count: u64,
    pub last_distribution_timestamp: i64,
    pub bump: u8,
}

#[error_code]
pub enum SafePumpError {
    #[msg("Contract already initialized")]
    AlreadyInitialized,
    #[msg("Contract not initialized")]
    NotInitialized,
    #[msg("Invalid supply")]
    InvalidSupply,
    #[msg("Anti-sniper cooldown not met")]
    AntiSniperCooldown,
    #[msg("Math error")]
    MathError,
    #[msg("Insufficient buy swaps for badge")]
    InsufficientBuySwaps,
    #[msg("User is already a badge holder")]
    AlreadyBadgeHolder,
    #[msg("Badge holder limit reached")]
    BadgeHolderLimitReached,
    #[msg("Meme coin already registered")]
    MemeCoinAlreadyRegistered,
    #[msg("Meme coin not registered")]
    MemeCoinNotRegistered,
    #[msg("Exceeds max buy amount")]
    ExceedsMaxBuy,
    #[msg("Exceeds max sell amount")]
    ExceedsMaxSell,
    #[msg("Invalid burn percentage")]
    InvalidBurnPercentage,
    #[msg("Sell cooldown not met")]
    SellCooldownNotMet,
    #[msg("Distribution period not met")]
    DistributionPeriodNotMet,
    #[msg("Invalid LP percentage")]
    InvalidLpPercentage,
    #[msg("Sell lock is active")]
    SellLockActive,
    #[msg("Invalid friends wallet allocation")]
    InvalidFriendsAllocation,
}

fn get_associated_token_address(owner: &Pubkey, mint: &Pubkey) -> Pubkey {
    anchor_spl::associated_token::get_associated_token_address(owner, mint)
}
