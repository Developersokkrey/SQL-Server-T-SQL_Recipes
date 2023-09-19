
CREATE OR ALTER PROC pos_uspUpdateStockWarehouseSummary(@receiptId int)
AS BEGIN
	UPDATE WS 
		SET WS.CumulativeValue = TWS.CumulativeValue,
			WS.InStock = TWS.[InStock],
			WS.[Committed] = TWS.[Committed]
		FROM tbWarehouseSummary WS
		INNER JOIN (
			SELECT	
				MAX(WS.ID) AS [ID],
				MAX(IA.ItemID) AS [ItemID],
				MAX(WS.InStock) - ABS(SUM(IA.Qty)) AS [InStock],
				MAX(WS.CumulativeValue) - ABS(SUM(IA.Trans_Valuse)) AS [CumulativeValue],
				CASE WHEN MAX(WS.[Committed]) > ABS(SUM(IA.Qty)) 
					THEN MAX(WS.[Committed]) - ABS(SUM(IA.Qty)) ELSE 0 END
				AS [Committed]
			FROM tbWarehouseSummary WS
			INNER JOIN pos_ufnNewInventoryAudit(@receiptId) IA ON WS.ItemID = IA.ItemID AND WS.WarehouseID = IA.WarehouseID
			GROUP BY WS.ID, IA.ItemID
		) TWS ON TWS.ID = WS.ID
END;