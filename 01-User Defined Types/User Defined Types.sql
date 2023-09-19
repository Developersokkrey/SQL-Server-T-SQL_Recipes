
/****** Object:  UserDefinedTableType [dbo].[JournalMap]    Script Date: 8/12/2023 1:02:35 PM ******/
CREATE TYPE [dbo].[JournalMap] AS TABLE(
	[ReceiptID] [int] NOT NULL,
	[BPAcctID] [int] NOT NULL,
	[GLAcctID] [int] NOT NULL,
	[Debit] [decimal](24, 6) NOT NULL,
	[Credit] [decimal](24, 6) NOT NULL
)
GO

/****** Object:  UserDefinedTableType [dbo].[SeriesDetailMap]    Script Date: 8/12/2023 1:02:42 PM ******/
CREATE TYPE [dbo].[SeriesDetailMap] AS TABLE(
	[SeriesDID] [int] NULL,
	[SeriesID] [int] NULL,
	[NextNo] [nvarchar](max) NULL
)
GO

/****** Object:  UserDefinedTableType [dbo].[StockOutMap]    Script Date: 8/12/2023 1:02:59 PM ******/
CREATE TYPE [dbo].[StockOutMap] AS TABLE(
	[ItemID] [int] NOT NULL,
	[WarehouseID] [int] NOT NULL,
	[UomID] [int] NOT NULL,
	[UserID] [int] NOT NULL,
	[TransID] [int] NOT NULL,
	[ContractID] [int] NOT NULL,
	[OutStockFromID] [int] NOT NULL,
	[BPID] [int] NOT NULL,
	[InStock] [decimal](18, 2) NOT NULL,
	[ProcessItem] [int] NOT NULL
)
GO




