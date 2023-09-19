


CREATE OR ALTER PROC [dbo].[pos_uspAddStockout] (
	@warehouseDetailMapSet [WarehouseDetailMap] READONLY,
	@stockOutMapSet [StockOutMap] READONLY
)
AS BEGIN

	INSERT INTO [dbo].[StockOut]
		([FromWareDetialID]
		,[WarehouseID]
		,[UomID]
		,[UserID]
		,[SyetemDate]
		,[TimeIn]
		,[InStock]
		,[CurrencyID]
		,[ExpireDate]
		,[ItemID]
		,[Cost]
		,[MfrSerialNumber]
		,[SerialNumber]
		,[BatchNo]
		,[BatchAttr1]
		,[BatchAttr2]
		,[MfrDate]
		,[AdmissionDate]
		,[Location]
		,[Details]
		,[SysNum]
		,[LotNumber]
		,[MfrWarDateStart]
		,[MfrWarDateEnd]
		,[TransType]
		,[ProcessItem]
		,[BPID]
		,[Direction]
		,[OutStockFrom]
		,[TransID]
		,[Contract]
		,[PlateNumber]
		,[Brand]
		,[Color]
		,[Condition]
		,[Power]
		,[Type]
		,[Year]
		,[BaseOnID]
		,[PurCopyType])
			
		SELECT DISTINCT
		WD.ID AS [FromWareDetialID]
		,WD.WarehouseID AS [WarehouseID]
		,TX.UomID
		,TX.UserID AS UserID
		,WD.SyetemDate
		,WD.TimeIn
		,WDS.OutStock
		,WD.CurrencyID
		,WD.[ExpireDate]
		,WD.ItemID
		,WD.Cost
		,WD.MfrSerialNumber
		,WD.SerialNumber
		,WD.BatchNo
		,WD.BatchAttr1
		,WD.BatchAttr2
		,WD.MfrDate
		,WD.AdmissionDate
		,WD.[Location]
		,WD.Details
		,WD.SysNum
		,WD.LotNumber
		,WD.MfrWarDateStart
		,WD.MfrWarDateEnd
		,14 --TransTypeWD.POS
		,TX.ProcessItem
		,TX.BPID
		,WD.Direction
		,TX.TransID AS OutStockFrom
		,TX.TransID AS TransID
		,TX.[ContractID] AS [Contract]
		,WD.PlateNumber
		,WD.Brand
		,WD.Color
		,WD.Condition
		,WD.[Power]
		,WD.[Type]
		,WD.[Year]
		,WD.BaseOnID
		,WD.PurCopyType
		FROM tbWarehouseDetail WD
		INNER JOIN @warehouseDetailMapSet WDS ON WD.ID = WDS.ID
		INNER JOIN @stockOutMapSet TX ON WD.ItemID = TX.ItemID	AND TX.WarehouseID = WD.WarehouseID
END
GO


