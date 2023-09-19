
CREATE OR ALTER  FUNCTION [dbo].[pos_ufnGetInventoryAuditMap](@receiptId int)
RETURNS TABLE AS RETURN(
	WITH
	R_CTE AS (
		SELECT * FROM tbReceipt R WHERE R.ReceiptID = @receiptId
	)
	, IA_CTE AS (
		SELECT 
			MAX(IA.ItemID) AS [ItemID],
			MAX(IA.Trans_Valuse) AS TransValue,
			SUM(IA.Qty) AS [CumulativeQty],
			SUM(IA.Trans_Valuse) AS [CumulativeValue]
		FROM tbInventoryAudit IA 
		GROUP BY IA.ItemID
	)
	SELECT 
		WD.ID AS [WarehouseDetailID],
		WD.ReceiptID AS [ReceiptID],
		WD.LineID AS [LineID],
		WD.ItemID AS [ItemID],
		WD.InventoryUomID AS [InventoryUomID],
		WD.UomID AS [UomID],
		WD.Process AS [Process],
		WD.OutStock AS [OutStock],
		WD.Cost AS [Cost],
		WD.AvgCost AS [AvgCost],
		WD.StdCost AS [StdCost],
		WD.TransValue AS [TransValue],
		WD.AvgTransValue AS [AvgTransValue],
		WD.StdTransValue AS [StdTransValue],
		ISNULL(IA.CumulativeQty, 0) - WD.TotalOutStock AS [CumulativeQty],
		ISNULL(IA.CumulativeQty, 0) - WD.ItemQty AS [StdCumulativeQty],
		ISNULL(IA.CumulativeValue, 0) - WD.TotalTransValue AS [CumulativeValue],
		ISNULL(IA.CumulativeValue, 0) - WD.AvgTotalTransValue AS [AvgCumulativeValue],
		ISNULL(IA.CumulativeValue, 0) - WD.StdTotalTransValue AS [StdCumulativeValue]
	FROM R_CTE R 
	CROSS APPLY pos_ufnGetWarehouseDetailMapUnionAll(R.ReceiptID, R.WarehouseID) WD
	LEFT JOIN IA_CTE IA ON IA.ItemID = WD.ItemID
);


GO


