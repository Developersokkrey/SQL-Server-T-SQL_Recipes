
CREATE OR ALTER FUNCTION [dbo].[pos_ufnGetWarehouseDetailMap](
	@receiptId int,
	@warehouseId int
)
RETURNS TABLE AS 
RETURN (
	WITH
	IM_NO_SB_CTE AS (
		SELECT * FROM pos_ufnGetReceiptItemsWithBoM(@receiptId) WHERE UPPER(Process) NOT IN('SERIAL', 'BATCH')
	),
	CTE
	AS (
		SELECT
			MAX(ISNULL(WD.ID, 0)) AS ID,
			MAX(TIM.ReceiptID) AS ReceiptID,
			MAX(TIM.WarehouseID) AS WarehouseID,
			MAX(TIM.LineID) AS [LineID],
			MAX(TIM.ItemID) AS ItemID,
			MAX(TIM.InventoryUomID) AS [InventoryUomID],
			MAX(TIM.UomID) AS UomID,
			MAX(TIM.GroupUomID) AS GroupUomID,
			Layer = ROW_NUMBER() OVER(ORDER BY WD.ID),
			MAX(TIM.Process) AS [Process],
			MAX(ISNULL(WD.Cost, 0)) AS Cost,
			MAX(ISNULL(WD.AvgCost, 0)) AS AvgCost,
			MAX(ISNULL(RD.Cost, 0)) AS StdCost,
			MAX(ISNULL(WD.InStock, 0)) AS BaseStock,
			MAX(TIM.Qty) AS ItemQty
		FROM IM_NO_SB_CTE TIM
		LEFT JOIN tbWarehouseDetail WD ON WD.ItemID = TIM.ItemID AND WD.WarehouseID = TIM.WarehouseID AND WD.InStock > 0
		LEFT JOIN tbReceiptDetail RD ON RD.ItemID = TIM.ItemID AND RD.ReceiptID = TIM.ReceiptID
		GROUP BY TIM.ItemID, WD.Cost, WD.ID
	),
	CTE1 AS (
		SELECT
			CT.*,
			TotalBaseStock = (SELECT SUM(CC.BaseStock) from CTE CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID)
		FROM CTE CT
	),
	CTE2 AS (
		SELECT 
			C2.*,
			C2.TotalBaseStock - C2.ItemQty AS RemainQty,
			CASE WHEN UPPER(C2.Process) = 'STANDARD' THEN C2.ItemQty ELSE 
				CASE WHEN C2.TotalBaseStock - C2.ItemQty < 0 THEN C2.BaseStock 
				ELSE C2.BaseStock - ABS(C2.TotalBaseStock - C2.ItemQty) END
			END AS OutStock,
		CASE WHEN C2.TotalBaseStock < C2.ItemQty THEN 0 ELSE C2.TotalBaseStock - C2.ItemQty END AS InStock
		FROM CTE1 C2
	),
	CTE3 AS (
		SELECT C2.*,
		(SELECT SUM(CC2.OutStock) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS TotalOutStock,
		(SELECT SUM(CC2.InStock) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS TotalInStock,
		C2.OutStock * C2.Cost AS TransValue,
		C2.OutStock * C2.AvgCost AS AvgTransValue,
		C2.ItemQty * C2.StdCost AS StdTransValue,
		(SELECT SUM(CC2.OutStock * CC2.Cost) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS [TotalTransValue],
		(SELECT SUM(CC2.OutStock * CC2.AvgCost) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS [AvgTotalTransValue],
		(SELECT SUM(CC2.OutStock * CC2.StdCost) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS [StdTotalTransValue]
		FROM CTE2 C2		
		WHERE C2.OutStock > 0
	)
	SELECT DISTINCT CTE3.* FROM CTE3
);
GO


