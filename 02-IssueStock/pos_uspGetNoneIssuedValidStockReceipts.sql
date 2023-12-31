

CREATE OR ALTER PROCEDURE [dbo].[pos_uspGetNoneIssuedValidStockReceipts]
AS
BEGIN
	SELECT DISTINCT _r.* FROM tbReceipt _r INNER JOIN tbReceiptDetail _rd ON _r.ReceiptID = _rd.ReceiptID  
	WHERE _r.ReceiptID 
	NOT IN (
		SELECT DISTINCT r.ReceiptID FROM tbReceipt r 
		CROSS APPLY pos_ufnGetReceiptItemsWithBoM(r.ReceiptID) rd
		INNER JOIN tbItemMasterData im on rd.ItemID = im.ID AND UPPER(im.Process) != 'STANDARD'
		INNER JOIN tbWarehouseSummary ws on ws.ItemID = rd.ItemID and ws.WarehouseID = r.WarehouseID
			AND (ws.InStock <= 0 OR (ws.InStock - ws.[Committed]) < rd.Qty)	
		GROUP BY r.ReceiptID
	) AND _r.SeriesDID NOT IN (SELECT i.SeriesDetailID FROM tbInventoryAudit i)
END;