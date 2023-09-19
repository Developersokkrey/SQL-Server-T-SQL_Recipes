--SELECT *  FROM tbSeries 
--SELECT sum(DiscountValue) from tbReceipt group by ReceiptID

--------------------------------------------
;WITH receipt_cte AS (
	SELECT 
		 R.*
		,R.DiscountValue * R.ExchangeRate AS [DisTotalSys]
		,TaxValue * R.ExchangeRate	AS [TaxValueSys]
		,GrandTotal_Sys * LocalSetRate AS [GrandTotal_LCC]
		FROM tbReceipt R
),
receipt_detail_cte AS (
	SELECT 
		RD.*
	   ,RD.DiscountValue *R.ExchangeRate AS [DisItemSys]
	   FROM tbReceipt R 
	INNER JOIN tbReceiptDetail RD ON R.ReceiptID = RD.ReceiptID
),
receipt_rpt_cte AS (
	SELECT 
	   MAX(R.SeriesDID) AS [ReceiptID]
	  ,MAX(R.AmountFreight) AS [AmountFreight]
	  ,MAX(DT.Code) AS [DouType]
	  ,MAX(EP.Code) AS [EmpCode]
	  ,MAX(EP.[Name]) AS [EmpName]
	  ,MAX(R.BranchID) AS [BranchID]
	  ,MAX(BR.[Name]) AS [BranchName]
	  ,MAX(R.ReceiptNo) AS [ReceiptNo]
	  ,MAX(CONVERT(VARCHAR,R.DateOut, 103)) AS [DateOut]
	  ,MAX(R.[TimeOut]) AS [TimeOut]
	  ,MAX(R.DiscountValue) AS [DiscountItem]
	  ,MAX(PL_CR.[Description]) AS [Currency]
	  ,MAX(R.GrandTotal) AS [GrandTotal]
	  ,MAX(CONVERT(VARCHAR,GETDATE(),103)) AS [DateFrom]
	  ,MAX(CONVERT(VARCHAR,GETDATE(),103))AS [DateTo]
	  ,(SELECT SUM(SR.GrandTotal_Sys) FROM receipt_cte SR WHERE SR.BranchID = R.BranchID) AS [GrandTotalBrand]
	  ,(SELECT SUM(DisItemSys) FROM receipt_detail_cte) AS [SDiscountItem]
	  ,(SELECT SUM(DisTotalSys) FROM receipt_cte)  AS [SDiscountTotal]
	  ,(SELECT SUM(TaxValueSys) FROM receipt_cte) AS [SVat]
	  ,(SELECT SUM(GrandTotal_Sys) FROM receipt_cte)AS [SGrandTotalSys]
	  ,(SELECT SUM(GrandTotal_LCC) FROM receipt_cte) AS [SGrandTotal]
	  ,MAX(R.Remark) AS [Remark]
	  ,(SELECT SUM(RDDT.DisitemSys) FROM receipt_detail_cte RDDT WHERE R.ReceiptID=RDDT.ReceiptID) AS [TotalDiscountItem]
	  ,MAX(R.DiscountValue* R.ExchangeRate) AS [DiscountTotal]
	  ,MAX(R.TaxValueSys) AS [Vat]
	  ,MAX(R.GrandTotal_Sys) AS [GrandTotalSys]
	  ,MAX(GrandTotal_LCC) AS [MGrandTotal]
	   FROM receipt_cte R 
	   INNER JOIN tbUserAccount UA ON R.UserOrderID = UA.ID
	   INNER JOIN tbEmployee EP ON UA.EmployeeID = EP.ID
	   INNER JOIN tbCurrency PL_CR ON R.PLCurrencyID = PL_CR.ID
	   INNER JOIN tbCurrency CL_CR ON R.LocalCurrencyID = CL_CR.ID
	   INNER JOIN tbCurrency SS_CR ON R.SysCurrencyID = SS_CR.ID
	   INNER JOIN tbSeries SR ON R.SeriesID = SR.ID
	   INNER JOIN tbDocumentType DT ON SR.DocuTypeID = DT.ID
	   INNER JOIN tbBranch BR ON R.BranchID = BR.ID
	   GROUP BY R.BranchID
			   ,R.ReceiptID
)
SELECT * FROM receipt_rpt_cte;

---------------------------


