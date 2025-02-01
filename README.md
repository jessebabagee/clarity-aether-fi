# AetherFi Multi-Asset Lending Protocol

A decentralized lending protocol built on Stacks that enables fixed-rate lending and borrowing across multiple assets. Users can deposit assets to earn interest or borrow assets by providing collateral in any supported token.

## Supported Assets
- STX (Stacks)
- xBTC (Wrapped Bitcoin)
- ALEX (ALEX token)

## Features
- Multi-asset support for deposits and collateral
- Fixed interest rates for predictable returns and payments
- Cross-asset collateralized borrowing
- Interest accrual on deposits
- Liquidation mechanism for under-collateralized positions
- Dynamic price feeds for accurate collateral valuation

## Contract Functions
- Deposit multiple types of assets
- Withdraw deposits in any supported token
- Borrow against cross-asset collateral
- Repay loans
- Liquidate under-collateralized positions
- Set and update token prices (admin only)

## Token Price Feeds
The protocol maintains current prices for all supported assets to:
- Calculate accurate collateral ratios
- Determine borrowing capacity
- Trigger liquidations when necessary
