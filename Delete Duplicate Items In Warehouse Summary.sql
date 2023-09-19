DELETE WSO FROM  tbWarehouseSummary WSO
INNER JOIN(
	SELECT
		MIN(WS.ID) AS [WSID],
		WS.WarehouseID,
		WS.ItemID,
		COUNT(WS.ItemID) AS DuplicateCount
	FROM tbWarehouseSummary WS
	GROUP BY WS.WarehouseID, WS.ItemID
) TWS ON TWS.WarehouseID = WSO.WarehouseID AND TWS.ItemID = WSO.ItemID
WHERE TWS.DuplicateCount > 1 AND WSO.ID NOT IN(TWS.WSID)

----------------------------------------------------------------------

SELECT TWS.* FROM tbWarehouseSummary WSO
INNER JOIN(
SELECT 
	MIN(WS.ID) WSID,
	WS.WarehouseID,
	WS.ItemID,
	COUNT(WS.ItemID) AS DuplicateCount
 FROM tbWarehouseSummary WS 
	GROUP BY WS.WarehouseID , WS.ItemID
) TWS ON TWS.WarehouseID = WSO.WarehouseID AND TWS.ItemID = WSO.ItemID
WHERE TWS.DuplicateCount > 1 AND WSO.ID NOT IN(TWS.WSID)