import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure that users can deposit and withdraw multiple assets",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const depositAmount = 1000;
    
    // Set token prices
    let priceBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'set-token-price', [
        types.ascii("stx"),
        types.uint(100)
      ], wallet1.address),
      Tx.contractCall('aether_lending', 'set-token-price', [
        types.ascii("xbtc"),
        types.uint(5000)
      ], wallet1.address),
      Tx.contractCall('aether_lending', 'set-token-price', [
        types.ascii("alex"),
        types.uint(50)
      ], wallet1.address)
    ]);
    
    // Test STX deposit
    let block = chain.mineBlock([
      Tx.contractCall('aether_lending', 'deposit', [
        types.ascii("stx"),
        types.uint(depositAmount)
      ], wallet1.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    let getBalance = chain.mineBlock([
      Tx.contractCall('aether_lending', 'get-deposit-balance', [
        types.principal(wallet1.address),
        types.ascii("stx")
      ], wallet1.address)
    ]);
    getBalance.receipts[0].result.expectOk().expectUint(depositAmount);
    
    // Test withdrawing STX
    let withdrawBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'withdraw', [
        types.ascii("stx"),
        types.uint(depositAmount)
      ], wallet1.address)
    ]);
    withdrawBlock.receipts[0].result.expectOk().expectBool(true);
  }
});

Clarinet.test({
  name: "Test borrowing with different collateral assets",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const borrowAmount = 1000;
    const collateralAmount = 1500; // 150% collateral
    
    // Set token prices
    chain.mineBlock([
      Tx.contractCall('aether_lending', 'set-token-price', [
        types.ascii("stx"),
        types.uint(100)
      ], wallet1.address),
      Tx.contractCall('aether_lending', 'set-token-price', [
        types.ascii("xbtc"),
        types.uint(5000)
      ], wallet1.address)
    ]);
    
    // Borrow STX with xBTC as collateral
    let block = chain.mineBlock([
      Tx.contractCall('aether_lending', 'borrow', [
        types.ascii("stx"),
        types.uint(borrowAmount),
        types.ascii("xbtc"),
        types.uint(30) // 30 xBTC worth more than 150% of 1000 STX
      ], wallet1.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Try to borrow with insufficient collateral
    let failedBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'borrow', [
        types.ascii("stx"),
        types.uint(borrowAmount),
        types.ascii("xbtc"),
        types.uint(10)
      ], wallet1.address)
    ]);
    failedBlock.receipts[0].result.expectErr().expectUint(101); // ERR-INSUFFICIENT-COLLATERAL
  }
});
