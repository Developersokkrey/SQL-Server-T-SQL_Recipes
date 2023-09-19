
CREATE OR ALTER FUNCTION pos_ufnGetWarehouseDetailMapUnionAll(@receiptId int, @warehouseId int)
RETURNS TABLE AS RETURN(
	SELECT * FROM pos_ufnGetWarehouseDetailMap(@receiptId, @warehouseId)
	UNION ALL 
	SELECT * FROM pos_ufnGetWarehouseDetailSerialBatchMap(@receiptId, @warehouseId)
);