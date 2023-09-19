	--SELECT * FROM tbSaleAR
	--SELECT * FROM tbSaleARDetail

-------------------------------------------------
;WITH salear_cte AS (
	SELECT * FROM tbSaleAR
),
salear_detail_cte AS (
	SELECT 
		SRD.*
	   ,SRD.DisValue * SR.ExchangeRate AS [DisItemSys]
		FROM tbSaleARDetail SRD 
		INNER JOIN tbSaleAR SR ON SRD.SARID = SR.SARID
),
salear_rpt_cte AS (
	SELECT 
		MAX(SR.SeriesDID) AS [RceciptID]
	   ,MAX(SR.FreightAmount) AS [AmountGreight]
	   ,MAX(DT.Code) AS [DouTpe]
	   ,MAX(EP.Code) AS [EmpCode]
	   ,MAX(EP.[Name]) AS [EmpName]
	   ,MAX(SR.BranchID) AS [BranchID]
	   ,MAX(SR.InvoiceNo) AS [ReceiptNo]
	   ,MAX(CONVERT(VARCHAR,SR.PostingDate, 103)) AS [DateOut]
	   ,'' AS [TimeOut]
	   ,MAX(SR.DisValue) AS [DiscountItem]
	   ,MAX(PL_CR.[Description]) AS [Currency]
	   ,MAX(SR.TotalAmount) AS [GrndTotal]
	   ,MAX(CONVERT(VARCHAR,GETDATE(),103)) AS [DateFrom]
	   ,MAX(CONVERT(VARCHAR,GETDATE(),103))AS [DateTo]
	   ,(SELECT SUM(TotalAmountSys) FROM salear_cte SRS WHERE SR.BranchID = SRS.BranchID) AS [GandTotalBrand]
	   ,(SELECT SUM(DisValue) FROM salear_detail_cte) AS [SDiscountItem]
		FROM salear_cte SR
		INNER JOIN tbUserAccount UA ON SR.UserID = UA.ID
		INNER JOIN tbCompany CM ON SR.CompanyID = CM.ID
		INNER JOIN tbEmployee EP ON UA.EmployeeID = EP.ID
		INNER JOIN tbDocumentType DT ON SR.DocTypeID = DT.ID
		INNER JOIN tbCurrency PL_CR ON SR.SaleCurrencyID = PL_CR.ID
		INNER JOIN tbCurrency CL_CR ON SR.LocalCurID = CL_CR.ID
		INNER JOIN tbCurrency SS_CR ON CM.SystemCurrencyID = SS_CR.ID
		INNER JOIN tbBranch BR ON SR.BranchID = BR.ID
		GROUP BY SR.BranchID
				,SR.SARID
)
SELECT * FROM salear_rpt_cte;