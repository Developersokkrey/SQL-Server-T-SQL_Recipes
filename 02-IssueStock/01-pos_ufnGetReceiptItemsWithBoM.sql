
CREATE OR ALTER   FUNCTION [dbo].[pos_ufnGetReceiptItemsWithBoM](@receiptId int)
RETURNS TABLE AS RETURN(
	WITH RD_CTE AS (
		SELECT			
			R.SeriesDID AS [SeriesDetailID],
			RD.ReceiptID AS [ReceiptID], 
			R.WarehouseID AS [WarehouseID],
			RD.LineID AS [LineID],
			RD.ItemID AS [ItemID],
			RD.UomID AS [UomID],
			0 AS [NegativeStock],
			RD.Qty AS [BaseQty]
		FROM tbReceipt R
		INNER JOIN tbReceiptDetail RD ON R.ReceiptID = RD.ReceiptID
		WHERE R.ReceiptID = @receiptId
	),
	BM_CTE AS (
		SELECT * FROM RD_CTE
		UNION ALL
		SELECT	
			IRD.SeriesDetailID AS [SeriesDetailID],
			IRD.ReceiptID AS ReceiptID,
			IRD.WarehouseID AS WarehouseID,
			'' AS [LineID],
			BMD.ItemID AS ItemID,
			BMD.UomID AS UomID,
			CONVERT(bit, 1 * BMD.NegativeStock) AS [NegativeStock],
			BMD.Qty * IRD.BaseQty AS BaseQty
		FROM RD_CTE IRD
		LEFT JOIN tbBOMaterial BM ON BM.ItemID = IRD.ItemID
		INNER JOIN tbBOMDetail BMD ON BM.BID = BMD.BID 
		WHERE BM.[Active] = 1
	)
	SELECT		
			MAX(BMD.SeriesDetailID) AS [SeriesDetailID],
			MAX(BMD.ReceiptID) AS [ReceiptID],
			MAX(BMD.WarehouseID) AS [WarehouseID],
			MAX(BMD.LineID) AS [LineID],
			MAX(BMD.ItemID) AS [ItemID],
			MAX(IM.InventoryUoMID) AS [InventoryUomID],
			MAX(BMD.UomID) AS [UomID],
			MAX(GDU.GroupUoMID) AS [GroupUomID],
			CONVERT(bit, MAX(1 * BMD.NegativeStock)) AS [IsAllowedNegativeStock],
			MAX(GDU.Factor) AS [Factor],
			SUM(BMD.BaseQty) AS [BaseQty],
			SUM(BMD.BaseQty * GDU.Factor) AS [Qty],
			MAX(IM.[Process]) AS [Process]
	FROM BM_CTE BMD
	INNER JOIN tbItemMasterData IM ON IM.ID = BMD.ItemID 
	INNER JOIN tbGroupDefindUoM GDU ON BMD.UomID = GDU.AltUOM AND IM.GroupUomID = GDU.GroupUoMID
	GROUP BY BMD.ReceiptID, BMD.ItemID
)


--------------------------------------------------------------------[pos_ufnGetWarehouseDetailMap] 02-IssueStock------------------------------------------------------------------

