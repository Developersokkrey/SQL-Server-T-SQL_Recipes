SELECT * FROM tbInventoryAudit
SELECT * FROM tbItemMasterData

UPDATE tbWarehouseSummary SET InStock=(SELECT CumulativeQty FROM tbInventoryAudit WHERE ID=(SELECT MAX(ID) 
FROM tbInventoryAudit WHERE ItemID = tbWarehouseSummary.ItemID))

SELECT * FROM tbWarehouseSummary
SELECT CumulativeQty FROM tbInventoryAudit WHERE ID= (SELECT MAX(ID) FROM tbInventoryAudit WHERE ItemID=1)  
SELECT * FROM tbInventoryAudit WHERE ItemID=1

SELECT MAX(IA.CumulativeQty) AS CumulativeQty, MAX(IA.ID) AS ID FROM tbWarehouseSummary WS 
JOIN tbInventoryAudit IA ON WS.ItemID = IA.ItemID AND IA.ItemID = 147 AND IA.WarehouseID = 1
GROUP BY IA.ID HAVING MAX(IA.ID) = IA.ID

UPDATE WS SET WS.InStock = IA.CumulativeQty, WS.CumulativeValue = IA.CumulativeValue
FROM tbWarehouseSummary WS
INNER JOIN tbInventoryAudit IA ON WS.WarehouseID = IA.WarehouseID AND WS.ItemID = IA.ItemID AND IA.ID IN(
SELECT _IA.ID FROM
( 
	SELECT MAX(IA.ID) AS ID, IA.ItemID AS ItemID FROM tbInventoryAudit IA
	 JOIN tbWarehouseSummary WS ON IA.WarehouseID = WS.WarehouseID AND IA.ItemID = WS.ItemID
	--WHERE IA.ItemID = 147 AND IA.WarehouseID = 1
	GROUP BY IA.ItemID
) AS _IA)

SELECT WS.*
FROM tbWarehouseSummary WS
INNER JOIN tbInventoryAudit IA ON WS.WarehouseID = IA.WarehouseID AND WS.ItemID = IA.ItemID AND IA.ID IN(
SELECT _IA.ID FROM
( 
	SELECT MAX(IA.ID) AS ID, IA.ItemID AS ItemID FROM tbInventoryAudit IA
	 JOIN tbWarehouseSummary WS ON IA.WarehouseID = WS.WarehouseID AND IA.ItemID = WS.ItemID
	--WHERE IA.ItemID = 147 AND IA.WarehouseID = 1
	GROUP BY IA.ItemID
) AS _IA) WHERE IA.ItemID = 147

SELECT * FROM tbInventoryAudit IA WHERE IA.ItemID = 143 AND IA.WarehouseID = 1
SELECT * FROM tbWarehouseSummary WS WHERE WS.ItemID = 143 AND WS.WarehouseID = 1