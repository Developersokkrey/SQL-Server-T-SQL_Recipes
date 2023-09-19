


CREATE OR ALTER PROC [dbo].[pos_uspAddJournalAccountBalance](
	@journalEntryId int, 
	@docTypeId int, 
	@journalMapSet [JournalMap] READONLY
) AS BEGIN

	UPDATE GL 
	SET GL.Balance = GL.Balance + ABS(JM.Debit) - ABS(JM.Credit)
	FROM tbGLAccount GL
	INNER JOIN @journalMapSet JM ON GL.ID = JM.[GLAcctID]

	INSERT INTO tbJournalEntryDetail (
		[JEID]
    ,[Type]
    ,[ItemID]
    ,[Debit]
    ,[Credit]
    ,[BPAcctID]
	)
	SELECT
		MAX(@journalEntryId) AS JEID,
		CASE WHEN MAX(TRV.BPAcctID) <= 0 THEN 1 ELSE 2 END AS [Type],
		MAX(TRV.[GLAcctID]) AS ItemID,
		MAX(TRV.Debit) AS Debit,
		MAX(TRV.Credit) AS Credit,
		MAX(TRV.[BPAcctID])
	FROM tbJournalEntryDetail JED
	RIGHT JOIN(
		SELECT * FROM @journalMapSet
	) TRV ON TRV.[GLAcctID] = JED.ItemID
	GROUP BY TRV.[GLAcctID];

	INSERT INTO tbAccountBalance(
		[PostingDate]
    ,[Origin]
    ,[OriginNo]
    ,[OffsetAccount]
    ,[Details]
    ,[CumulativeBalance]
    ,[Debit]
    ,[Credit]
    ,[LocalSetRate]
    ,[GLAID]
    ,[BPAcctID]
    ,[Creator]
    ,[JEID]
    ,[Effective]
    ,[Remarks]
		,[Type]
	)
	SELECT DISTINCT
		TRV.PostingDate,
		TRV.DocTypeID AS [Origin],
		TRV.ReceiptNo AS [OriginNo],
		TRV.OffsetAccountCode [OffsetAccount],
		TRV.Details,
		ISNULL(TRV.Balance, 0) AS [Balance],
		TRV.Debit AS Debit,
		TRV.Credit AS Credit,
		TRV.LocalSetRate,
		TRV.[GLAcctID] AS GLAID,
		TRV.BPAcctID AS [BPAcctID],
		TRV.UserOrderID AS [Creator],
		ISNULL(@journalEntryId, 0) AS JEID,
		CASE WHEN TRV.Debit > 0 THEN 1 ELSE 2 END AS [Effective],
		TRV.Remark,
		CASE WHEN TRV.[BPAcctID] <= 0 THEN 1 ELSE 0 END AS [Type]
	FROM tbAccountBalance AB
	RIGHT JOIN (
		SELECT 
			R.*,
			TR.[BPAcctID],
			DT.ID AS DocTypeID,
			TR.[GLAcctID],
			TR.Debit,
			TR.Credit,
			GL.Code AS OffsetAccountCode,			
			CONCAT(DT.[Name], '-', GL.Code) AS Details,
			ISNULL(GL.Balance, 0) AS [Balance]
		FROM @journalMapSet TR
		INNER JOIN tbReceipt R ON R.ReceiptID = TR.ReceiptID
		INNER JOIN tbDocumentType DT ON DT.ID = @docTypeId
		INNER JOIN tbGLAccount GL ON GL.ID = TR.[GLAcctID]
	) TRV ON AB.GLAID = TRV.[GLAcctID] AND AB.ID IS NULL
END

GO


