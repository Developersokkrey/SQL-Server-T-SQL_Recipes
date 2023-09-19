

CREATE OR ALTER PROC pos_uspAddInventoryAudit(@receiptId int)
AS BEGIN
	INSERT INTO [dbo].[tbInventoryAudit]
    ([WarehouseID]
    ,[BranchID]
    ,[UserID]
    ,[ItemID]
    ,[CurrencyID]
    ,[UomID]
    ,[InvoiceNo]
    ,[Trans_Type]
    ,[Process]
    ,[SystemDate]
    ,[TimeIn]
    ,[Qty]
    ,[Cost]
    ,[Price]
    ,[CumulativeQty]
    ,[CumulativeValue]
    ,[Trans_Valuse]
    ,[ExpireDate]
    ,[LocalCurID]
    ,[LocalSetRate]
    ,[CompanyID]
    ,[DocumentTypeID]
    ,[SeriesDetailID]
    ,[SeriesID]
    ,[TypeItem]
    ,[LineID]
    ,[PostingDate]
    ,[OpenQty])
	SELECT * FROM pos_ufnNewInventoryAudit(@receiptId)
END; 
GO


