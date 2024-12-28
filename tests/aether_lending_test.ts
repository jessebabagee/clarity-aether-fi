import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure that users can deposit and withdraw",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const depositAmount = 1000;
    
    let block = chain.mineBlock([
      Tx.contractCall('aether_lending', 'deposit', [
        types.uint(depositAmount)
      ], wallet1.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    let getBalance = chain.mineBlock([
      Tx.contractCall('aether_lending', 'get-deposit-balance', [
        types.principal(wallet1.address)
      ], wallet1.address)
    ]);
    getBalance.receipts[0].result.expectOk().expectUint(depositAmount);
    
    // Test withdraw
    let withdrawBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'withdraw', [
        types.uint(depositAmount)
      ], wallet1.address)
    ]);
    withdrawBlock.receipts[0].result.expectOk().expectBool(true);
  }
});

Clarinet.test({
  name: "Test borrowing and collateral requirements",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const borrowAmount = 1000;
    const collateralAmount = 1500; // 150% collateral
    
    let block = chain.mineBlock([
      Tx.contractCall('aether_lending', 'borrow', [
        types.uint(borrowAmount),
        types.uint(collateralAmount)
      ], wallet1.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Try to borrow with insufficient collateral
    let failedBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'borrow', [
        types.uint(borrowAmount),
        types.uint(1000) // Only 100% collateral
      ], wallet1.address)
    ]);
    failedBlock.receipts[0].result.expectErr().expectUint(101); // ERR-INSUFFICIENT-COLLATERAL
  }
});

Clarinet.test({
  name: "Test liquidation mechanism",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const borrowAmount = 1000;
    const collateralAmount = 1300; // Just above liquidation threshold
    
    // Setup a loan
    let setupBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'borrow', [
        types.uint(borrowAmount),
        types.uint(collateralAmount)
      ], wallet1.address)
    ]);
    
    // Attempt liquidation (should fail as above threshold)
    let liquidationBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'liquidate', [
        types.principal(wallet1.address)
      ], wallet2.address)
    ]);
    liquidationBlock.receipts[0].result.expectErr().expectUint(103); // ERR-ABOVE-LIQUIDATION-THRESHOLD
  }
});