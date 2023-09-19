
CREATE OR ALTER FUNCTION [dbo].[pos_ufnGetItemAccounting](@receiptId INT)
RETURNS TABLE AS RETURN
	SELECT DISTINCT
		IAC.*
	FROM tbItemMasterData IM 
	INNER JOIN(
		SELECT 
			MAX(RD.ItemID) AS ItemID,
			SUM(RD.Total_Sys) AS TotalSys
		FROM tbReceiptDetail RD
		INNER JOIN tbReceipt R ON R.ReceiptID = RD.ReceiptID
		WHERE R.ReceiptID = @receiptId
		GROUP BY RD.ItemID
	) TRD ON TRD.ItemID = IM.ID AND TRD.ItemID = IM.ID AND IM.[Delete] = 0
	INNER JOIN ItemAccounting IAC 
	ON (IAC.ItemGroupID = IM.ItemGroup1ID AND IM.SetGlAccount = 1)
	OR (IAC.ItemID = IM.ID AND IM.SetGlAccount = 2)
GO


