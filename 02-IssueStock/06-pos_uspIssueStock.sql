

CREATE OR ALTER PROC [dbo].[pos_uspIssueStock](@receiptId int)
AS
BEGIN
	BEGIN TRY
		BEGIN TRAN
		DECLARE @warehouseDetailMapSet [WarehouseDetailMap];
		DECLARE @stockOutMapSet [StockOutMap];

		INSERT INTO @warehouseDetailMapSet 
		SELECT DISTINCT TWD.* FROM tbReceipt R
		CROSS APPLY pos_ufnGetWarehouseDetailMapUnionAll(R.ReceiptID, R.WarehouseID) AS TWD
		WHERE R.ReceiptID = @receiptId

		INSERT INTO @stockOutMapSet
		SELECT 
			WDS.ItemID,
			R.WarehouseID,
			WDS.UomID,
			R.UserDiscountID AS UserID,
			R.ReceiptID AS [TransID],
			IM.ContractID AS [ContractID],
			R.ReceiptID  AS [OutStockFromID],
			R.CustomerID AS [BPID],
			WDS.OutStock AS [InStock],
			CASE 
				WHEN UPPER(IM.Process) = 'FIFO' THEN 1
				WHEN UPPER(IM.Process) = 'FEFO' THEN 2
				WHEN UPPER(IM.Process) = 'STANDARD' THEN 3
				WHEN UPPER(IM.Process) = 'AVERAGE' THEN 4
				WHEN UPPER(IM.Process) IN ('SERIAL', 'BATCH') THEN 5
			END AS [ProcessItem]
		FROM 
		@warehouseDetailMapSet WDS
		INNER JOIN tbItemMasterData IM ON IM.ID = WDS.ItemID
		CROSS APPLY tbReceipt R WHERE R.ReceiptID = WDS.ReceiptID AND UPPER(IM.Process) != 'STANDARD'
		EXEC pos_uspAddStockout	@warehouseDetailMapSet, @stockOutMapSet

		--Update [CumulativeValue] in table [tbWarehouseSummary] from previous inventory audit.
		EXEC pos_uspUpdateStockWarehouseSummary @receiptId

		--Add a new row to table [tbInventoryAudit]
		EXEC pos_uspAddInventoryAudit @receiptId
		
		--Update [InStock] of table [tbWarehouseDetail]
		UPDATE WD 
		SET WD.InStock = WDS.InStock
		FROM tbWarehouseDetail WD
		INNER JOIN (
			SELECT * FROM @warehouseDetailMapSet
		) AS WDS ON WD.ID = WDS.ID;

		--Update [Cost] in table [tbPriceListDetail]
		UPDATE PLD 
		SET PLD.Cost = TC.AvgCost * XR.SetRate * GDU.Factor
		FROM tbPriceListDetail PLD
		INNER JOIN (
			SELECT * FROM pos_ufnGetInventoryAuditMap(@receiptId)
		) AS TC ON PLD.ItemID = TC.ItemID
		INNER JOIN tbExchangeRate XR ON XR.CurrencyID = PLD.CurrencyID
		INNER JOIN tbItemMasterData IM ON IM.ID = PLD.ItemID 
		INNER JOIN tbGroupDefindUoM GDU ON GDU.GroupUoMID = IM.GroupUomID AND GDU.AltUOM = PLD.UomID

		COMMIT
	END TRY
	BEGIN CATCH
	 ROLLBACK
	END CATCH
END
GO


