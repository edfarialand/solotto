use anchor_lang::prelude::*;
use anchor_lang::solana_program::clock::Clock;
use anchor_lang::solana_program::hash::{hash, Hash};
use anchor_spl::token::{self, Token, TokenAccount, Mint, Transfer};
use std::mem::size_of;

declare_id!("J1SgiaWF6Mo64Ka6VHzPmk9ZSQzWGkWVpQwCbuJsQmMW");

// Solotto: A lottery token system with dual fee structure:
// 1. AUTHORITY FEE: 1% of all transactions goes to the creator (authority wallet)
// 2. LOTTERY FEE: 1% of all transactions goes to the weekly winner
//
// The winner is selected weekly from among token holders:
// - 4 random wallets are selected
// - Among those 4, the wallet with the highest token balance becomes the winner
// - This winner automatically receives 1% of all transactions for the next 7 days
//
// No manual claiming needed - fees are automatically transferred during transactions

#[program]
pub mod solotto {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let solotto = &mut ctx.accounts.solotto;
        
        solotto.authority = ctx.accounts.authority.key();
        solotto.authority_wallet = ctx.accounts.authority.key(); // The authority is also the fee recipient
        solotto.mint = ctx.accounts.mint.key();
        solotto.last_draw_time = Clock::get()?.unix_timestamp;
        solotto.next_draw_time = solotto.last_draw_time + 7 * 24 * 60 * 60; // 7 days in seconds
        solotto.holders = Vec::new();
        solotto.current_winner = None;
        solotto.winner_fees_distributed = 0;
        solotto.authority_fees_distributed = 0;
        solotto.bump = *ctx.bumps.get("solotto").unwrap();
        
        msg!("Solotto initialized with 7-day draw period, next draw at {}", solotto.next_draw_time);
        msg!("Authority wallet (receiving 1% fees): {:?}", solotto.authority_wallet);
        Ok(())
    }
    
    pub fn process_transfer(ctx: Context<ProcessTransfer>, amount: u64) -> Result<()> {
        let solotto = &mut ctx.accounts.solotto;
        
        // Calculate fees: 1% to winner, 1% to authority
        let winner_fee = amount.checked_mul(1).unwrap_or(0).checked_div(100).unwrap_or(0);
        let authority_fee = amount.checked_mul(1).unwrap_or(0).checked_div(100).unwrap_or(0);
        let transfer_amount = amount
            .checked_sub(winner_fee)
            .unwrap_or(amount)
            .checked_sub(authority_fee)
            .unwrap_or(amount - winner_fee);
        
        // Transfer tokens minus fees
        let cpi_accounts = Transfer {
            from: ctx.accounts.from_token_account.to_account_info(),
            to: ctx.accounts.to_token_account.to_account_info(),
            authority: ctx.accounts.authority.to_account_info(),
        };
        
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        
        token::transfer(cpi_ctx, transfer_amount)?;
        
        // Transfer winner fee if winner exists and fee > 0
        if winner_fee > 0 && solotto.current_winner.is_some() {
            // Check if winner token account is provided
            if let Some(winner_token_account) = &ctx.accounts.winner_token_account {
                let fee_accounts = Transfer {
                    from: ctx.accounts.from_token_account.to_account_info(),
                    to: winner_token_account.to_account_info(),
                    authority: ctx.accounts.authority.to_account_info(),
                };
                
                let fee_ctx = CpiContext::new(
                    ctx.accounts.token_program.to_account_info(),
                    fee_accounts,
                );
                
                token::transfer(fee_ctx, winner_fee)?;
                
                solotto.winner_fees_distributed = solotto.winner_fees_distributed
                    .checked_add(winner_fee)
                    .unwrap_or(solotto.winner_fees_distributed);
                
                msg!("Transferred {} tokens with {} fee to weekly winner", transfer_amount, winner_fee);
            } else {
                // If winner account not provided, send to recipient
                let fee_accounts = Transfer {
                    from: ctx.accounts.from_token_account.to_account_info(),
                    to: ctx.accounts.to_token_account.to_account_info(),
                    authority: ctx.accounts.authority.to_account_info(),
                };
                
                let fee_ctx = CpiContext::new(
                    ctx.accounts.token_program.to_account_info(),
                    fee_accounts,
                );
                
                token::transfer(fee_ctx, winner_fee)?;
                msg!("Winner fee sent to recipient (no winner token account provided)");
            }
        }
        
        // Transfer authority fee if authority account is provided and fee > 0
        if authority_fee > 0 && ctx.accounts.authority_token_account.is_some() {
            let authority_token_account = ctx.accounts.authority_token_account.as_ref().unwrap();
            
            let fee_accounts = Transfer {
                from: ctx.accounts.from_token_account.to_account_info(),
                to: authority_token_account.to_account_info(),
                authority: ctx.accounts.authority.to_account_info(),
            };
            
            let fee_ctx = CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                fee_accounts,
            );
            
            token::transfer(fee_ctx, authority_fee)?;
            
            solotto.authority_fees_distributed = solotto.authority_fees_distributed
                .checked_add(authority_fee)
                .unwrap_or(solotto.authority_fees_distributed);
            
            msg!("Transferred {} fee to authority wallet", authority_fee);
        } else if authority_fee > 0 {
            // If authority account not provided, send to recipient
            let fee_accounts = Transfer {
                from: ctx.accounts.from_token_account.to_account_info(),
                to: ctx.accounts.to_token_account.to_account_info(),
                authority: ctx.accounts.authority.to_account_info(),
            };
            
            let fee_ctx = CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                fee_accounts,
            );
            
            token::transfer(fee_ctx, authority_fee)?;
            msg!("Authority fee sent to recipient (no authority token account provided)");
        }
        
        // Update sender and recipient holdings
        update_holder(solotto, ctx.accounts.from.key(), ctx.accounts.from_token_account.amount)?;
        update_holder(solotto, ctx.accounts.to.key(), ctx.accounts.to_token_account.amount)?;
        
        // Check if it's time for a draw
        let current_time = Clock::get()?.unix_timestamp;
        if current_time >= solotto.next_draw_time {
            draw_winner(solotto, current_time)?;
        }
        
        Ok(())
    }

    pub fn update_holder_balance(ctx: Context<UpdateHolderBalance>) -> Result<()> {
        let solotto = &mut ctx.accounts.solotto;
        let holder = ctx.accounts.holder.key();
        let balance = ctx.accounts.holder_token_account.amount;
        
        update_holder(solotto, holder, balance)?;
        
        msg!("Updated holder {:?} with balance {}", holder, balance);
        Ok(())
    }

    pub fn force_draw(ctx: Context<ForceDraw>) -> Result<()> {
        let solotto = &mut ctx.accounts.solotto;
        
        // Only authority can force a draw
        require!(solotto.authority == ctx.accounts.authority.key(), SolottoError::NotAuthorized);
        
        let current_time = Clock::get()?.unix_timestamp;
        draw_winner(solotto, current_time)?;
        
        Ok(())
    }
    
    // We've removed the update_authority_wallet function since the authority wallet never changes
}

// Helper function to update a holder's balance
fn update_holder(solotto: &mut Account<SolottoState>, holder: Pubkey, balance: u64) -> Result<()> {
    // Update or add holder in the list
    let holder_index = solotto.holders.iter().position(|h| h.0 == holder);
    
    if let Some(index) = holder_index {
        if balance > 0 {
            solotto.holders[index].1 = balance;
        } else {
            // Remove holder if balance is 0
            solotto.holders.remove(index);
        }
    } else if balance > 0 {
        solotto.holders.push((holder, balance));
    }
    
    Ok(())
}

// Helper function to draw new winner
fn draw_winner(solotto: &mut Account<SolottoState>, current_time: i64) -> Result<()> {
    // Remove holders with zero balance
    solotto.holders.retain(|h| h.1 > 0);
    
    // Check if we have holders
    if solotto.holders.is_empty() {
        msg!("No holders available for draw");
        
        // Update draw times
        solotto.last_draw_time = current_time;
        solotto.next_draw_time = current_time + 7 * 24 * 60 * 60; // 7 days in seconds
        solotto.current_winner = None;
        return Ok(());
    }
    
    // We need 4 wallets for the selection (or all if less than 4)
    let num_to_select = std::cmp::min(4, solotto.holders.len());
    let mut selected_holders = Vec::with_capacity(num_to_select);
    let mut indices_used = Vec::new();
    
    // Select random holders
    let recent_slot = Clock::get()?.slot;
    for i in 0..num_to_select {
        // Create a different seed for each selection
        let seed_data = [
            recent_slot.to_le_bytes().as_ref(),
            &[i as u8],
            current_time.to_le_bytes().as_ref()
        ].concat();
        
        let seed = &hash(&seed_data).to_bytes();
        let mut index;
        
        // Ensure we don't select the same holder twice
        loop {
            index = (u64::from_le_bytes(seed[0..8].try_into().unwrap()) % 
                    solotto.holders.len() as u64) as usize;
            
            if !indices_used.contains(&index) {
                indices_used.push(index);
                break;
            }
            
            // If we've tried all indices, just use what's left
            if indices_used.len() >= solotto.holders.len() {
                for j in 0..solotto.holders.len() {
                    if !indices_used.contains(&j) {
                        index = j;
                        indices_used.push(j);
                        break;
                    }
                }
                break;
            }
        }
        
        selected_holders.push(solotto.holders[index]);
    }
    
    // Find the holder with the highest balance among selected holders
    selected_holders.sort_by(|a, b| b.1.cmp(&a.1));
    let winner = selected_holders[0].0;
    
    // Set winner
    solotto.current_winner = Some(winner);
    
    // Update draw times
    solotto.last_draw_time = current_time;
    solotto.next_draw_time = current_time + 7 * 24 * 60 * 60; // 7 days in seconds
    
    msg!("New winner drawn: {:?} (highest balance among 4 random holders)", winner);
    msg!("This wallet will receive 1% of all transactions until {}", solotto.next_draw_time);
    
    Ok(())
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init, 
        payer = authority, 
        space = 8 + size_of::<SolottoState>(),
        seeds = [b"solotto", authority.key().as_ref()],
        bump
    )]
    pub solotto: Account<'info, SolottoState>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    pub mint: Account<'info, Mint>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ProcessTransfer<'info> {
    #[account(mut)]
    pub solotto: Account<'info, SolottoState>,
    
    #[account(mut)]
    pub from_token_account: Account<'info, TokenAccount>,
    
    /// CHECK: This account is not read or written to directly
    pub from: AccountInfo<'info>,
    
    #[account(mut)]
    pub to_token_account: Account<'info, TokenAccount>,
    
    /// CHECK: This account is not read or written to directly
    pub to: AccountInfo<'info>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    /// Optional winner token account to receive fees
    #[account(
        mut,
        constraint = winner_token_account.is_none() || 
                     (winner_token_account.as_ref().unwrap().mint == solotto.mint && 
                      winner_token_account.as_ref().unwrap().owner == solotto.current_winner.unwrap_or_default())
    )]
    pub winner_token_account: Option<Account<'info, TokenAccount>>,
    
    /// Optional authority token account to receive fees
    #[account(
        mut,
        constraint = authority_token_account.is_none() || 
                     (authority_token_account.as_ref().unwrap().mint == solotto.mint && 
                      authority_token_account.as_ref().unwrap().owner == solotto.authority_wallet)
    )]
    pub authority_token_account: Option<Account<'info, TokenAccount>>,
    
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct UpdateHolderBalance<'info> {
    #[account(mut)]
    pub solotto: Account<'info, SolottoState>,
    
    pub holder: Signer<'info>,
    
    #[account(
        constraint = holder_token_account.mint == solotto.mint,
        constraint = holder_token_account.owner == holder.key()
    )]
    pub holder_token_account: Account<'info, TokenAccount>,
}

#[derive(Accounts)]
pub struct ForceDraw<'info> {
    #[account(
        mut,
        seeds = [b"solotto", solotto.authority.as_ref()],
        bump = solotto.bump
    )]
    pub solotto: Account<'info, SolottoState>,
    
    pub authority: Signer<'info>,
}

// We've removed the UpdateAuthorityWallet struct since it's no longer needed

#[account]
pub struct SolottoState {
    pub authority: Pubkey,                   // Program authority (creator)
    pub authority_wallet: Pubkey,            // Wallet receiving the authority fee (1%)
    pub mint: Pubkey,                        // Token mint address
    pub last_draw_time: i64,                 // Timestamp of last lottery draw
    pub next_draw_time: i64,                 // Timestamp when next draw will occur
    pub holders: Vec<(Pubkey, u64)>,         // All holders (Pubkey, Balance)
    pub current_winner: Option<Pubkey>,      // Current week's winner receiving 1% fee
    pub winner_fees_distributed: u64,        // Total fees sent to winners (historical)
    pub authority_fees_distributed: u64,     // Total fees sent to authority (historical)
    pub bump: u8,                           // PDA bump
}

#[error_code]
pub enum SolottoError {
    #[msg("Not authorized to perform this action")]
    NotAuthorized,
}
