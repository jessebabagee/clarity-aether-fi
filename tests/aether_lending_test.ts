[Previous test content...]

Clarinet.test({
  name: "Test loan repayment functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const borrowAmount = 1000;
    const collateralAmount = 30; // 30 xBTC
    
    // Set up prices and borrow
    [Previous test setup remains the same...]
    
    // Test repayment
    let repayBlock = chain.mineBlock([
      Tx.contractCall('aether_lending', 'repay', [
        types.ascii("stx"),
        types.uint(borrowAmount)
      ], wallet1.address)
    ]);
    repayBlock.receipts[0].result.expectOk().expectBool(true);
    
    // Verify loan is closed
    let loanData = chain.mineBlock([
      Tx.contractCall('aether_lending', 'get-loan-data', [
        types.principal(wallet1.address),
        types.ascii("stx")
      ], wallet1.address)
    ]);
    loanData.receipts[0].result.expectOk().expectNone();
  }
});
