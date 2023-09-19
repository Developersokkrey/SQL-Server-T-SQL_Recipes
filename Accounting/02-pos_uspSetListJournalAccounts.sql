

CREATE OR ALTER  PROC [dbo].[pos_uspSetListJournalAccounts] (
	@receiptId int,
	@journalEntryId int, 
	@docTypeId int
) AS BEGIN 
	DECLARE @journalMapSet [JournalMap];
	--Debit from Customer (Invoice)
	INSERT INTO @journalMapSet 
	SELECT 
		R.ReceiptID AS [ReceiptID],
		BP.ID AS [BPAcctID],
		GL.ID AS [GLAcctID],
		R.GrandTotal * R.ExchangeRate AS [Debit],
		0 AS [Credit]
	FROM tbReceipt R 
	LEFT JOIN tbBusinessPartner BP ON R.CustomerID = BP.ID
	INNER JOIN tbGLAccount GL ON GL.ID = BP.GLAccID
	WHERE R.ReceiptID = @receiptId
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Credit from Tax Group
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(RD.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		0 AS [Debit],
		SUM(RD.[ItemTaxValue]) AS [Credit]
	FROM pos_ufnGetItemBalance(@receiptId) RD
	INNER JOIN TaxGroup TG ON RD.TaxGroupID = TG.ID
	INNER JOIN tbGLAccount GL ON GL.ID = TG.GLID
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet
	
	--Credit from Tax PublicLightingTax
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(RD.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		0 AS [Debit],
		SUM(RD.[ItemPLTaxValue]) AS [Credit]
	FROM pos_ufnGetItemBalance(@receiptId) RD
	INNER JOIN TaxGroup TG ON RD.TaxPlID = TG.ID
	INNER JOIN tbGLAccount GL ON GL.ID = TG.GLID
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet
	
		--Credit from Tax PublicLightingTax
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(RD.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		0 AS [Debit],
		SUM(RD.[ItemSPTaxValue]) AS [Credit]
	FROM pos_ufnGetItemBalance(@receiptId) RD
	INNER JOIN TaxGroup TG ON RD.TaxSPID = TG.ID
	INNER JOIN tbGLAccount GL ON GL.ID = TG.GLID
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Credit from Freight
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT
		R.ReceiptID AS [ReceiptID],
		0 AS [BPAcctID],
		TFR.GLAcctID AS [GLAcctID],
		0 AS [Debit],
		TFR.AmountReven * R.ExchangeRate
		AS [Credit]
	FROM tbReceipt R
	CROSS APPLY (
		SELECT 
			MAX(GL.ID) AS GLAcctID,
			MAX(FR.ReceiptID) AS ReceiptID,
			MAX(FR.FreightID) AS FreightID,
			SUM(FR.AmountReven) AS AmountReven,
			MAX(FR.FreightReceiptType) AS FreightReceiptType
		FROM FreightReceipt FR
		INNER JOIN Freight F ON F.ID = FR.FreightID
		INNER JOIN tbGLAccount GL ON GL.ID = F.RevenAcctID
		WHERE FR.ReceiptID = R.ReceiptID AND FR.AmountReven > 0
		GROUP BY GL.ID
	) TFR WHERE TFR.ReceiptID = @receiptId
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	-- Credit from Revenue
	DELETE FROM @journalMapSet;
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(TIM.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(TIM.[GLAcctID]) AS [GLAcctID],
		0 AS [Debit],
		SUM(TIM.[RevenueAmount]) AS [Credit]	
	FROM  (
		SELECT
			MAX(TR.ReceiptID) AS [ReceiptID],
			MAX(TR.ItemID) AS [ItemID],
			MAX(TR.ItemGroupID) AS [ItemGroupID],
			MAX(GL.ID) AS [GLAcctID],
			MAX(TR.[RevenueAmount]) AS [RevenueAmount]	
		FROM pos_ufnGetItemBalance(@receiptId) TR
		CROSS APPLY pos_ufnGetItemAccounting(TR.ReceiptID) IA 	
		INNER JOIN tbGLAccount GL ON IA.RevenueAccount = GL.Code
		WHERE TR.ItemGroupID = IA.ItemGroupID OR TR.ItemID = IA.ItemID
		GROUP BY TR.ItemID
	) TIM GROUP BY TIM.GLAcctID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Debit from COGS (Cost Of Good Sold)
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(TIM.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(TIM.[GLAcctID]) AS [GLAcctID],
		ABS(SUM(IA.Trans_Valuse)) AS [Debit],
		0 AS [Credit]
	FROM 
	tbInventoryAudit IA 
	INNER JOIN(
		SELECT
			MAX(IM.[SeriesDetailID]) AS [SeriesDetailID],
			MAX(IM.ReceiptID) AS [ReceiptID],
			MAX(IB.ItemID) AS [ItemID],
			MAX(IB.ItemGroupID) AS [ItemGroupID],
			MAX(GL.ID) AS [GLAcctID]
		FROM pos_ufnGetReceiptItemsWithBoM(@receiptId) IM
		CROSS APPLY pos_ufnGetItemBalance(IM.ReceiptID) IB
		CROSS APPLY pos_ufnGetItemAccounting(IM.ReceiptID) IAC
		INNER JOIN tbGLAccount GL ON GL.Code = IAC.CostofGoodsSoldAccount
		WHERE (IB.ItemGroupID = IAC.ItemGroupID OR IB.ItemID = IAC.ItemID) 
		GROUP BY IB.ItemID, GL.ID
	) TIM ON TIM.SeriesDetailID = IA.SeriesDetailID AND TIM.ItemID = IA.ItemID
	GROUP BY IA.ItemID, TIM.GLAcctID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	-- Credit from Inventory
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(TIM.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(TIM.[GLAcctID]) AS [GLAcctID],
		0 AS [Debit],
		ABS(SUM(IA.Trans_Valuse)) AS [Credit]
	FROM 
	tbInventoryAudit IA 
	INNER JOIN(
		SELECT
			MAX(IM.[SeriesDetailID]) AS [SeriesDetailID],
			MAX(IM.ReceiptID) AS [ReceiptID],
			MAX(IB.ItemID) AS [ItemID],
			MAX(IB.ItemGroupID) AS [ItemGroupID],
			MAX(GL.ID) AS [GLAcctID]
		FROM pos_ufnGetReceiptItemsWithBoM(@receiptId) IM
		CROSS APPLY pos_ufnGetItemBalance(IM.ReceiptID) IB
		CROSS APPLY pos_ufnGetItemAccounting(IM.ReceiptID) IAC
		INNER JOIN tbGLAccount GL ON GL.Code = IAC.InventoryAccount
		WHERE (IB.ItemGroupID = IAC.ItemGroupID OR IB.ItemID = IAC.ItemID) 
		GROUP BY IB.ItemID, GL.ID
	) TIM ON TIM.SeriesDetailID = IA.SeriesDetailID AND TIM.ItemID = IA.ItemID
	GROUP BY IA.ItemID, TIM.GLAcctID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	----Debit from Member cards
	--INSERT INTO @journalMapSet 
	--SELECT
	--	@receiptId AS [ReceiptID],
	--	0 AS [BPAcctID],
	--	GL.ID AS [GLAcctID],
	--	MP.Amount AS [Debit],
	--	0 AS [Credit]
	--FROM AccountMemberCards MC
	--INNER JOIN tbGLAccount GL ON GL.ID = MC.UnearnedRevenueID
	--INNER JOIN MultiPaymentMean MP ON MP.ReceiptID = @receiptId AND [Type] = 1 -- PaymentMeanType.CardMember
	--EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Debit from Payment Means
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet
	SELECT 
		MAX(R.ReceiptID) AS [ReceiptID],
		MAX(0) AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		SUM(MP.Amount * MP.SCRate * R.ExchangeRate) AS [Debit],
		0 AS [Credit]
	FROM tbReceipt R
	LEFT JOIN MultiPaymentMean MP ON MP.ReceiptID = R.ReceiptID
	INNER JOIN tbPaymentMeans PM ON PM.ID = MP.PaymentMeanID
	INNER JOIN tbGLAccount GL ON GL.ID = PM.AccountID
	WHERE MP.Amount > 0 AND R.ReceiptID = @receiptId
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Credit from Customer (Invoice)
	DELETE FROM @journalMapSet;
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(R.ReceiptID) AS [ReceiptID],
		MAX(R.CustomerID) AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		0 AS [Debit],
		SUM(MP.Amount * MP.SCRate * R.ExchangeRate) AS [Credit]
	FROM tbReceipt R
	INNER JOIN tbBusinessPartner BP ON R.CustomerID = BP.ID
	LEFT JOIN MultiPaymentMean MP ON MP.ReceiptID = R.ReceiptID
	INNER JOIN tbPaymentMeans PM ON PM.ID = MP.PaymentMeanID
	INNER JOIN tbGLAccount GL ON GL.ID = BP.GLAccID
	WHERE MP.Amount > 0 AND R.ReceiptID = @receiptId
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet
END

GO


