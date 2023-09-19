

CREATE OR ALTER FUNCTION [dbo].[pos_ufnNewInventoryAudit](
	@receiptId int
) RETURNS TABLE AS RETURN (
	SELECT
		MAX(R.WarehouseID) AS [WarehouseID],
		MAX(R.BranchID) AS [BranchID],
		MAX(R.UserOrderID) AS [UserID],
		MAX(TIA.ItemID) AS [ItemID],
		MAX(R.SysCurrencyID) AS [CurrencyID],
		MAX(TIA.InventoryUomID) AS [InventoryUomID],
		MAX(R.ReceiptNo) AS [InvoiceNo],
		MAX(DT.Code) AS [Trans_Type],
		MAX(IM.Process) AS [Process],
		MAX(CONVERT(DATE, GETDATE())) AS [SystemDate],
		MAX(FORMAT(GETDATE(), 'hh:mm tt')) AS [TimeIn],
		MAX(-1 * ABS(TIA.[OutStock])) AS [Qty],
		MAX(CASE 
				WHEN UPPER(IM.Process) IN ('FIFO', 'SERIAL', 'BATCH') THEN TIA.Cost
				WHEN UPPER(IM.Process) = 'AVERAGE' THEN TIA.AvgCost
				WHEN UPPER(IM.Process) = 'STANDARD' THEN TIA.StdCost END
		) AS [Cost],
		MAX(0) AS [Price],
	  MAX(CASE WHEN UPPER(IM.Process) = 'STANDARD' THEN TIA.StdCumulativeQty ELSE TIA.[CumulativeQty] END) AS [CumulativeQty],
	  MAX(CASE 
				WHEN UPPER(IM.Process) IN ('FIFO', 'SERIAL', 'BATCH') THEN TIA.CumulativeValue
				WHEN UPPER(IM.Process) = 'AVERAGE' THEN TIA.AvgCumulativeValue
				WHEN UPPER(IM.Process) = 'STANDARD' THEN TIA.StdCumulativeValue END
		) AS [CumulativeValue],
		MAX(CASE 
				WHEN UPPER(IM.Process) IN ('FIFO', 'SERIAL', 'BATCH') THEN -1 * TIA.TransValue
				WHEN UPPER(IM.Process) = 'AVERAGE' THEN -1 * TIA.AvgTransValue
				WHEN UPPER(IM.Process) = 'STANDARD' THEN -1 * TIA.StdTransValue END
		) AS [Trans_Valuse],
		MAX(ISNULL(WD.[ExpireDate], '0001-01-01T00:00:00')) AS [ExpireDate],
		MAX(R.LocalCurrencyID) AS [LocalCurID],
		MAX(R.LocalSetRate) AS [LocalSetRate],
		MAX(R.CompanyID) AS [CompanyID],
		MAX(DT.ID) AS [DocumentTypeID],
		MAX(R.SeriesDID) AS [SeriesDetailID],
		MAX(R.SeriesID) AS [SeriesID],
		MAX(RD.ItemType) AS [TypeItem],
		MAX(TIA.LineID) AS [LineID],
		MAX(R.PostingDate) AS [PostingDate],
		MAX(TIA.OutStock) AS [OpenQty]
	FROM pos_ufnGetInventoryAuditMap(@receiptId) TIA
	LEFT JOIN tbItemMasterData IM ON IM.ID = TIA.ItemID 
	LEFT JOIN tbWarehouseDetail WD ON TIA.ItemID = WD.ItemID
	INNER JOIN tbReceipt R ON R.ReceiptID = TIA.ReceiptID
	INNER JOIN tbSeries SR ON SR.ID = R.SeriesID
	INNER JOIN tbDocumentType DT ON SR.DocuTypeID = DT.ID
	LEFT JOIN tbReceiptDetail RD ON RD.ItemID = TIA.ItemID
	GROUP BY TIA.WarehouseDetailID, TIA.ItemID
)
GO


