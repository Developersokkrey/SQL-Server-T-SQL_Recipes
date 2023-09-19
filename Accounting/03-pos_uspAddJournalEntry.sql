
CREATE OR ALTER PROC [dbo].[pos_uspAddJournalEntry](@receiptId int)
AS 
BEGIN TRANSACTION TxJournalEntry
BEGIN TRY

	DECLARE @seriesDetailMapSet [SeriesDetailMap];
	DECLARE @jeSet TABLE(JEID INT);
	DECLARE @docTypeId int;
	SET @docTypeId = (SELECT TOP 1 DT.ID FROM tbDocumentType DT WHERE DT.Code = 'SP');

	INSERT INTO [dbo].[tbSeriesDetail]
					([SeriesID]
					,[Number]           
					,[RowId]
					,[ChangeLog])
	OUTPUT
		inserted.ID AS SeriesDID, 	
		inserted.SeriesID AS SeriesID,
		inserted.Number AS NextNo
		INTO @seriesDetailMapSet
	SELECT
		MAX(TSR.ID) AS [SeriesID],
		MAX(TSR.NextNo) AS [Number],
		MAX(NEWID()) AS [RowId],
		MAX(GETUTCDATE()) AS [ChangeLog]
	FROM (		
		SELECT TOP 1 SR.* FROM tbSeries SR 
		RIGHT JOIN tbDocumentType DT ON SR.DocuTypeID = DT.ID AND DT.Code = 'JE'
		WHERE SR.[Default] = 1 
	) TSR
	LEFT JOIN tbSeriesDetail SRD ON SRD.SeriesID = TSR.ID 
	GROUP BY TSR.ID

	INSERT INTO tbJournalEntry (
		[SeriesID]
    ,[Number]
    ,[DouTypeID]
    ,[Creator]
    ,[TransNo]
    ,[PostingDate]
    ,[DueDate]
    ,[DocumentDate]
    ,[Remarks]
    ,[TotalDebit]
    ,[TotalCredit]
    ,[SSCID]
    ,[LLCID]
    ,[LocalSetRate]
    ,[SeriesDID]
    ,[CompanyID]
    ,[BranchID]
    ,[TransType]
    ,[ChangeLog]
		,[RefSeriesDID]
	)
	OUTPUT inserted.ID AS JEID INTO @jeSet
	SELECT
		SSR.[SeriesID] AS [SeriesID]
		,SSR.[NextNo] AS [Number]
		,@docTypeId AS [DouTypeID]
		,R.UserOrderID AS [Creator]
		,R.ReceiptNo AS [TransNo]
		,R.PostingDate AS [PostingDate]
		,R.DateOut AS [DueDate]
		,R.DateOut AS [DocumentDate]
		,CONCAT(SR.[Name], '-', R.ReceiptNo) AS [Remarks]
		,0 AS [TotalDebit]
    ,0 AS [TotalCredit]
		,R.SysCurrencyID AS [SSCID]
		,R.LocalCurrencyID AS [LLCID]
		,R.[LocalSetRate]
		,SSR.[SeriesDID] AS [SeriesDID]		
		,R.[CompanyID]
		,R.[BranchID]
		,1 AS [TransType] --TransType.SP
		,GETUTCDATE() AS [ChangeLog]
		,R.SeriesDID
	FROM @seriesDetailMapSet SSR
	INNER JOIN tbSeries SR ON SR.ID = SSR.SeriesID
	LEFT JOIN tbReceipt R ON R.ReceiptID = @receiptId
	
	DECLARE @jeId int;
	SET @jeId = (SELECT TOP 1 JEID FROM @jeSet);
	EXEC pos_uspSetListJournalAccounts @receiptId, @jeId, @docTypeId

	--Increment [NextNo] of table [tbSeries] after added Journal.
	UPDATE SR SET SR.NextNo = SR.NextNo + 1 FROM @seriesDetailMapSet SSR
	INNER JOIN tbSeries SR ON SR.ID = SSR.SeriesID

	--Update [TotalDebit], [TotalCredit] of JournalEntry
	UPDATE JE
	SET JE.[TotalDebit] = TJE.[TotalDebit],
		JE.[TotalCredit] = TJE.[TotalCredit]
	FROM tbJournalEntry JE
	INNER JOIN(
	SELECT 
			MAX(JE.ID) AS JEID,
			SUM(AB.[Debit]) AS [TotalDebit],
			SUM(AB.[Credit]) AS [TotalCredit]
		FROM tbAccountBalance AB
		INNER JOIN tbJournalEntry JE ON AB.JEID = JE.ID
		GROUP BY JE.ID
	) TJE ON TJE.JEID = JE.ID AND JE.ID = @jeId

	COMMIT TRANSACTION TxJournalEntry
END TRY
BEGIN CATCH
	RAISERROR('Journal entry not set', 16, 1);
	ROLLBACK TRANSACTION TxJournalEntry
END CATCH
GO


