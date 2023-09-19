
CREATE OR ALTER    FUNCTION [dbo].[pos_ufnGetItemBalance](@receiptId int)
RETURNS TABLE AS RETURN (
	WITH RD_CTE AS (
		SELECT 
			MAX(ISNULL(TG.GLID, 0)) AS [GLAcctID],
			MAX(R.ReceiptID) AS ReceiptID, 
			MAX(R.CustomerID) AS CustomerID, 
			MAX(RD.ItemID) AS ItemID,
			MAX(IM.ItemGroup1ID) AS ItemGroupID,
			MAX(ISNULL(TG.ID, 0)) AS [TaxGroupID],
			MAX(ISNULL(TG1.ID,0)) AS [TaxPlID],
			MAX(ISNULL(TG2.ID,0)) AS [TaxSPID],
			MAX(R.TaxOption) AS TaxOption,
			(MAX(R.DiscountRate) + MAX(R.PromoCodeDiscRate) + MAX(R.BuyXAmGetXDisRate) + MAX(R.CardMemberDiscountRate)) AS InvDiscountRate,
			MAX(RD.TaxRate) AS ItemTaxRate,
			MAX(RD.PublicLightingTaxRate) AS ItemTaxPLRate,
			MAX(RD.SpecailTaxRate) AS ItemTaxSPRate,
			SUM(RD.TaxValue * R.ExchangeRate) AS ItemTaxValue,	
			SUM(RD.TotalBeforeDiscount * R.ExchangeRate) AS TotalBeforeDiscount,
			SUM(RD.TotalAfterDiscountLine * R.ExchangeRate) AS TotalAfterDiscountLine,
			SUM(RD.TotalAfterDiscountSum * R.ExchangeRate) AS TotalAfterDiscountSum,
			SUM(RD.Revenue * R.ExchangeRate) AS RevenueAmount,
			SUM(RD.TotalAfterTax * R.ExchangeRate) AS TotalAfterTax,
			SUM(RD.PublicLightingTaxValue*R.ExchangeRate) AS ItemPLTaxValue,
			SUM(RD.SpecailTaxValue*R.ExchangeRate) AS ItemSPTaxValue
		FROM tbReceipt R
		INNER JOIN tbReceiptDetail RD ON R.ReceiptID = RD.ReceiptID
		INNER JOIN tbItemMasterData IM ON RD.ItemID = IM.ID
		LEFT JOIN TaxGroup TG ON TG.ID IN (R.TaxGroupID, RD.TaxGroupID) AND TG.[Active] = 1
		LEFT JOIN TaxGroup TG1 ON TG1.ID IN (RD.PublicLightingTaxGroupID) AND TG1.[Active] = 1
		LEFT JOIN TaxGroup TG2 ON TG2.ID IN (RD.SpecailTaxGroupID) AND TG2.[Active] = 1
		WHERE R.ReceiptID = @receiptId
		GROUP BY RD.ItemID
	)
	SELECT * FROM RD_CTE
);
