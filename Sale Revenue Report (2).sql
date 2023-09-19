

;WITH dt_cte AS (
	SELECT 
		U.UserID
	FROM tbUserAccount U
	INNER JOIN tbEmployee E ON U.EmployeeID = E.ID
	INNER JOIN tbDocumentType DT ON UPPER(DT.Code) = 'SP'
),
sale_receipt_cte AS (
	SELECT 
		MAX(R.SeriesDID) AS SeriesDetailID
		,MAX(R.TotalBeforeDiscount) AS [TotalBeforeDiscount] 
		,MAX(R.TotalAfterDiscount) AS [TotalAfterDiscount] 
		,MAX(R.TotalAfterTax) AS [TotalAfterTax]
		,MAX(R.[DiscountValue]) AS [DiscountSum]
		,MAX(R.TaxValue) AS [TaxValueSum]
	FROM tbReceiptDetail RD 
	INNER JOIN tbReceipt R ON RD.ReceiptID = R.ReceiptID
	GROUP BY R.ReceiptID
),
sale_receipt_memo_cte AS (
	SELECT 
		MAX(RM.SeriesDID) AS SeriesDetailID
		,MAX(RM.SubTotal) AS [TotalBeforeDiscount]
		,SUM(RMD.TotalNet * (1 - RMD.DisRate / 100)) AS [TotalAfterDiscount] 
		,CASE WHEN RM.TaxOption = 1 
			THEN SUM(RMD.TotalNet - RMD.DisValue + RMD.TaxValue)
			ELSE SUM(RMD.TotalNet - RMD.DisValue) END
			AS [TotalAfterTax]
		,SUM(RMD.DisValue) AS [DiscountSum]
		,SUM(RMD.TaxValue) AS [TaxValueSum]
	FROM ReceiptDetailMemoKvms RMD 
	INNER JOIN ReceiptMemo RM ON RMD.ReceiptMemoID = RM.ID
	GROUP BY RMD.ReceiptMemoID
),
sale_ar_cte AS (
	SELECT 
		MAX(AR.SeriesDID) AS SeriesDetailID,
		MAX(AR.SubTotalBefDis) AS [TotalBeforeDiscount] 
		,MAX(AR.SubTotalAfterDis) AS [TotalAfterDiscount] 
		,MAX(AR.TotalAmount) AS [TotalAfterTax]
		,MAX(AR.DisValue) AS [DiscountSum]
		,SUM(ARD.TaxValue) AS [TaxValueSum]
	FROM tbSaleARDetail ARD 
	INNER JOIN tbSaleAR AR ON ARD.SARID = AR.SARID
	GROUP BY ARD.SARID
),
sale_ar_memo_cte AS (
	SELECT 
		MAX(SCM.SeriesDID) AS SeriesDetailID,
		MAX(SCM.SubTotalBefDis) AS [TotalBeforeDiscount] 
		,MAX(SCM.SubTotalAfterDis) AS [TotalAfterDiscount] 
		,MAX(SCM.TotalAmount) AS [TotalAfterTax]
		,MAX(SCM.DisValue) AS [DiscountSum]
		,SUM(SCMD.TaxValue) AS [TaxValueSum]
	FROM tbSaleCreditMemoDetail SCMD 
	INNER JOIN SaleCreditMemos SCM ON SCMD.SCMOID = SCM.SCMOID
	GROUP BY SCMD.SCMOID
)

SELECT 
	[LineID]
	,[GrandTotalBrand]
	,[EmpCode]
	,[EmpName]
	,[BranchName]
	,[BranchID]
	,[ReceiptNo]
	,[ReceiptNmber]
	,[Expires]
	,[NewContractStartDate]
	,[NewContractEndDate]
	,[NextOpenRenewalDate]
	,[Renewalstartdate]
	,[Renewalenddate]
	,[TerminateDate]
	,[ContractName]
	,[SetupContractName]
	,[Activities]
	,[EstimateSupportCost]
	,[Remark]
	,[Attachement]
	,[DouType]
	,[DateOut]
	,[DisRemark]
	,[Currency]
	,[Reasons]
	,[GrandTotal]
	,[ReceiptID]
	,[TimeOut]
	,[DiscountItem]
	,[AmmountFreightss]
	,[Distotalin]
	,[DisItem]
	,[DateFrom]
	,[DateTo]
	,[SCount]
	,[SDiscountItem]
	,[SDiscountTotal]
	,[SVat]
	,[SGrandTotalSys]
	,[SGrandTotal]
	,[TotalDiscountItem]
	,[DiscountTotal]
	,[Vat]
	,[GrandTotalSys]
	,[UnitPrice]
	,[Total]
	,[MGrandTotal]
	,[RefNo]
	,[AmountFreight]
	,[ItemCode]
	,[ItemNameKhmer]
	,[ItemNameEng]
	,[Qty]
	,[Uom]
	,[ShipBy]
	,[ItemID]
	,[TotalVat]
	,[TotalGrandTotal]
	,[TotalGrandTotalSys]
	,[Process]
	,[InvoiceNo]
	,[LoanPartner]
	,[TotalCost]
	,[Margin]
	,[ExchangeRate]
	,[SubTotal]
	,[VatInvoice]
	,[VatItem]

FROM tbReceiptDetail RD

