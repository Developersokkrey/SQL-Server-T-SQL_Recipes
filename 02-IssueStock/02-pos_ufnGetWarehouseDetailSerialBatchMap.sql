
CREATE OR ALTER FUNCTION pos_ufnGetWarehouseDetailSerialBatchMap(@receiptId int, @warehouseId int)
RETURNS TABLE AS RETURN(
	WITH im_cte AS (
		SELECT DISTINCT
			IM.*, 
			RD.ID AS ReceiptDetailID 
		FROM tbReceiptDetail RD
		CROSS APPLY pos_ufnGetReceiptItemsWithBoM(RD.ReceiptID) IM
		WHERE UPPER(IM.Process) IN ('SERIAL','BATCH') AND RD.ReceiptID = @receiptId
	),
	im_sub_cte AS (
		SELECT 
			IM.WarehouseID,
			IM.ReceiptDetailID,
			IM.ItemID,
			IM.Process
		FROM im_cte IM
	),
	im_sr_cte AS (
		SELECT
			WD.ID AS [WDID],
			RDS.LineID AS [LineID],
			IM.ItemID AS [ItemID],
			RDS.SerialNo AS [SerialNo],
			'' AS [BatchNo],
			RDS.OpenQty AS [OpenQty],
			WD.InStock,
			WD.Cost,
			Layer = ROW_NUMBER() OVER(ORDER BY WD.ID)
		FROM im_sub_cte IM
		INNER JOIN tbReceiptDetailSerial RDS ON RDS.ReceiptDetailID = IM.ReceiptDetailID AND RDS.ItemID = IM.ItemID
		INNER JOIN tbWarehouseDetail WD ON WD.WarehouseID = IM.WarehouseID
		WHERE WD.ItemID = IM.ItemID AND WD.InStock > 0 AND WD.SerialNumber = RDS.SerialNo
	),
	im_bc_cte AS (
		SELECT 
			WD.ID AS [WDID],
			RDB.LineID AS [LineID],
			IM.ItemID AS [ItemID],
			'' AS [SerialNo],
			RDB.BatchNo AS [BatchNo],
			RDB.OpenQty AS [OpenQty],
			WD.InStock,
			WD.Cost,
			Layer = ROW_NUMBER() OVER(ORDER BY WD.ID)
		FROM im_sub_cte IM
		INNER JOIN tbReceiptDetailBatch RDB  ON RDB.ReceiptDetailID = IM.ReceiptDetailID AND RDB.ItemID = IM.ItemID
		INNER JOIN tbWarehouseDetail WD ON WD.WarehouseID = IM.WarehouseID
		WHERE WD.ItemID = IM.ItemID AND WD.InStock > 0 AND WD.BatchNo = RDB.BatchNo
	),
	sb_cte AS (
		SELECT * FROM im_sr_cte
		UNION ALL
		SELECT * FROM im_bc_cte
	),
	sbs_cte AS (
		SELECT 
		CT.WDID,
		TotalBaseStock = (SELECT SUM(CC.InStock) from sb_cte CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID),
		TotalOutStock = (SELECT SUM(CC.OpenQty) from sb_cte CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID),
		TotalInStock = (SELECT SUM(CC.InStock) - SUM(CC.OpenQty) from sb_cte CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID),
		TotalTransValue = (SELECT SUM(CC.OpenQty * CC.Cost) from sb_cte CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID)
		FROM sb_cte CT
	)
	SELECT
			MAX(ISNULL(TWD.[WDID], 0)) AS ID,
			MAX(IM.ReceiptID) AS ReceiptID,
			MAX(IM.WarehouseID) AS WarehouseID,
			MAX(TWD.LineID) AS [LineID],
			MAX(TWD.ItemID) AS ItemID,
			MAX(IM.InventoryUomID) AS [InventoryUomID],
			MAX(IM.UomID) AS UomID,
			MAX(IM.GroupUomID) AS GroupUomID,
			Layer = ROW_NUMBER() OVER(ORDER BY TWD.[WDID]),
			MAX(IM.Process) AS [Process],
			MAX(ISNULL(TWD.Cost, 0)) AS Cost,
			MAX(0) AS AvgCost,
			MAX(0) AS StdCost,
			MAX(ISNULL(TWD.InStock, 0)) AS BaseStock,
			MAX(TWD.OpenQty) AS ItemQty,
			MAX(WDS.TotalBaseStock) AS [TotalBaseStock],
			MAX(TWD.InStock - TWD.OpenQty) AS [RemainQty],
			MAX(TWD.OpenQty) AS [OutStock],
			MAX(TWD.InStock - TWD.OpenQty) AS [InStock],
			MAX(WDS.TotalOutStock) AS [TotalOutStock],
			MAX(WDS.TotalInStock) AS TotalInStock,
			MAX(TWD.Cost * TWD.OpenQty) AS [TransValue],
			MAX(0) [AvgTransValue],
			MAX(0) [StdTransValue],
			MAX(WDS.TotalTransValue) AS [TotalTransValue],
			MAX(0) AS [AvgTotalTransValue],
			MAX(0) AS [StdTotalTransValue]
		FROM sb_cte TWD
		INNER JOIN sbs_cte WDS ON TWD.WDID = WDS.WDID
		INNER JOIN im_cte IM ON TWD.ItemID = IM.ItemID
		GROUP BY TWD.[WDID], TWD.ItemID, TWD.Cost, TWD.SerialNo, TWD.BatchNo
);