-------------------------------- SELECT DISTINCT ------------------------------------
SELECT 
    R.*
FROM tbReceipt R
INNER JOIN(
    SELECT DISTINCT R.ReceiptID FROM tbReceipt R
         INNER JOIN (SELECT ReceiptID FROM tbReceiptDetail
         ) AS RD 
         ON R.ReceiptID = RD.ReceiptID
) TR ON TR.ReceiptID = R.ReceiptID


--------------------------------  CROSS JOIN ------------------------------------
SELECT C.*,U.[Name] AS UserName FROM CUSMER C
         CROSS JOIN UERACC U

SELECT C.*,U.[Name] AS UserName FROM CUSMER C
         CROSS JOIN BRANCH U


-------------------------------- UPDATE JOIN SELECT LAST ------------------------------------
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
    
-------------------------------- SELECT NESTED JSON ------------------------------------
SELECT
    ent.Id AS 'Id',
    ent.Name AS 'Name',
    ent.Age AS 'Age',
    EMails = (
        SELECT
            Emails.Id AS 'Id',
            Emails.Email AS 'Email'
        FROM EntitiesEmails Emails WHERE Emails.EntityId = ent.Id
        FOR JSON PATH
    )
FROM Entities ent
FOR JSON PATH
