Clarinet.test({
  name: "Test loan repayment functionality - full and partial repayments",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const borrowAmount = 1000;
    const collateralAmount = 30; // 30 xBTC
    
    // [Previous test setup remains the same...]
    
    // Test partial repayment
    let partialRepayBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'repay', [
        types.ascii("stx"),
        types.uint(500) // Repay half
      ], wallet1.address)
    ]);
    partialRepayBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify loan is still active with reduced amount
    let partialLoanData = chain.mineBlock([
      Tx.contractCall('aether_lending', 'get-loan-data', [
        types.principal(wallet1.address),
        types.ascii("stx")
      ], wallet1.address)
    ]);
    partialLoanData.receipts[0].result.expectOk().expectSome();
    
    // Test full repayment
    let fullRepayBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'repay', [
        types.ascii("stx"),
        types.uint(500) // Repay remaining amount
      ], wallet1.address)
    ]);
    fullRepayBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify loan is closed
    let finalLoanData = chain.mineBlock([
      Tx.contractCall('aether_lending', 'get-loan-data', [
        types.principal(wallet1.address),
        types.ascii("stx")
      ], wallet1.address)
    ]);
    finalLoanData.receipts[0].result.expectOk().expectNone();
  }
});
