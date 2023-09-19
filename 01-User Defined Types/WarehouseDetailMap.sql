

/****** Object:  UserDefinedTableType [dbo].[WarehouseDetailMap]    Script Date: 8/17/2023 2:27:16 PM ******/
IF EXISTS (SELECT *
				FROM   sys.objects
				WHERE  object_id = OBJECT_ID(N'[dbo].[pos_uspIssueStock]')
        AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION [dbo].[pos_uspIssueStock]

IF EXISTS (SELECT *
          FROM   sys.objects
          WHERE  object_id = OBJECT_ID(N'[dbo].[pos_uspAddStockout]'))
DROP PROC [dbo].[pos_uspAddStockout]

IF TYPE_ID(N'[dbo].[WarehouseDetailMap]') IS NOT NULL
DROP TYPE [dbo].[WarehouseDetailMap]
CREATE TYPE [dbo].[WarehouseDetailMap] AS TABLE(
	[ID] [int] NOT NULL,
	[ReceiptID] [int] NOT NULL,
	[WarehouseID] [int] NOT NULL,
	[LineID] [nvarchar](max) NOT NULL,
	[ItemID] [int] NOT NULL,
	[InventoryUomID] [int] NOT NULL,
	[UomID] [int] NOT NULL,
	[GroupUomID] [int] NOT NULL,
	[Layer] [int] NOT NULL,
	[Process] [nvarchar](50) NOT NULL,
	[Cost] [float] NOT NULL,
	[AvgCost] [float] NOT NULL,
	[StdCost] [float] NOT NULL,
	[BaseStock] [float] NOT NULL,
	[IssueQty] [float] NOT NULL,
	[TotalBaseStock] [float] NOT NULL,
	[RemainQty] [float] NOT NULL,
	[OutStock] [float] NOT NULL,
	[InStock] [float] NOT NULL,
	[TotalOutStock] [float] NOT NULL,
	[TotalInStock] [float] NOT NULL,
	[TransValue] [float] NOT NULL,
	[AvgTransValue] [float] NOT NULL,
	[StdTransValue] [float] NOT NULL,
	[TotalTransValue] [float] NOT NULL,
	[AvgTotalTransValue] [float] NOT NULL,
	[StdTotalTransValue] [float] NOT NULL
)
GO


