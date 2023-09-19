

CREATE OR ALTER PROC [dbo].[pos_uspUpdateCommitStockWarehouseSummary](@orderId INT, @warehouseId INT)
AS BEGIN
	UPDATE WS
	SET 
		WS.[Committed] += TOD.TotalPrintQty
	FROM tbWarehouseSummary WS 
	INNER JOIN (
		SELECT
			MAX(OD.OrderID) OrderID,
			MAX(OD.ItemID) ItemID,
			SUM(OD.Qty * GDU.Factor) TotalQty,
			SUM(OD.PrintQty * GDU.Factor) TotalPrintQty
		FROM tbOrderDetail OD 
		INNER JOIN tbOrder O ON OD.OrderID = O.OrderID
		INNER JOIN tbGroupDefindUoM GDU ON OD.UomID = GDU.AltUOM AND OD.GroupUomID = GDU.GroupUoMID
		WHERE O.OrderID = @orderId
		GROUP BY OD.ItemID
	) TOD ON TOD.ItemID = WS.ItemID AND WS.WarehouseID = @warehouseId;

	UPDATE OD
	SET OD.PrintQty = 0
	FROM tbOrderDetail OD 
	INNER JOIN tbWarehouseSummary WS ON WS.ItemID = OD.ItemID AND WS.WarehouseID = @warehouseId
	WHERE OD.OrderID = @orderId
END
GO


