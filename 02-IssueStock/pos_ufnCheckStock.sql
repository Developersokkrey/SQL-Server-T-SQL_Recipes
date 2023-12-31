

ALTER  FUNCTION [dbo].[pos_ufnCheckStock](@tempOrderId bigint)
RETURNS TABLE AS 
RETURN (
	WITH RD_CTE AS (
		SELECT			
			RD.LineID AS [LineID],
			RD.ItemID AS ItemID,
			RD.UomID AS UomID,
			0 AS [NegativeStock],
			RD.PrintQty AS BaseQty
		FROM TempOrder R
		INNER JOIN TempOrderItem RD ON R.TempOrderID = RD.TempOrderID
		WHERE R.TempOrderID = @tempOrderId
	),
	BM_CTE AS (
		SELECT * FROM RD_CTE
		UNION
		SELECT	
			'0' AS [LineID],
			BMD.ItemID AS ItemID,
			BMD.UomID AS UomID,
			CONVERT(bit, 1 * BMD.NegativeStock) AS [NegativeStock],
			BMD.Qty * IRD.BaseQty AS BaseQty
		FROM RD_CTE IRD
		LEFT JOIN tbBOMaterial BM ON BM.ItemID = IRD.ItemID
		INNER JOIN tbBOMDetail BMD ON BM.BID = BMD.BID 
		WHERE BM.[Active] = 1
	),
	ALL_CTE AS (
		SELECT		
			MAX(BMD.LineID) AS [LineID],
			MAX(BMD.ItemID) AS ItemID,
			MAX(BMD.UomID) AS UomID,
			MAX(GDU.GroupUoMID) AS [GroupUomID],
			CONVERT(bit, MAX(1 * BMD.NegativeStock)) AS [IsAllowedNegativeStock],
			SUM(BMD.BaseQty) AS Qty,
			MAX(IM.[Process]) AS [Process]
		FROM BM_CTE BMD
		INNER JOIN tbItemMasterData IM ON IM.ID = BMD.ItemID AND IM.[Delete] = 0
		INNER JOIN tbGroupDefindUoM GDU ON BMD.UomID = GDU.AltUOM AND IM.GroupUomID = GDU.GroupUoMID
		INNER JOIN tbWarehouseSummary WS ON IM.ID = WS.ItemID
		GROUP BY BMD.ItemID
	)
	SELECT * FROM (
		SELECT
			MAX(IMC.LineID) AS LineID,
			MAX(IMC.ItemID) AS ItemID,
			MAX(IM.Code) AS Code,
			MAX(IM.KhmerName) AS KhmerName,
			MAX(WS.InStock) AS InStock,
			MAX(WS.InStock - WS.[Committed] - IMC.Qty) AS TotalStock,
			MAX(IMC.Qty) AS [OrderQty],
			MAX(WS.[Committed]) AS [Committed],
			MAX(UM.[Name]) AS [Uom],
			MAX(CASE WHEN UPPER(IM.Process) IN ('SERIAL', 'BATCH') THEN 1 ELSE 0 END) AS IsSerailBatch
		FROM ALL_CTE IMC
		INNER JOIN tbItemMasterData IM ON IMC.ItemID = IM.ID
		INNER JOIN tbUnitofMeasure UM ON IMC.UomID = UM.ID
		INNER JOIN tbWarehouseSummary WS ON IM.ID = WS.ItemID
		WHERE UPPER(IM.Process) != 'STANDARD'
		GROUP BY IM.ID
	) T 
	--WHERE T.TotalStock < 0
)
