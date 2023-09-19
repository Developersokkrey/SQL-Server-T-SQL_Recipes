
---------------------------- Insert tbPriceList -----------------------------
IF NOT EXISTS( SELECT Code FROM tbPriceList Where Code!='' )
BEGIN
	UPDATE tbPriceList SET Code = [Name]
END

---------------------------- Insert tbCurrency -----------------------------
IF NOT EXISTS( SELECT Code FROM tbCurrency Where Code!='' )
BEGIN
	UPDATE tbCurrency SET Code = [Description]
END

---------------------------- Insert DashboardSettings -----------------------------

IF NOT EXISTS( SELECT Code FROM DashboardSettings Where Code='R4' )
BEGIN
	INSERT INTO DashboardSettings
		VALUES ('R4', 1, 1)
END

---------------------------- Insert CustomerSort (Old Script) -----------------------------

GO
IF NOT EXISTS( SELECT Code FROM CustomerSort Where Code='Code' )
BEGIN
	INSERT INTO CustomerSort
		(Code, Name, [Enable])
		VALUES ('Code', 'Code', 1)
END
IF NOT EXISTS( SELECT Code FROM CustomerSort Where Code='Name' )
BEGIN
	INSERT INTO CustomerSort
		(Code, Name, [Enable]) 
VALUES ('Name', 'Name', 0) 
END
IF NOT EXISTS( SELECT Code FROM CustomerSort Where Code='Group1' )
BEGIN
	INSERT INTO CustomerSort
		(Code, Name, [Enable])
	VALUES ('Group1',' Group1', 0) 
END

---------------------------- Insert ItemSorts (Old Script) -----------------------------

GO
IF NOT EXISTS( SELECT Code FROM ItemSorts Where Code='Code' )
BEGIN
	INSERT INTO ItemSorts
		(Code, Name, [Enable])
		VALUES ('Code', 'Code', 1)
END
IF NOT EXISTS( SELECT Code FROM ItemSorts Where Code='Barcode' )
BEGIN
	INSERT INTO ItemSorts
		(Code, Name, [Enable])
		VALUES ('Barcode', 'Barcode', 0)
END
IF NOT EXISTS( SELECT Code FROM ItemSorts Where Code='ItemName' )
BEGIN
	INSERT INTO ItemSorts
		(Code, Name, [Enable]) 
VALUES ('ItemName', 'ItemName', 0) 
END
IF NOT EXISTS( SELECT Code FROM ItemSorts Where Code='ItemGroup' )
BEGIN
	INSERT INTO ItemSorts
		(Code, Name, [Enable])
	VALUES ('ItemGroup',' ItemGroup', 0) 
END

---------------------------- pos_uspGetIssuedStockReceiptMemos (Old Script) -----------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[pos_uspGetIssuedStockReceiptMemos]
AS BEGIN
	SELECT _rm.* FROM ReceiptMemo _rm
	LEFT JOIN tbInventoryAudit _ia ON _rm.SeriesDID = _ia.SeriesDetailID
	WHERE _rm.ID IN (
	SELECT MAX(rm.ID) FROM ReceiptMemo rm
	JOIN tbReceipt r ON rm.BasedOn = r.ReceiptID
	JOIN tbInventoryAudit ia ON r.SeriesDID = ia.SeriesDetailID
	GROUP BY rm.ID) AND _ia.ID IS NULL
END

------------------------------- pos_uspGetNoneIssuedValidStockReceipts (Old Script) -----------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[pos_uspGetNoneIssuedValidStockReceipts]
AS
BEGIN
	SELECT DISTINCT _r.* FROM tbReceipt _r INNER JOIN tbReceiptDetail _rd ON _r.ReceiptID = _rd.ReceiptID  
	WHERE _r.ReceiptID 
	NOT IN (
		SELECT DISTINCT r.ReceiptID FROM tbReceipt r 
		CROSS APPLY pos_ufnGetReceiptItemsWithBoM(r.ReceiptID) rd
		INNER JOIN tbItemMasterData im on rd.ItemID = im.ID AND UPPER(im.Process) != 'STANDARD'
		INNER JOIN tbWarehouseSummary ws on ws.ItemID = rd.ItemID and ws.WarehouseID = r.WarehouseID
			AND (ws.InStock <= 0 OR (ws.InStock - ws.[Committed]) < rd.Qty)	
		GROUP BY r.ReceiptID
	) AND _r.SeriesDID NOT IN (SELECT i.SeriesDetailID FROM tbInventoryAudit i)
END;

----------------------------------  pos_uspGetSaleItems (Old Script) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE pos_uspGetSaleItems(@userId INT, @priceListId INT, @warehouseId INT, @process VARCHAR(50))
AS 
SELECT 
	TS.*, 
	ISNULL(TPS.PromotionID, 0) AS PromotionID, 
	ISNULL(TPS.Discount, 0) AS DiscountRate 
FROM (
	SELECT
		MAX(T4.ID) AS ID,
		MAX(T0.ID) AS ItemID,
		MAX(T0.Code) AS Code,
		REPLACE(MAX(T4.Barcode),' ','') AS Barcode,
		MAX(T0.Barcode) AS ItemBarcode,
		MAX(T0.KhmerName) AS KhmerName,
		MAX(T0.EnglishName) AS EnglishName,
		MAX(T4.UnitPrice) AS UnitPrice,
		MAX(T0.[Description]) AS [Description],
		MAX(T4.TypeDis) AS TypeDis,
		MAX(T0.GroupUomID) AS GroupUomID,
		MAX(T0.[Type]) AS ItemType,
		MAX(T0.ItemGroup1ID) AS Group1,
		MAX(ISNULL(T0.ItemGroup2ID, 0)) AS Group2,
		MAX(ISNULL(T0.ItemGroup3ID, 0)) AS Group3,
		MAX(ISNULL(T0.SaleUomID, 0)) AS SaleUomID,
	  	MAX(T5.ID) AS UomID,
		MAX(T5.[Name]) AS UoM,
		MAX(T6.ID) AS CurrencyID,
		MAX(T6.Symbol) AS Symbol,
		MAX(T4.PriceListID) AS PriceListID,
		MAX(T4.Cost) AS Cost,
		CONVERT(bit, MAX(1 * T0.Scale)) AS IsScale,
		MAX(T0.TaxGroupSaleID) AS TaxGroupSaleID,
		MAX(T8.[Name]) AS PrintTo,
		MAX(T9.[Name]) AS PrintTo2,
		MAX((ISNULL(T10.InStock, 0) / T7.Factor)) AS InStock,
		MAX(T0.Process) AS Process,
		MAX(T0.[Image]) AS [Image]
	FROM tbItemMasterData T0
	JOIN ItemGroup1 T2 ON T0.ItemGroup1ID = T2.ItemG1ID
	JOIN Multigroups T3 ON T2.ItemG1ID = T3.Group1ID AND T3.Active = 1 AND T3.UserID = @userId
	JOIN tbPriceListDetail T4 ON T0.ID = T4.ItemID
	JOIN tbUnitofMeasure T5 ON T5.ID = T4.UomID
	JOIN tbCurrency T6 ON T6.ID = T4.CurrencyID
	JOIN tbGroupDefindUoM T7 ON T7.AltUOM = T5.ID AND T7.GroupUoMID = T0.GroupUomID
	LEFT JOIN tbPrinterName T8 ON T8.ID = T0.PrintToID
	LEFT JOIN tbPrinterName T9 ON T9.ID = T0.PrintTo2ID
	LEFT JOIN tbWarehouseSummary T10 ON T10.ItemID = T4.ItemID AND T10.WarehouseID = @warehouseId
	WHERE T4.PriceListID = @priceListId AND T4.InActive=0 AND T0.[Delete]=0
	AND (UPPER(T0.Process) = UPPER(@process) OR @process IS NULL OR LEN(@process) <= 0)
	GROUP BY T4.ID
) AS TS
LEFT JOIN (
	SELECT MAX(TPD.ItemID) AS ItemID, MAX(TPD.Discount) AS Discount, MAX(TPD.PromotionID) AS PromotionID FROM 
		tbPromotionDetail TPD
		LEFT JOIN tbPromotion TP ON TPD.PromotionID = TP.ID AND TP.PriceListID = @priceListId
		WHERE GETDATE() BETWEEN TP.StartDate AND TP.StopDate AND TP.Active = 1
		GROUP BY TPD.ItemID
) AS TPS ON TS.ItemID = TPS.ItemID

----------------------------------  GeneralServiceSetups (Old Script) --------------------------------------------

GO
IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='DueDate' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active)
		VALUES ('DueDate','DueDate',1)
END
IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='Stock' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active)
		VALUES ('Stock','Stock',1)
END
IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='ExItem' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active) 
VALUES ('ExItem','ExItem',1);
END
IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='Activity' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active) 
VALUES ('Activity','Activity',1);
END
IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='SaleQuote' )
BEGIN
	INSERT INTO GeneralServiceSetups
VALUES ('SaleQuote','SaleQuote',1);
END
IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='SaleOrder' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active) 
VALUES ('SaleOrder','SaleOrder',1);
END
IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='PurchaseOrder' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active) 
VALUES ('PurchaseOrder','PurchaseOrder',1);
END
IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='CreditCustomer' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active) 
VALUES ('CreditCustomer','CreditCustomer',1);
END
IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='StockAvalible' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active) 
VALUES ('StockAvalible','StockAvalible',1);
END

IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='PurchaseToday' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active) 
VALUES ('PurchaseToday','PurchaseToday',1);
END

IF NOT EXISTS( SELECT Code FROM GeneralServiceSetups Where Code='SaleToday' )
BEGIN
	INSERT INTO GeneralServiceSetups
		(Code,Name,Active) 
VALUES ('SaleToday','SaleToday',1);
END

----------------------------------  ColorSetting (Old Script) --------------------------------------------

GO
IF NOT EXISTS(select c.ID from ColorSetting c right join SkinUser s on c.ID = s.SkinID)
insert into SkinUser(s.SkinID,s.UserID, s.Unable) 
select  c.ID, COALESCE(s.Unable, 0), COALESCE(s.UserID, 0) from SkinUser s right join  ColorSetting c on c.ID = s.SkinID 


--///////////////update SkinUser(secend)//////////////////////
IF NOT EXISTS(select * from SkinUser s Where s.UserID != 0)
insert into SkinUser(s.SkinID,s.UserID, s.Unable) 
select  COALESCE(s.SkinID,0),  COALESCE(a.ID,0),COALESCE(s.Unable, 0) from SkinUser s cross join  tbUserAccount a

----------------------------------  sp_GetCustomer (Old Script) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[sp_GetCustomer] 
AS
BEGIN
	DECLARE @SortBy NVARCHAR(50) 
	SET @SortBy = (SELECT TOP 1 Code FROM CustomerSort WHERE [Enable]=1)

		SELECT
			BP.ID AS [No],
			BP.Code,
			BP.[Name],
			BP.[Type],
			G.[Name] AS Group1,
			BP.Phone,
			PL.[Name] AS PriceList
			FROM tbBusinessPartner BP
				JOIN tbPriceList PL ON BP.PriceListID=PL.ID
				LEFT JOIN tbGroup1 G ON BP.Group1ID=PL.ID
			WHERE BP.[Delete]=0 AND BP.[Type]='Customer'
			ORDER BY 
				(CASE WHEN @SortBy = 'Code' THEN BP.Code
					WHEN @SortBy = 'Name' THEN BP.[Name] 
					WHEN @SortBy = 'Group1' THEN G.[Name] 
					ELSE @SortBy 
				END);	
END

----------------------------------  sp_GetItemDiscount (Old Script) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[sp_GetItemDiscount](
@PriceListID int=0,
@Group1 int=0,
@Group2 int=0,
@Group3 int=0,
@PromotionId int=0,
@UomID int=0
)
AS
BEGIN
	IF @PriceListID!=0 and @Group1=0 and @Group2=0 and @Group3=0
		Begin
			SELECT DISTINCT
				    pld.ID,
				  item.ID as ItemID,
				  item.Code,
				  item.KhmerName,
				  item.EnglishName,
				  uom.Name as Uom,
				  pld.UnitPrice as Price,
				  cur.[Description] as Currency,
				  convert(float, ISNULL(prod.Discount,0)) as Discount,
				  pld.TypeDis
			FROM tbPriceListDetail pld 
								   inner join tbItemMasterData item on pld.ItemID=item.ID
								   inner join tbCurrency cur on pld.CurrencyID=cur.ID
								   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
								   left join tbPromotionDetail prod on prod.PromotionID = @PromotionId 
								   where item.[Delete]=0 and pld.PriceListID=@PriceListID 
								   order by item.Code
		End
	ELSE IF @PriceListID!=0 and @Group1!=0 and @Group2=0 and @Group3=0
		Begin 
			SELECT DISTINCT
				    pld.ID,
				  item.ID as ItemID,
				  item.Code,
				  item.KhmerName,
				  item.EnglishName,
				  uom.Name as Uom,
				  pld.UnitPrice as Price,
				  cur.[Description] as Currency,
				  convert(float,ISNULL(prod.Discount,0)) as Discount,
				  pld.TypeDis
			FROM tbPriceListDetail pld 
								   inner join tbItemMasterData item on pld.ItemID=item.ID
								   inner join tbCurrency cur on pld.CurrencyID=cur.ID
								   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
								   left join tbPromotionDetail prod on prod.PromotionID = @PromotionId 
								   where item.[Delete]=0 and pld.PriceListID=@PriceListID and item.ItemGroup1ID=@Group1 
								   order by item.Code
		End
END

----------------------------------  sp_GetItemMasterData (Old Script) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[sp_GetItemMasterData]
@inActive BIT
AS
BEGIN

	DECLARE @SortBy NVARCHAR(50) 
	SET @SortBy = (SELECT TOP 1 Code FROM ItemSorts WHERE [Enable]=1)
	SELECT * FROM (
	SELECT
		MAX(item.ID) AS ID,
		MAX(item.Code) AS Code ,
		MAX(item.KhmerName) AS KhmerName,
		MAX(item.EnglishName) AS EnglishName,
		MAX(unitprice.UnitPrice) AS UnitPrice,
		MAX(item.Cost * uom.Factor) AS Cost,
		MAX(item.PriceListID) AS PriceListID,
		MAX(item.SaleUomID) AS SaleUomID,
		MAX(ISNULL(WHS.InStock, 0)) AS Stock,
		MAX(item.[Type]) AS [Type],
		MAX(item.ItemGroup1ID) AS ItemGroup1ID ,
		MAX(item.ItemGroup2ID) AS ItemGroup2ID,
		MAX(item.ItemGroup3ID) AS ItemGroup3ID ,
		MAX(item1.ItemG1ID) AS ItemGroupID,
		MAX(item1.[Name]) AS ItemGroupName,
		MAX(item.Barcode) AS Barcode ,
		MAX(item.PrintToID) AS PrintToID, 
		MAX(item.[Image]) AS [Image], 
		MAX(item.[Description]) AS [Description] ,  
		MAX(item.Process) AS Process,
		MAX(_uom.ID) AS UomID,
		MAX(_uom.[Name]) AS UomName
	FROM tbItemMasterData item
		join tbPriceList pl ON item.PriceListID=pl.ID
		join tbUnitofMeasure _uom ON item.SaleUomID=_uom.ID
		join ItemGroup1 item1 ON item.ItemGroup1ID=item1.ItemG1ID
		left join tbGroupDefindUoM uom ON item.GroupUomID=uom.GroupUoMID and item.SaleUomID=uom.UoMID
		left join tbWarehouseSummary WHS ON item.ID = WHS.ItemID
		left join tbPriceListDetail unitprice ON item.ID=unitprice.ItemID
	WHERE  item.[Delete]=@inActive and pl.[Delete]=0 and item1.[Delete]=0 
	GROUP BY
		item.ID 
	) AS T0
	ORDER BY 
		(CASE WHEN @SortBy = 'Code' THEN T0.Code
			WHEN @SortBy = 'Barcode' THEN T0.Barcode 
			WHEN @SortBy = 'ItemName' THEN T0.KhmerName 
			WHEN @SortBy = 'ItemGroup' THEN T0.ItemGroupName 
			ELSE @SortBy 
		END);
END

----------------------------------  sp_GetItemMasterToCopy (Old Script) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[sp_GetItemMasterToCopy]
@PriceListBaseID int=0,
@PriceListID int=0,
@Group1 int =0,
@Group2 int =0,
@Group3 int=0

AS
BEGIN
  
   IF @PriceListID!=0 and @Group1=0
		Begin
		select 
		       item.ID as ItemID,
			   max(item.Code) as Code,
			   max(item.KhmerName) as KhmerName,
			   max(item.EnglishName) as EnglishName,
			   max(uom.Name) as UoM,
			   max(item.Barcode) as Barcode,
			   max(item.Process) as Process
			  from tbItemMasterData item inner join tbPriceListDetail pld on item.ID=pld.ItemID
			                             inner join tbUnitofMeasure uom on item.InventoryUoMID=uom.ID
							             WHERE pld.PriceListID=@PriceListID and pld.ItemID not in (select ItemID from tbPriceListDetail where PriceListID=@PriceListBaseID)
										 group by item.ID
										 order by item.ID
		End
	 ELSE IF @PriceListID!=0 and @Group1!=0 
		Begin
			 select item.ID as ItemID,
			   max(item.Code) as Code,
			   max(item.KhmerName) as KhmerName,
			   max(item.EnglishName) as EnglishName,
			   max(uom.Name) as UoM,
			   max(item.Barcode) as Barcode,
			   max(item.Process) as Process
			  from tbItemMasterData item inner join tbPriceListDetail pld on item.ID=pld.ItemID
			                             inner join tbUnitofMeasure uom on item.InventoryUoMID=uom.ID
							             WHERE pld.PriceListID=@PriceListID and item.ItemGroup1ID=@Group1 and pld.ItemID not in (select ItemID from tbPriceListDetail where PriceListID=@PriceListBaseID)
										 group by item.ID
										 order by item.ID
		End
		
		
END 

----------------------------------  sp_GetItemSetPrice (Old Script) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[sp_GetItemSetPrice](
@PriceListID int=0,
@Group1 int=0,
@Group2 int=0,
@Group3 int=0,
@Process nvarchar(max)='Add')
AS
BEGIN
    Declare @SysCurrency nvarchar(max)
	select @SysCurrency=cur.[Description] from tbCompany cop inner join tbPriceList pl on cop.PriceListID=pl.ID
	                                                       inner join tbCurrency cur on cur.ID=pl.CurrencyID 
	IF(@Process='Add')
		Begin
			IF @PriceListID!=0 and @Group1=0 
				Begin
					SELECT 
						  pld.ID,
						  item.Code,
						  item.KhmerName,
						  item.EnglishName,
						  uom.Name as Uom,
						  pld.Cost as Cost,
						  convert(float,0) as Makup,
						  pld.UnitPrice as Price,
						  cur.[Description] as Currency,
						  convert(float,pld.Discount) as Discount,
						  pld.TypeDis,
						  item.Process,
						  @SysCurrency as SysCurrency,
						  item.Barcode as Barcode
					FROM tbPriceListDetail pld 
										   inner join tbItemMasterData item on pld.ItemID=item.ID
										   inner join tbCurrency cur on pld.CurrencyID=cur.ID
										   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
										   where item.[Delete]=0 and pld.PriceListID=@PriceListID and pld.UnitPrice=0
										   order by pld.ItemID
				End
			ELSE IF @PriceListID!=0 and @Group1!=0 
				Begin 
					SELECT 
						 pld.ID,
						  item.Code,
						  item.KhmerName,
						  item.EnglishName,
						  uom.Name as Uom,
						  pld.Cost as Cost,
						  convert(float,0) as Makup,
						  pld.UnitPrice as Price,
						  cur.[Description] as Currency,
						  convert(float,pld.Discount) as Discount,
						  pld.TypeDis,
						  item.Process,
						  @SysCurrency as SysCurrency,
						   item.Barcode as Barcode
					FROM tbPriceListDetail pld 
										   inner join tbItemMasterData item on pld.ItemID=item.ID
										   inner join tbCurrency cur on pld.CurrencyID=cur.ID
										   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
										   where item.[Delete]=0 and pld.PriceListID=@PriceListID and item.ItemGroup1ID=@Group1 and pld.UnitPrice=0
										   order by pld.ItemID
				End
		
		
		End
	Else
		Begin
			IF @PriceListID!=0 and @Group1=0
				Begin
					SELECT 
						  pld.ID,
						  item.Code,
						  item.KhmerName,
						  item.EnglishName,
						  uom.Name as Uom,
						  pld.Cost as Cost,
						  convert(float,0) as Makup,
						  pld.UnitPrice as Price,
						  cur.[Description] as Currency,
						  convert(float,pld.Discount) as Discount,
						  pld.TypeDis,
						  item.Process,
						  @SysCurrency as SysCurrency,
						  item.Barcode as Barcode
					FROM tbPriceListDetail pld 
										   inner join tbItemMasterData item on pld.ItemID=item.ID
										   inner join tbCurrency cur on pld.CurrencyID=cur.ID
										   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
										   where item.[Delete]=0 and pld.PriceListID=@PriceListID and pld.UnitPrice>0
										   order by pld.ItemID
				End
			ELSE IF @PriceListID!=0 and @Group1!=0
					Begin 
						SELECT 
							 pld.ID,
							  item.Code,
							  item.KhmerName,
							  item.EnglishName,
							  uom.Name as Uom,
							  pld.Cost as Cost,
							  convert(float,0) as Makup,
							  pld.UnitPrice as Price,
							  cur.[Description] as Currency,
							  convert(float,pld.Discount) as Discount,
							  pld.TypeDis,
							  item.Process,
							  @SysCurrency as SysCurrency,
							   item.Barcode as Barcode
						FROM tbPriceListDetail pld 
											   inner join tbItemMasterData item on pld.ItemID=item.ID
											   inner join tbCurrency cur on pld.CurrencyID=cur.ID
											   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
											   where item.[Delete]=0 and pld.PriceListID=@PriceListID and item.ItemGroup1ID=@Group1 and pld.UnitPrice>0
											   order by pld.ItemID
					End
				
		End
END

----------------------------------  sp_InsertSatAndUpdatePriceList (Old Script) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[sp_InsertSatAndUpdatePriceList] 
	(
	@ID int =0,
	@PriceListID int,
	@ItemID int,
	@UserID int,
	@UomID int,
	@CurrencyID int,
	@Quantity float,
	@Discount real,
	@TypeDis nvarchar,
	@PromotionID int,
	@ExpireDate datetime,
	@SystemDate datetime,
	@TimeIn datetime,
	@Cost float,
	@UniPrice float,
	@Barcode float
	
	)
AS
BEGIN

	IF(@ID=0)
		BEGIN
			INSERT INTO tbPriceListDetail(ID,PriceListID,ItemID,UserID,UomID,CurrencyID,Quantity,Discount,TypeDis,PromotionID,[ExpireDate],TimeIn,Cost,UnitPrice,Barcode)
			VALUES (@ID,@PriceListID,@ItemID,@UserID,@UomID,@CurrencyID,@Quantity,@Discount,@TypeDis,@PromotionID,@ExpireDate,@TimeIn,@Cost,@UniPrice,@Barcode)
		END
	ELSE IF(@ID!=0)
		BEGIN
			 Update tbPriceListDetail 
			 SET	PriceListID = @PriceListID,
					ItemID= @ItemID,
					UserID=@UserID,
					UomID=@UomID,
					CurrencyID=@CurrencyID,
					Quantity=@Quantity,
					Discount=@Discount,
					TypeDis=@TypeDis,
					PromotionID=@PromotionID,
					[ExpireDate]=@ExpireDate,
					SystemDate=@SystemDate,
					TimeIn=@TimeIn,
					Cost=@Cost,
					UnitPrice=@UniPrice,
					Barcode=@Barcode
			WHERE ID=@ID 
		END
END

----------------------------------  [uspGetSaleServiceReports] (Old Script) --------------------------------------------
 
GO
CREATE OR ALTER PROC [dbo].[uspGetSaleServiceReports](@dateFrom date, @dateTo date,@keyword NVARCHAR(MAX))
AS 
BEGIN
	SELECT
	MAX(T0.Code) AS Code,
	MAX(I.ID) AS ItemID,
	MAX(T0.KhmerName) AS ProductName,
	Max(T0.Code) AS ItemCode,
	MAX(T0.Qty) AS Qty,
	MAX(T9.Name) AS NameType,
	MAX(T2.Code) AS CustomerCode,
	MAX(T2.[Name]) AS CustomerName,
	MAX(T5.ModelName) AS ModelName,
	MAX(T4.BrandName) AS BrandName,
	MAX(T3.Frame) AS Frame,
	MAX(T3.Engine) AS Engine,
	MAX(T3.Plate) AS Plate,
	MAX(T3.Year) AS Year,
	MAX(T7.TypeName) AS TypeName,
	MAX(T6.ColorName) AS Color,
	MAX(T1.DateOut) AS InvoiceDate,
	MAX(T9.Code) AS PreFix,
	MAX(T1.ReceiptNo) AS InvoiceNo,
	MAX(T1.CustomerID) AS CustomerID,
	Max(T0.UnitPrice) AS UnitPrice,
	Max(ISNULL(T3.AutoMID, 0)) AS VehicleID,
	Max(T1.PLRate) AS PLRate,
	Max(SaleC.Description) As CurrencyName,
	Max(SysC.Description) AS SysCurrencyName,
	Max(Sysc.ID) AS SysCurrencyID
	FROM tbReceiptDetail T0
	INNER JOIN tbReceipt T1 ON T0.ReceiptID = T1.ReceiptID
	INNER JOIN tbItemMasterData I ON T0.ItemID = I.ID
	INNER JOIN tbBusinessPartner T2 ON T1.CustomerID = T2.ID
	INNER JOIN tbCurrency SaleC ON T1.PLCurrencyID = SaleC.ID
	INNER JOIN tbCurrency SysC ON T1.SysCurrencyID = SysC.ID
	LEFT JOIN tbAutoMobile T3 ON T1.vehicleID = T3.AutoMID
	LEFT JOIN tbAutoBrand T4 ON T3.BrandID = T4.BrandID
	LEFT JOIN tbAutoModel T5 ON T3.ModelID =T5.ModelID
	LEFT JOIN tbAutoColor T6 ON T3.ColorID = T6.ColorID 
	LEFT JOIN tbAutoType T7 ON T3.TypeID = T7.TypeID
	INNER JOIN tbSeries T8 ON T1.SeriesID = T8.ID
	INNER JOIN tbDocumentType T9 ON T8.DocuTypeID = T9.ID
	WHERE T1.DateOut BETWEEN @dateFrom AND @dateTo
		AND(T0.Code like '%'+ @keyword +'%'
		OR T0.KhmerName like '%'+ @keyword +'%'
		OR T2.Code like '%'+ @keyword +'%'
		OR T2.Name like '%'+ @keyword +'%'
		OR T4.BrandName like '%'+ @keyword +'%'
		OR T5.ModelName like '%'+ @keyword +'%'
		OR T3.Frame like '%'+ @keyword +'%'
		OR T3.Engine like '%'+ @keyword +'%'
		OR T3.Plate like '%'+ @keyword +'%')
	GROUP BY T0.ID;
END

----------------------------------  [uspGetUseServiceReports] (Old Script) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetUseServiceReports](@dateFrom date, @dateTo date, @keyword NVARCHAR(MAX))
AS 
BEGIN
	SELECT 
	MAX(T2.Code) AS Code,
	MAX(T0.ItemID) AS ItemID,
	MAX(T2.KhmerName) AS ProductName,
	Max(T2.Code) AS ItemCode,
	MAX(T0.Qty) AS Qty,
	MAX(T0.UsedCount) AS UsedCount ,
	MAX(T9.Name) AS NameType,
	MAX(T3.Code) AS CustomerCode,
	MAX(T3.[Name]) AS CustomerName,
	MAX(T6.ModelName) AS ModelName,
	MAX(T5.BrandName) AS BrandName,
	MAX(T4.Frame) AS Frame,
	MAX(T4.Engine) AS Engine,
	MAX(T4.Plate) AS Plate,
	MAX(T4.Year) AS Year,
	MAX(T8.TypeName) AS TypeName,
	MAX(T7.ColorName) AS Color,
	MAX(T0.PostingDate) AS InvoiceDate,
	MAX(T9.Code) AS PreFix,
	MAX(T0.Invoice) AS InvoiceNo,
	MAX(T0.CusID) AS CusID,
	MAX(T0.CurrencyID) AS CurrencyID,
	Max(T0.vehicleID) AS VehicleID
	from UseServiceHistories T0
	join tbItemMasterData T2 ON T0.ItemID = T2.ID
	join tbBusinessPartner T3 ON T0.CusID = T3.ID
	left join tbAutoMobile T4 ON T0.vehicleID = T4.AutoMID
	left join tbAutoBrand T5 ON T4.BrandID = T5.BrandID
	left join tbAutoModel T6 ON T4.ModelID =T6.ModelID
	left join tbAutoColor T7 ON T4.ColorID = T7.ColorID 
	left join tbAutoType T8 ON T4.TypeID = T8.TypeID
	join tbDocumentType T9 ON T0.DocType = T9.ID	
	join tbSeries T10 ON T9.ID = T10.ID
	WHERE T0.PostingDate BETWEEN @dateFrom AND @dateTo AND T0.UsedCount > 0
		AND(T3.Code like '%'+ @keyword +'%'
		OR T3.Name like '%'+ @keyword +'%'
		OR T2.Code like '%'+ @keyword +'%'
		OR T2.KhmerName like '%'+ @keyword +'%'
		OR T5.BrandName like '%'+ @keyword +'%'
		OR T6.ModelName like '%'+ @keyword +'%'
		OR T4.Frame like '%'+ @keyword +'%'
		OR T4.Engine like '%'+ @keyword +'%'
		OR T4.Plate like '%'+ @keyword +'%')

	GROUP BY T0.ID ;
END

----------------------------------  [uspSelectTable] (Old Script) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[uspSelectTable](@tableName VARCHAR(100)) 
AS 
BEGIN 
	IF OBJECT_ID (@tableName, N'U') IS NULL 
	BEGIN
		RAISERROR ('Table name not found.', 11, 1) WITH NOWAIT
		RETURN;
	END

	DECLARE @tablenametable TABLE(tablename VARCHAR(100));
	INSERT INTO @tablenametable
	VALUES(@tableName);

	DECLARE dbcursor CURSOR	
	FOR
		SELECT tablename
		FROM @tablenametable
	OPEN dbcursor;
	FETCH NEXT FROM dbcursor INTO @tablename;
	WHILE @@FETCH_STATUS = 0
		BEGIN
			DECLARE @sql VARCHAR(MAX);
			SET @sql = 'SELECT * FROM '+ @tablename;
			EXEC(@sql);
			FETCH NEXT FROM dbcursor INTO @tablename;
		END;
	CLOSE dbcursor;
	DEALLOCATE dbcursor;
END

---------------------------------- [GetAllActivitys] (KSMS Stored Procedures-29-07-2023) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetAllActivitys]
AS 
BEGIN
	SELECT
	MAX(A.ID) AS ActivityID,
	MAX(I.ID) AS ItemID,									  
	Max(ISNULL(T3.AutoMID, 0)) AS VihicleID,
	MAX(A.BPID) AS BPID,
	MAX(BP.Name) AS BpName,
	MAX(BP.Code) AS BpCode,
	MAX(BP.Phone) AS BpPhone,
	MAX(A.Number) AS Number,
	MAX(A.ActivityStatus) AS Status,
	MAX(I.KhmerName) AS ItemName,
	MAX(I.MaxOrderQty) AS Qty,
	MAX(T4.BrandName) AS BrandName,
	MAX(T3.Plate) AS PlateNumber,
	MAX(T3.Year) AS Year,
	MAX(G.Durration) AS Durration,
	MAX(G.StartTime) AS StartTimes,
	MAX(G.EndTime) AS EndTimes,
	MAX(A.Activities) AS ActivityName
	from Activity A
	join tbBusinessPartner BP ON A.BPID = BP.ID
	LEFT join General G ON A.ID = G.ActivityID
	LEFT join tbItemMasterData I ON A.ItemID = I.ID
	left join tbAutoMobile T3 ON A.VihicleID = T3.AutoMID
	left join tbAutoBrand T4 ON T3.BrandID = T4.BrandID
	left join tbAutoModel T5 ON T3.ModelID =T5.ModelID
	left join tbAutoColor T6 ON T3.ColorID = T6.ColorID 
	left join tbAutoType T7 ON T3.TypeID = T7.TypeID
	WHERE A.ActivityStatus = 0 And A.ItemID > 0
	GROUP BY A.ID;
END

----------------------------------  [GetCheckedUpListReports] (KSMS Stored Procedures-29-07-2023) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetCheckedUpListReports](@dateFrom date, @dateTo date)
AS 
BEGIN
	SELECT
	MAX(v.AutoMID) AS VehicleID,
	MAX(bp.ID) AS CustomerID,
	Max(cl.PostingDate) AS PostingDate,
	MAX(cl.ID) AS CheckedListID,
	Max(cld.ID) AS CheckedListDetailID,
	Max(cf.ID) AS CheckFormID,
	Max(cg.ID) AS CheckGroupID

	from CheckedLists cl
	join CheckedListDetails cld ON cl.ID = cld.CheckedUpListID
	join CheckUpForms cf ON cld.CheckFormID = cf.ID
	join CheckUpGroups cg ON cld.CheckGroupID = cg.ID
	join tbBusinessPartner bp ON cl.CusID = bp.ID
	left join tbAutoMobile v ON cl.VehicleID = v.AutoMID
	WHERE cl.PostingDate BETWEEN @dateFrom AND @dateTo
		
	GROUP BY cl.ID;
END

----------------------------------  [GetDashboardSaveServic] (KSMS Stored Procedures-29-07-2023) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetDashboardSaveServic]
AS 
BEGIN
	SELECT
	MAX(T1.ID) AS ReceiptID,
	MAX(T1.StartDate) AS StartDate,
	MAX(T1.EndDate) AS EndDate,
	MAX(T1.Progress) AS Progress,
	MAX(T1.StartTime)   AS StartTime,
	MAX(T1.EndTime) AS EndTime,
	MAX(T2.ID)		AS CustomerID,
	MAX(T2.Code)	AS CustomerCode,
	MAX(T2.[Name])  AS CustomerName,
	MAX(T2.Phone)   AS PhoneNumber,
	Max(ISNULL(T3.AutoMID, 0)) AS VehicleID,
	MAX(T3.Frame)   AS Frame,
	MAX(T3.Engine)  AS Engine,
	MAX(T3.Plate)   AS Plate,
	MAX(T3.Year)    AS Year,
	MAX(T4.BrandName) AS BrandName,
	MAX(T5.ModelName) AS ModelName,
	MAX(T6.ColorName) AS Color,
	MAX(T7.TypeName)  AS TypeName,
	MAX(TT.[Name])  AS TableName
	from Saveservices T1
	join tbTable TT				ON T1.TableID	 = TT.ID
	join tbBusinessPartner T2	ON T1.CusId      = T2.ID
	left join tbAutoMobile T3	ON T1.vehicleID	 = T3.AutoMID
	left join tbAutoBrand  T4	ON T3.BrandID    = T4.BrandID
	left join tbAutoModel  T5	ON T3.ModelID    = T5.ModelID
	left join tbAutoColor  T6	ON T3.ColorID    = T6.ColorID 
	left join tbAutoType   T7	ON T3.TypeID     = T7.TypeID
	where TT.[Status] !='A'
	GROUP BY T1.ID;
END

----------------------------------  [GetDashboardServicTracking] (KSMS Stored Procedures-29-07-2023) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetDashboardServicTracking]
AS 
BEGIN
	SELECT
	MAX(T1.OrderID) AS ReceiptID,
	MAX(T1.DateOut)   AS InvoiceDate,
	MAX(ISNULL(T1.StartDate, CONVERT(DATETIME, '00:00'))) AS StartDate,
	MAX(ISNULL(T1.EndDate,CONVERT(DATETIME, '00:00'))) AS EndDate,
	MAX(T1.Progress) AS Progress,
	MAX(ISNULL(T1.StartTime,'00:00:00'))   AS StartTime,
	MAX(ISNULL(T1.EndTime,'00:00:00')) AS EndTime,
	MAX(T2.ID)		AS CustomerID,
	MAX(T2.Code)	AS CustomerCode,
	MAX(T2.[Name])  AS CustomerName,
	MAX(T2.Phone)   AS PhoneNumber,
	Max(ISNULL(T3.AutoMID, 0)) AS VehicleID,
	MAX(T3.Frame)   AS Frame,
	MAX(T3.Engine)  AS Engine,
	MAX(T3.Plate)   AS Plate,
	MAX(T3.Year)    AS Year,
	MAX(T4.BrandName) AS BrandName,
	MAX(T5.ModelName) AS ModelName,
	MAX(T6.ColorName) AS Color,
	MAX(T7.TypeName)  AS TypeName,
	MAX(TT.[Name])  AS TableName
	from tbOrder T1
	join tbTable TT				ON T1.TableID	 = TT.ID
	join tbBusinessPartner T2	ON T1.CustomerID = T2.ID
	left join tbAutoMobile T3	ON T1.vehicleID	 = T3.AutoMID
	left join tbAutoBrand  T4	ON T3.BrandID    = T4.BrandID
	left join tbAutoModel  T5	ON T3.ModelID    = T5.ModelID
	left join tbAutoColor  T6	ON T3.ColorID    = T6.ColorID 
	left join tbAutoType   T7	ON T3.TypeID     = T7.TypeID
	where TT.[Status] !='A'
	GROUP BY T1.OrderID;
END

----------------------------------  [GetSaleKilometer] (KSMS Stored Procedures-29-07-2023) --------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleKilometer]
AS 
BEGIN
	SELECT
	Max(ISNULL(T3.AutoMID, 0)) AS VehicleID,
	MAX(T1.ReceiptID) AS ReceiptID,
	MAX(T0.ID) AS ReceiptDID,
	Max(T1.OrderID) AS OrderID,
	MAX(T0.OrderDetailID) AS OrderDetailID,
	Max(T1.CheckedUpListID) AS CheckedUpListID,
	MAX(T1.CustomerID) AS CusID,
	MAX(I.ID) AS ItemID,
	MAX(T1.DateOut) AS PostingDate,
	MAX(T1.ReceiptNo) AS InvoiceNo,
	MAX(U.Username) AS Creator,
	MAX(T9.Name) AS DocType,
	MAX(T2.Code) AS CusCode,
	MAX(T2.[Name]) AS CusName,
	MAX(T3.Plate + ', ' + T4.BrandName + ', ' + T7.TypeName + ', ' +
	T5.ModelName + ', ' + T6.ColorName) AS Vehicle,
	Max(T0.Code) AS ItemCode,
	MAX(T0.KhmerName) AS ItemName1,
	MAX(T0.EnglishName) AS ItemName2,
	MAX(T0.Qty) AS Qty,
	MAX(Uom.Name) AS Uom,
	Max(T0.DiscountValue) AS DisItem,
	Max(T1.DiscountValue) AS DisTotal,
	Max(T0.UnitPrice) AS Price,
	Max(SaleC.Description) As Currency,
	Max(SysC.Symbol) As Symbol,
	Max(SysC.ID) AS CurID,
	Max(T0.Total_Sys) As SubTotal,
	Max(T1.GrandTotal_Sys) AS SGrandTotal
	from tbReceiptDetail T0
	join tbReceipt T1 ON T0.ReceiptID = T1.ReceiptID
	join tbItemMasterData I on T0.ItemID = I.ID
	join tbBusinessPartner T2 ON T1.CustomerID = T2.ID
	join tbUserAccount U ON T1.UserOrderID = U.ID
	join tbCurrency SaleC ON T1.PLCurrencyID = SaleC.ID
	join tbCurrency SysC ON T1.SysCurrencyID = SysC.ID
	join tbSeries T8 ON T1.SeriesID = T8.ID
	join tbDocumentType T9 ON T8.DocuTypeID = T9.ID
	join tbUnitofMeasure Uom ON T0.UomID = Uom.ID
	left join tbAutoMobile T3 ON T1.vehicleID = T3.AutoMID
	left join tbAutoBrand T4 ON T3.BrandID = T4.BrandID
	left join tbAutoModel T5 ON T3.ModelID =T5.ModelID
	left join tbAutoColor T6 ON T3.ColorID = T6.ColorID 
	left join tbAutoType T7 ON T3.TypeID = T7.TypeID
	GROUP BY T0.ID;
END


----------------------------------  [[GetSubActivitys]] (KSMS Stored Procedures-29-07-2023) --------------------------------------------\

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSubActivitys]
AS 
BEGIN
	SELECT
	MAX(SA.ID) AS ID,
	MAX(SA.EmpID) AS EmpID,
	MAX(SA.Number) AS Number,
	MAX(SA.ActivityID) AS ActivityID,
	MAX(SA.Duration) AS Duration,
	MAX(SA.StartTime) AS StartTimes,
	MAX(SA.EndTime) AS EndTimes,
	MAX(SA.Remarks) AS Remarks
	from Activity A
	join SubActivities SA ON SA.ActivityID = A.ID
	WHERE A.ItemID > 0 AND A.ActivityStatus = 0
	GROUP BY SA.ID;
END

-------------------------------------------------------[uspGetSaleServiceReports] (KSMS Stored Procedures-29-07-2023)-----------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetSaleServiceReports](@dateFrom date, @dateTo date,@keyword NVARCHAR(MAX))
AS 
BEGIN
	SELECT
	MAX(T0.Code) AS Code,
	MAX(I.ID) AS ItemID,
	MAX(T0.KhmerName) AS ProductName,
	Max(T0.Code) AS ItemCode,
	MAX(T0.Qty) AS Qty,
	MAX(T9.Name) AS NameType,
	MAX(T2.Code) AS CustomerCode,
	MAX(T2.[Name]) AS CustomerName,
	MAX(T5.ModelName) AS ModelName,
	MAX(T4.BrandName) AS BrandName,
	MAX(T3.Frame) AS Frame,
	MAX(T3.Engine) AS Engine,
	MAX(T3.Plate) AS Plate,
	MAX(T3.Year) AS Year,
	MAX(T7.TypeName) AS TypeName,
	MAX(T6.ColorName) AS Color,
	MAX(T1.DateOut) AS InvoiceDate,
	MAX(T9.Code) AS PreFix,
	MAX(T1.ReceiptNo) AS InvoiceNo,
	MAX(T1.CustomerID) AS CustomerID,
	Max(T0.UnitPrice) AS UnitPrice,
	Max(ISNULL(T3.AutoMID, 0)) AS VehicleID,
	Max(T1.PLRate) AS PLRate,
	Max(SaleC.Description) As CurrencyName,
	Max(SysC.Description) AS SysCurrencyName,
	Max(Sysc.ID) AS SysCurrencyID
	from tbReceiptDetail T0
	join tbReceipt T1 ON T0.ReceiptID = T1.ReceiptID
	join tbItemMasterData I on T0.ItemID = I.ID
	join tbBusinessPartner T2 ON T1.CustomerID = T2.ID
	join tbCurrency SaleC ON T1.PLCurrencyID = SaleC.ID
	join tbCurrency SysC ON T1.SysCurrencyID = SysC.ID
	left join tbAutoMobile T3 ON T1.vehicleID = T3.AutoMID
	left join tbAutoBrand T4 ON T3.BrandID = T4.BrandID
	left join tbAutoModel T5 ON T3.ModelID =T5.ModelID
	left join tbAutoColor T6 ON T3.ColorID = T6.ColorID 
	left join tbAutoType T7 ON T3.TypeID = T7.TypeID
	join tbSeries T8 ON T1.SeriesID = T8.ID
	join tbDocumentType T9 ON T8.DocuTypeID = T9.ID
	WHERE T1.DateOut BETWEEN @dateFrom AND @dateTo
		AND(T0.Code like '%'+ @keyword +'%'
		OR T0.KhmerName like '%'+ @keyword +'%'
		OR T2.Code like '%'+ @keyword +'%'
		OR T2.Name like '%'+ @keyword +'%'
		OR T4.BrandName like '%'+ @keyword +'%'
		OR T5.ModelName like '%'+ @keyword +'%'
		OR T3.Frame like '%'+ @keyword +'%'
		OR T3.Engine like '%'+ @keyword +'%'
		OR T3.Plate like '%'+ @keyword +'%')

	GROUP BY T0.ID;
END

---------------------------------------------------------[uspGetUseServiceReports] (KSMS Stored Procedures-29-07-2023) ---------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetUseServiceReports](@dateFrom date, @dateTo date, @keyword NVARCHAR(MAX))
AS 
BEGIN
	SELECT 
	MAX(T2.Code) AS Code,
	MAX(T0.ItemID) AS ItemID,
	MAX(T2.KhmerName) AS ProductName,
	Max(T2.Code) AS ItemCode,
	MAX(T0.Qty) AS Qty,
	MAX(T0.UsedCount) AS UsedCount ,
	MAX(T9.Name) AS NameType,
	MAX(T3.Code) AS CustomerCode,
	MAX(T3.[Name]) AS CustomerName,
	MAX(T6.ModelName) AS ModelName,
	MAX(T5.BrandName) AS BrandName,
	MAX(T4.Frame) AS Frame,
	MAX(T4.Engine) AS Engine,
	MAX(T4.Plate) AS Plate,
	MAX(T4.Year) AS Year,
	MAX(T8.TypeName) AS TypeName,
	MAX(T7.ColorName) AS Color,
	MAX(T0.PostingDate) AS InvoiceDate,
	MAX(T9.Code) AS PreFix,
	MAX(T0.Invoice) AS InvoiceNo,
	MAX(T0.CusID) AS CusID,
	MAX(T0.CurrencyID) AS CurrencyID,
	Max(T0.vehicleID) AS VehicleID	
	from UseServiceHistories T0
	join tbItemMasterData T2 ON T0.ItemID = T2.ID
	join tbBusinessPartner T3 ON T0.CusID = T3.ID
	left join tbAutoMobile T4 ON T0.vehicleID = T4.AutoMID
	left join tbAutoBrand T5 ON T4.BrandID = T5.BrandID
	left join tbAutoModel T6 ON T4.ModelID =T6.ModelID
	left join tbAutoColor T7 ON T4.ColorID = T7.ColorID 
	left join tbAutoType T8 ON T4.TypeID = T8.TypeID
	join tbDocumentType T9 ON T0.DocType = T9.ID	
	join tbSeries T10 ON T9.ID = T10.ID
	WHERE T0.PostingDate BETWEEN @dateFrom AND @dateTo AND T0.UsedCount > 0
		AND(T3.Code like '%'+ @keyword +'%'
		OR T3.Name like '%'+ @keyword +'%'
		OR T2.Code like '%'+ @keyword +'%'
		OR T2.KhmerName like '%'+ @keyword +'%'
		OR T5.BrandName like '%'+ @keyword +'%'
		OR T6.ModelName like '%'+ @keyword +'%'
		OR T4.Frame like '%'+ @keyword +'%'
		OR T4.Engine like '%'+ @keyword +'%'
		OR T4.Plate like '%'+ @keyword +'%')
	GROUP BY T0.ID ;
END

---------------------------------------------------GeneralDetermination 19-August-2023--------------------------------------------------------------

GO
IF NOT EXISTS (select * from GeneralDetermination where Code ='PUY')
insert into GeneralDetermination (TypeOfAccount, GLID, Code, SaleGLDeterminationMasterID)
values ('Profit During The Year', 0, 'PUY',1)
IF NOT EXISTS (select * from GeneralDetermination where Code ='YAC')
insert into GeneralDetermination (TypeOfAccount, GLID, Code, SaleGLDeterminationMasterID)
values ('Year And Closing', 0, 'YAC',1)

IF NOT EXISTS (select * from GeneralDetermination where Code ='GEP')
insert into GeneralDetermination (TypeOfAccount, GLID, Code, SaleGLDeterminationMasterID)
values ('General Expense', 0, 'GEP',1)

IF NOT EXISTS (select * from GeneralDetermination where Code ='VOE')
insert into GeneralDetermination (TypeOfAccount, GLID, Code, SaleGLDeterminationMasterID)
values ('Voucher Expense', 0, 'VOE',1)

---------------------------------------------------------[sp_GetItemDiscount]- 19-August-2023-------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[sp_GetItemDiscount](
@PriceListID int=0,
@Group1 int=0,
@Group2 int=0,
@Group3 int=0,
@PromotionId int=0,
@UomID int=0
)
AS
BEGIN
	IF @PriceListID!=0 and @Group1=0 and @Group2=0 and @Group3=0
		Begin
			SELECT DISTINCT
				   pld.ID,
				  item.ID as ItemID,
				  item.Code,
				  item.KhmerName,
				  item.EnglishName,
				  uom.Name as Uom,
				  pld.UnitPrice as Price,
				  cur.[Description] as Currency,
				  convert(float, ISNULL(prod.Discount,0)) as Discount,
				  pld.TypeDis
			FROM tbPriceListDetail pld 
								   inner join tbItemMasterData item on pld.ItemID=item.ID
								   inner join tbCurrency cur on pld.CurrencyID=cur.ID
								   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
								   LEFT join tbPromotionDetail prod on​​ prod.PromotionID = @PromotionId and prod.ItemID = item.ID 
								   where item.[Delete]=0 and pld.PriceListID=@PriceListID  
								   order by item.Code
		End
	ELSE IF @PriceListID!=0 and @Group1!=0 and @Group2=0 and @Group3=0
		Begin 
			SELECT DISTINCT
				    pld.ID,
				  item.ID as ItemID,
				  item.Code,
				  item.KhmerName,
				  item.EnglishName,
				  uom.Name as Uom,
				  pld.UnitPrice as Price,
				  cur.[Description] as Currency,
				  convert(float,ISNULL(prod.Discount,0)) as Discount,
				  pld.TypeDis
			FROM tbPriceListDetail pld 
								   inner join tbItemMasterData item on pld.ItemID=item.ID
								   inner join tbCurrency cur on pld.CurrencyID=cur.ID
								   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
								   left join tbPromotionDetail prod on prod.PromotionID = @PromotionId and prod.ItemID = item.ID 
								   where item.[Delete]=0 and pld.PriceListID=@PriceListID and item.ItemGroup1ID=@Group1
								   order by item.Code
		End
END

---------------------------------------------[DashboardR1show] 31-August-2023\Dashboard-23Aug2023---------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[DashboardR1show]
AS
	BEGIN
	DECLARE @AVG FLOAT = 0
	DECLARE @receiptmemo FLOAT = 0
	DECLARE @saleaR FLOAT = 0
	DECLARE @salearRes FLOAT = 0
	DECLARE @salearSer FLOAT = 0
	DECLARE @salearedit FLOAT = 0
	DECLARE @saleARMemo FLOAT =0
	DECLARE @TOTALCOUNT FLOAT =0
	DECLARE @TOTALCOUNTMEMO FLOAT =0
	DECLARE @SumAvg FLOAT =0
	DECLARE @SumAvgMemo FLOAT =0
	DECLARE @sumtotalReciept FLOAT =0
	DECLARE @sumtotalSaleAR FLOAT =0
	DECLARE @sumtotalsalearRes FLOAT =0
	DECLARE @sumtotalsalearSer FLOAT =0
	DECLARE @sumtotalsalearedit FLOAT =0
	DECLARE @sumtotalreceiptmemo FLOAT =0
	DECLARE @sumtotalsaleARMemo FLOAT =0
	DECLARE @GRANDTOTALCOUNT FLOAT =0
	DECLARE @GRANDTOTALAVG FLOAT =0
	DECLARE @reDetail FLOAT =0
	DECLARE @memoDetail FLOAT =0
	DECLARE @saleARDetail FLOAT =0
	DECLARE @SaleARredetail FLOAT =0
	DECLARE @saleARSercondetail FLOAT =0
	DECLARE @salememoDetail FLOAT =0
	DECLARE @saleEditDetail FLOAT =0
	DECLARE @ReMemoDetailCount FLOAT =0
	DECLARE @ReDetailQty FLOAT =0
	DECLARE @ReMemoDetailQty FLOAT =0
	DECLARE @saleMemoDetailQty FLOAT =0
	DECLARE @saleDetailQty FLOAT =0
	DECLARE @saleARRDetailQty FLOAT =0
	DECLARE @saleARSerdetailQty FLOAT =0
	DECLARE @saleArEditDetailQty FLOAT =0
	DECLARE @totalCountAvgQty FLOAT =0
	DECLARE @totalQty FLOAT =0
	DECLARE @allavg FLOAT =0
  SET @AVG =(SELECT COUNT(*) FROM tbReceipt R WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @saleaR =(SELECT COUNT(*) FROM tbSaleAR R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @salearRes =(SELECT COUNT(*) FROM ARReserveInvoice R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @salearSer =(SELECT COUNT(*) FROM ServiceContract R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @salearedit =(SELECT COUNT(*) FROM SaleAREdites R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));

  SET @receiptmemo =(SELECT COUNT(*) FROM ReceiptMemo R WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @saleARMemo =(SELECT COUNT(*) FROM SaleCreditMemos R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));

  SET @TOTALCOUNT = @AVG + @saleaR + @salearRes + @salearSer + @salearedit;
  SET @TOTALCOUNTMEMO = @saleARMemo+ @receiptmemo;

  SET @sumtotalReciept = (SELECT convert(float, ISNULL(SUM(r.GrandTotal_Sys),0)) FROM tbReceipt r WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @sumtotalSaleAR = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM tbSaleAR r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @sumtotalsalearRes = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM ARReserveInvoice r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @sumtotalsalearSer = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM ServiceContract r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @sumtotalsalearedit = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM SaleAREdites r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));

  SET @sumtotalreceiptmemo = (SELECT convert(float, ISNULL(SUM(r.GrandTotalSys),0)) FROM ReceiptMemo r WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @sumtotalsaleARMemo = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM SaleCreditMemos r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  
  SET @SumAvg = @sumtotalReciept + @sumtotalSaleAR +@sumtotalsalearRes + @sumtotalsalearedit + @sumtotalsalearSer
  SET @SumAvgMemo = @sumtotalreceiptmemo + @sumtotalsaleARMemo

  SET @GRANDTOTALCOUNT = @TOTALCOUNT -@TOTALCOUNTMEMO
  SET @GRANDTOTALAVG = @SumAvg - @SumAvgMemo
   --decimal allavg = totalCount == 0 ? 0 : totalAmount / totalCount;
  SET @reDetail =(SELECT Count(*) FROM tbReceipt R INNER JOIN tbReceiptDetail RD ON R.ReceiptID = RD.ReceiptID WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @memoDetail =(SELECT COUNT(*) FROM ReceiptMemo RMEMO INNER JOIN ReceiptDetailMemoKvms RMEMOD ON RMEMO.ID = RMEMOD.ReceiptMemoID WHERE YEAR(GETDATE()) <= YEAR(RMEMO.DateOut));
  SET @saleARDetail =(SELECT COUNT(*) FROM tbSaleAR S INNER JOIN tbSaleARDetail SD ON S.SARID = SD.SARID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @SaleARredetail =(SELECT COUNT(*) FROM ARReserveInvoice S INNER JOIN ARReserveInvoiceDetail SD ON S.ID = SD.ARReserveInvoiceID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleARSercondetail =(SELECT COUNT(*) FROM ServiceContract S INNER JOIN ServiceContractDetail SD ON S.ID = SD.ServiceContractID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @salememoDetail=(SELECT COUNT(*) FROM SaleCreditMemos S INNER JOIN tbSaleCreditMemoDetail SD ON S.SCMOID = SD.SCMOID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleEditDetail=(SELECT COUNT(*) FROM SaleAREdites S INNER JOIN SaleAREditeDetails SD ON S.SARID = SD.SARID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));

  SET @ReDetailQty =(SELECT convert(float, ISNULL(SUM(RD.Qty),0)) FROM tbReceipt R INNER JOIN tbReceiptDetail RD ON R.ReceiptID = RD.ReceiptID WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @ReMemoDetailQty =(SELECT convert(float, ISNULL(SUM(RMEMOD.Qty),0)) FROM ReceiptMemo RMEMO INNER JOIN ReceiptDetailMemoKvms RMEMOD ON RMEMO.ID = RMEMOD.ReceiptMemoID WHERE YEAR(GETDATE()) <= YEAR(RMEMO.DateOut));
  SET @saleDetailQty =(SELECT convert(float, ISNULL(SUM(SD.Qty),0)) FROM tbSaleAR S INNER JOIN tbSaleARDetail SD ON S.SARID = SD.SARID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleARRDetailQty =(SELECT convert(float, ISNULL(SUM(SD.Qty),0)) FROM ARReserveInvoice S INNER JOIN ARReserveInvoiceDetail SD ON S.ID = SD.ARReserveInvoiceID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleARSerdetailQty =(SELECT convert(float, ISNULL(SUM(SD.Qty),0)) FROM ServiceContract S INNER JOIN ServiceContractDetail SD ON S.ID = SD.ServiceContractID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleMemoDetailQty=(SELECT convert(float, ISNULL(SUM(SD.Qty),0)) FROM SaleCreditMemos S INNER JOIN tbSaleCreditMemoDetail SD ON S.SCMOID = SD.SCMOID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleArEditDetailQty=(SELECT COUNT(*) FROM SaleAREdites S INNER JOIN SaleAREditeDetails SD ON S.SARID = SD.SARID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
	
   SET @totalCountAvgQty = (@reDetail +@saleARDetail +@SaleARredetail +@saleARSercondetail + @saleEditDetail)-(@memoDetail+@salememoDetail)
   SET @totalQty = (@ReDetailQty +@saleDetailQty +@saleARRDetailQty +@saleARSerdetailQty + @saleArEditDetailQty)-(@ReMemoDetailQty+@saleMemoDetailQty)
   SELECT 
	@SumAvg as SumAvg,
	@SumAvgMemo as SumAvgMemo,
	@GRANDTOTALCOUNT as totalCount,
	@GRANDTOTALAVG as totalAmount,
	@TOTALCOUNT as [Count],
	@TOTALCOUNTMEMO as countMemo,
	@ReDetailQty as ReDetailQty,
	@ReMemoDetailQty as ReMemoDetailQty,
	@saleDetailQty as saleDetailQty,
	@saleARRDetailQty​​ as saleARRDetailQty,
	@saleARSerdetailQty as saleARSerdetailQty,
	@saleMemoDetailQty as saleMemoDetailQty,
	@saleArEditDetailQty as saleArEditDetailQty,
	@totalCountAvgQty as totalCountAvgQty,
	@totalQty as totalQty
END;

-----------------------------------------------------------[GetRecieptMonthly] \31-August-2023\Dashboard-23Aug2023-------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetRecieptMonthly]
AS
BEGIN
	SELECT 
	MAX(item.ID) as [ReceiptID],
	MAX(r.ReceiptID) as [SARID],
	MAX(rd.ID) as [SARDID],
	MAX(item.ID) as [ItemID],
	SUM(rd.Total_Sys) as [SubTotal],
	SUM(r.GrandTotal_Sys)as [GrandTotal],
	MAX(item.KhmerName) as [ItemName],
	MAX(item.ItemGroup1ID)as [Group1ID],
	--MAX(MONTHNAME(s.PostingDate)) as [Month],
	MAX(DATENAME(MONTH,r.DateOut)) as [Month],
	MAX(r.DateOut) as [DateOut],
	MAX(U.Name) AS [GroupName]
	FROM tbReceipt r
	INNER JOIN tbReceiptDetail rd on r.ReceiptID = rd.ReceiptID
	INNER JOIN tbItemMasterData item on rd.ItemID = item.ID
	INNER JOIN ItemGroup1 U ON item.ItemGroup1ID = U.ItemG1ID
	INNER JOIN tbCurrency c on r.SysCurrencyID = c.ID
	WHERE YEAR(GETDATE()) <= YEAR(r.DateOut)
	GROUP BY rd.ItemID
END;

-------------------------------------------------[GetRecieptMemos] 31-August-2023\Dashboard-23Aug2023--------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetRecieptMemos]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.ReceiptKvmsID) AS [SARID],
		MAX(SD.ID) AS [SARDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SysCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		(MAX(SD.UnitPrice) * MAX(sd.Qty)) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		(MAX(SD.UnitPrice) * MAX(sd.Qty)) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.DateOut) AS [PostingDate],
		SUM(S.GrandTotalSys) AS [GrandTotalSys]
	FROM ReceiptMemo s 
		INNER JOIN ReceiptDetailMemoKvms  sd on s.ID = sd.ReceiptMemoID
	WHERE YEAR(GETDATE()) <= YEAR(s.DateOut) 
	GROUP BY sd.ID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - SD.TotalDisValue) ELSE (SD.TotalSys- SD.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.SARID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID
END

-------------------------------------------------[GetReciepts]31-August-2023\Dashboard-23Aug2023----------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetReciepts]
AS
BEGIN
   SELECT
	  MAX(r.ReceiptID) as ReceiptID,
	  MAX(rd.ItemID) as ItemID,
	  MAX(item.KhmerName) as ItemName,
      SUM(rd.Total_Sys)- SUM(rd.TaxValue) as SubTotal,                    
      SUM(r.GrandTotal_Sys) as GrandTotal,    
	  MAX(item.ItemGroup1ID) as Group1ID,
	  MAX(rd.Total_Sys) - SUM(rd.TaxValue) as TotalItem,
	  MAX(MONTH(r.DateOut)) as [Month],
	  MAX(r.DateOut) as DateOut
FROM tbReceipt r
inner join tbReceiptDetail rd on rd.ReceiptID = r.ReceiptID
inner join tbItemMasterData item on rd.ItemID = item.ID
inner join tbCurrency c on r.SysCurrencyID = c.ID
WHERE YEAR(GETDATE()) <= YEAR(r.DateOut) 
GROUP BY rd.ID
END

---------------------------------[GetSaleARs] 31-August-2023\Dashboard-23Aug2023--------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleARs]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.SARID) AS [SARID],
		MAX(SD.SARDID) AS [SARDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SaleCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		MAX(SD.TotalSys) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		SUM(SD.TotalSys) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.PostingDate) AS [PostingDate],
		SUM(S.SubTotalSys) AS [GrandTotalSys]
	FROM tbSaleAR s 
		INNER JOIN tbSaleARDetail sd on s.SARID = sd.SARID
	WHERE YEAR(GETDATE()) <= YEAR(s.PostingDate) 
	GROUP BY sd.SARDID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - sd.TotalDisValue) ELSE (SD.TotalSys - sd.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.SARID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID

END

--------------------------------------------[GetSaleAREdit] 31-August-2023\Dashboard-23Aug2023------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleAREdit]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.SARID) AS [SARID],
		MAX(SD.SARDID) AS [SARDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SaleCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		MAX(SD.TotalSys) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		SUM(SD.TotalSys) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.PostingDate) AS [PostingDate],
		SUM(S.SubTotalSys) AS [GrandTotalSys]
	FROM SaleAREdites s 
		INNER JOIN SaleAREditeDetails sd on s.SARID = sd.SARID
	WHERE YEAR(GETDATE()) <= YEAR(s.PostingDate) 
	GROUP BY sd.SARDID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - sd.TotalDisValue) ELSE (SD.TotalSys - sd.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.SARID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID
END

------------------------------------------------[GetSaleARsMonthly] 31-August-2023\Dashboard-23Aug2023-------------------------------------------------------

GO
CREATE OR ALTER   PROCEDURE [dbo].[GetSaleARsMonthly]
AS
BEGIN
	SELECT 
	MAX(item.ID) as [Sarid],
	MAX(s.SARID) as [SARID],
	MAX(sd.SARDID) as [SARDID],
	MAX(item.ID) as [ItemID],
	SUM(s.SubTotal) as [SubTotal],
	SUM(s.TotalAmount)as [GrandTotal],
	MAX(item.KhmerName) as [ItemName],
	MAX(item.ItemGroup1ID)as [Group1ID],
	--MAX(MONTHNAME(s.PostingDate)) as [Month],
	MAX(DATENAME(MONTH,s.PostingDate)) as [Month],
	MAX(U.Name) AS [GroupName]
	FROM tbSaleAR s
	INNER JOIN tbSaleARDetail sd on s.SARID = sd.SARID
	INNER JOIN tbItemMasterData item on sd.ItemID = item.ID
	INNER JOIN ItemGroup1 U ON item.ItemGroup1ID = U.ItemG1ID
	INNER JOIN tbCurrency c on sd.CurrencyID = c.ID
	GROUP BY sd.ItemID

END;

------------------------------------------------[GetSaleARReserveMonthly] 31-August-2023\Dashboard-23Aug2023--------------------------------------------------------------

GO
CREATE OR ALTER   PROCEDURE [dbo].[GetSaleARReserveMonthly]
AS
BEGIN
	SELECT 
	MAX(sd.ItemID) as [Sarid],
	MAX(s.ID) as [SARID],
	MAX(sd.ID) as [SARDID],
	MAX(item.ID) as [ItemID],
	SUM(s.SubTotal) as [SubTotal],
	SUM(s.TotalAmount)as [GrandTotal],
	MAX(item.ItemGroup1ID)as [Group1ID],
	MAX(item.KhmerName) as [ItemName],
	--MAX(MONTHNAME(s.PostingDate)) as [Month],
	MAX(DATENAME(MONTH,s.PostingDate)) as [Month],
	MAX(U.Name) AS [GroupName]
	FROM ARReserveInvoice s
	INNER JOIN ARReserveInvoiceDetail sd on s.ID = sd.ARReserveInvoiceID
	INNER JOIN tbItemMasterData item on sd.ItemID = item.ID
	INNER JOIN ItemGroup1 U ON item.ItemGroup1ID = U.ItemG1ID
	INNER JOIN tbCurrency c on sd.CurrencyID = c.ID
	GROUP BY sd.ItemID
END;

-------------------------------------------------------------------[GetSaleARSercontract] 31-August-2023\Dashboard-23Aug2023---------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleARSercontract]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.ID) AS [ID],
		MAX(SD.ID) AS [SERDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SaleCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		MAX(SD.TotalSys) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		SUM(SD.TotalSys) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.PostingDate) AS [PostingDate],
		SUM(S.SubTotalSys) AS [GrandTotalSys]
	FROM ServiceContract s 
		INNER JOIN ServiceContractDetail sd on s.ID = sd.ServiceContractID
	WHERE YEAR(GETDATE()) <= YEAR(s.PostingDate) 
	GROUP BY sd.ID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - sd.TotalDisValue) ELSE (SD.TotalSys - sd.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.ID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID
END

-----------------------------------------------------------[GetSaleCreadiMemos] 31-August-2023\Dashboard-23Aug2023--------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleCreadiMemos]
AS
BEGIN
	DECLARE @subTotal FLOAT = 0
	DECLARE @disInvoiceValue FLOAT =0
	DECLARE @TotalItem FLOAT =0

	SET @subTotal = (SELECT SUM(rd.TotalSys) FROM SaleCreditMemos r inner join tbSaleCreditMemoDetail rd on r.SCMOID = rd.SCMOID)
	SET @disInvoiceValue = (SELECT SUM(rd.TotalSys) * SUM(r.DisRate/100)  FROM SaleCreditMemos r inner join tbSaleCreditMemoDetail rd on r.SCMOID = rd.SCMOID)
	SET @TotalItem = (SELECT SUM(rd.TotalSys) -@disInvoiceValue  FROM SaleCreditMemos r inner join tbSaleCreditMemoDetail rd on r.SCMOID = rd.SCMOID)
   SELECT
		 
		  MAX(r.SCMOID) as ReceiptID,
		  MAX(rd.ItemID) as ItemID,
		  MAX(item.KhmerName) as ItemName,
		  SUM(rd.TotalSys) as SubTotal,                    
		  SUM(r.SubTotalSys) as GrandTotal,    
		  MAX(item.ItemGroup1ID) as Group1ID,
		  MAX(MONTH(r.PostingDate)) as [Month],
		  MAX(r.PostingDate) as DateOut,
		  MAX(rd.TotalSys)- @disInvoiceValue as TotalItem
	FROM SaleCreditMemos r
	inner join tbSaleCreditMemoDetail rd on rd.SCMOID = r.SCMOID
	inner join tbItemMasterData item on rd.ItemID = item.ID
	WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate) 
	GROUP BY rd.SCMODID
END;

---------------------------------------------------------------[GetSaleReserve] 31-August-2023\Dashboard-23Aug2023-----------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleReserve]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.ID) AS [ID],
		MAX(SD.ID) AS [ARDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SaleCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		MAX(SD.TotalSys) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		SUM(SD.TotalSys) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.PostingDate) AS [PostingDate],
		SUM(S.SubTotalSys) AS [GrandTotalSys]
	FROM ARReserveInvoice s 
		INNER JOIN ARReserveInvoiceDetail sd on s.ID = sd.ARReserveInvoiceID
	WHERE YEAR(GETDATE()) <= YEAR(s.PostingDate) 
	GROUP BY sd.ID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - sd.TotalDisValue) ELSE (SD.TotalSys - sd.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.ID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID
END

----------------------------------------------------------------------[CashoutKsms] \31-August-2023----------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[CashoutKsms]
@Tran_From int, 
@Tran_To int,
@UserID int
AS 
BEGIN
 SELECT
	MAX(T0.ReceiptID) AS ReceiptID,
	MAX(I.ID) AS ItemID,
	MAX(T1.ID) AS ReceiptDID,
	MAX(T1.OrderDetailID) AS OrderDetailID,
	MAX(T0.UserOrderID) AS UserOrderID,
	MAX(T0.CustomerID) AS CustomerID,
	MAX(T0.ReceiptNo) AS InvoiceNo,
	MaX(T0.DateIn) AS DateIn,
	MaX(T0.DateOut) AS DateOut,
	MaX(T0.TimeIn) AS TimeIn,
	MaX(T0.TimeOut) AS TimeOut,
	MaX(T0.PLRate) AS PLRate,
	MAX(T2.[Name]) AS CustomerName,
	MAX(T1.KhmerName) AS KhmerName,
	MAX(T1.EnglishName) AS EnglishName,
	MAX(T9.Name) AS NameType,
	MAX(T3.AutoMID) AS AutoMID,
	MAX(T3.Plate) AS Plate,
	MAX(T0.DateOut) AS InvoiceDate,
	MAX(T1.Qty) AS Qty,
	Max(T1.UnitPrice) AS UnitPrice,
	Max(T1.Total_Sys) AS Total,
	MAx(T0.DiscountValue) AS DiscountValue,
	MAx(T1.DiscountValue) AS DiscountItem,
	MAx(T0.GrandTotal_Sys) AS GrandTotal_Sys,
	MAx(T0.GrandTotal) AS GrandTotal,
	Max(SaleC.Description) As CurrencyName,
	Max(SysC.Description) AS SysCurrencyName,
	Max(Sysc.ID) AS SysCurrencyID,
	Max(T0.ExchangeRate) AS ExchangeRate,
	Max(T0.LocalSetRate) AS LocalSetRate,
	MAx(T0.CurrencyDisplay) AS CurrencyDisplay
	from tbReceipt T0
	join tbReceiptDetail T1 ON T0.ReceiptID = T1.ReceiptID
	join tbItemMasterData I on T1.ItemID = I.ID
	join tbBusinessPartner T2 ON T0.CustomerID = T2.ID
	join tbCurrency SaleC ON T0.PLCurrencyID = SaleC.ID
	join tbCurrency SysC ON T0.SysCurrencyID = SysC.ID
	left join tbAutoMobile T3 ON T0.vehicleID = T3.AutoMID
	join tbSeries T8 ON T0.SeriesID = T8.ID
	join tbDocumentType T9 ON T8.DocuTypeID = T9.ID
	where T0.ReceiptID > @Tran_From AND T0.ReceiptID <= @Tran_To AND T0.UserOrderID=@UserID 
	GROUP BY T1.ID;
END

--------------------------------------------------------PropertyPurchaseDetails \31-August-2023------------------------------------------------------------------------------

-- Create Property  PurchaseDetail (Purchase Request)
		
		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Code' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Code', 'Item Code',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Barcode' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Barcode', 'Barcode',0,1)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='ItemName' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('ItemName', 'Description',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='VendorCode' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('VendorCode', 'Vendor Code',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='VendorName' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('VendorName', 'Vendor Name',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='RequiredDate' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('RequiredDate', 'Required Date',0,1)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Qty' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Qty', 'Required Qty',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='UoMSelect' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('UoMSelect', 'UoM',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='PurchasPrice' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('PurchasPrice', 'Info Price',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxGroupSelect' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxGroupSelect', 'Tax',0,1)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Warehouse' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Warehouse', 'Warehouse',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Foc' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Foc', 'Free Of Charge',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxRate' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxRate', 'Tax Rate',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxValue' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxValue', 'Tax Value',0,1)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxOfFinDisValue' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountRate' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountRate', 'Discount Rate',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountValue' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountValue', 'Discount Value',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisRate' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisRate', 'Final Discount Rate',0,1)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisValue' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisValue', 'Final Discount Value',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Total' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Total', 'Total After Discount',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TotalWTax' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TotalWTax', 'Total With Tax',0,1)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinTotalValue' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinTotalValue', 'Final Total Value',0,1)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Remark' AND [Type]=1)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Remark', 'Remark',0,1)

	-- End Property  PurchaseDetail (Purchase Request)

		-- Create Property  PurchaseDetail (Purchase Quotation)
		
		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Code' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Code', 'Item Code',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Barcode' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Barcode', 'Barcode',0,2)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='ItemName' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('ItemName', 'Description',0,2)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Qty' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Qty', 'Quantity',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='UoMSelect' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('UoMSelect', 'UoM',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='CurrencyName' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('CurrencyName', 'Currency',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='PurchasPrice' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('PurchasPrice', 'Unit Price',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxGroupSelect' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxGroupSelect', 'Tax',0,2)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Warehouse' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Warehouse', 'Warehouse',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Foc' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Foc', 'Free Of Charge',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxRate' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxRate', 'Tax Rate',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxValue' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxValue', 'Tax Value',0,2)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxOfFinDisValue' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountRate' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountRate', 'Discount Rate',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountValue' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountValue', 'Discount Value',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisRate' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisRate', 'Final Discount Rate',0,2)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisValue' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisValue', 'Final Discount Value',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Total' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Total', 'Total After Discount',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TotalWTax' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TotalWTax', 'Total With Tax',0,2)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinTotalValue' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinTotalValue', 'Final Total Value',0,2)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Remark' AND [Type]=2)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Remark', 'Remark',0,2)

	-- End Property  PurchaseDetail (Purchase Quotation)

			-- Create Property  PurchaseDetail (Purchase Order)
		
		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Code' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Code', 'Item Code',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Barcode' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Barcode', 'Barcode',0,3)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='ItemName' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('ItemName', 'Description',0,3)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Qty' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Qty', 'Quantity',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='UoMSelect' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('UoMSelect', 'UoM',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='CurrencyName' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('CurrencyName', 'Currency',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='PurchasPrice' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('PurchasPrice', 'Unit Price',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxGroupSelect' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxGroupSelect', 'Tax',0,3)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Warehouse' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Warehouse', 'Warehouse',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Foc' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Foc', 'Free Of Charge',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxRate' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxRate', 'Tax Rate',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxValue' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxValue', 'Tax Value',0,3)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxOfFinDisValue' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountRate' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountRate', 'Discount Rate',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountValue' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountValue', 'Discount Value',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisRate' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisRate', 'Final Discount Rate',0,3)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisValue' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisValue', 'Final Discount Value',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Total' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Total', 'Total After Discount',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TotalWTax' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TotalWTax', 'Total With Tax',0,3)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinTotalValue' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinTotalValue', 'Final Total Value',0,3)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Remark' AND [Type]=3)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Remark', 'Remark',0,3)

	-- End Property  PurchaseDetail (Purchase Order)

		-- Create Property  PurchaseDetail ((Good ReceiptPO)
		
		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Code' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Code', 'Item Code',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Barcode' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Barcode', 'Barcode',0,4)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='ItemName' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('ItemName', 'Description',0,4)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Qty' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Qty', 'Quantity',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='UoMSelect' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('UoMSelect', 'UoM',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='CurrencyName' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('CurrencyName', 'Currency',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='PurchasPrice' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('PurchasPrice', 'Unit Price',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxGroupSelect' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxGroupSelect', 'Tax',0,4)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Warehouse' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Warehouse', 'Warehouse',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Foc' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Foc', 'Free Of Charge',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxRate' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxRate', 'Tax Rate',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxValue' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxValue', 'Tax Value',0,4)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxOfFinDisValue' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountRate' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountRate', 'Discount Rate',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountValue' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountValue', 'Discount Value',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisRate' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisRate', 'Final Discount Rate',0,4)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisValue' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisValue', 'Final Discount Value',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Total' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Total', 'Total After Discount',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TotalWTax' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TotalWTax', 'Total With Tax',0,4)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinTotalValue' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinTotalValue', 'Final Total Value',0,4)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Remark' AND [Type]=4)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Remark', 'Remark',0,4)

	-- End Property  PurchaseDetail (Good ReceiptPO)

	-- Create Property  PurchaseDetail (A/P Reserve Invoice)
		
		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Code' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Code', 'Item Code',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Barcode' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Barcode', 'Barcode',0,5)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='ItemName' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('ItemName', 'Description',0,5)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Qty' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Qty', 'Quantity',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='UoMSelect' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('UoMSelect', 'UoM',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='CurrencyName' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('CurrencyName', 'Currency',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='PurchasPrice' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('PurchasPrice', 'Unit Price',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxGroupSelect' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxGroupSelect', 'Tax',0,5)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Warehouse' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Warehouse', 'Warehouse',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Foc' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Foc', 'Free Of Charge',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxRate' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxRate', 'Tax Rate',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxValue' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxValue', 'Tax Value',0,5)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxOfFinDisValue' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountRate' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountRate', 'Discount Rate',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountValue' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountValue', 'Discount Value',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisRate' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisRate', 'Final Discount Rate',0,5)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisValue' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisValue', 'Final Discount Value',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Total' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Total', 'Total After Discount',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TotalWTax' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TotalWTax', 'Total With Tax',0,5)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinTotalValue' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinTotalValue', 'Final Total Value',0,5)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Remark' AND [Type]=5)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Remark', 'Remark',0,5)

	-- End Property  PurchaseDetail (A/P Reserve Invoice)

	-- Create Property  PurchaseDetail (A/P Invoice)
		
		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Code' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Code', 'Item Code',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Barcode' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Barcode', 'Barcode',0,6)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='ItemName' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('ItemName', 'Description',0,6)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Qty' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Qty', 'Quantity',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='UoMSelect' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('UoMSelect', 'UoM',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='CurrencyName' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('CurrencyName', 'Currency',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='PurchasPrice' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('PurchasPrice', 'Unit Price',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxGroupSelect' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxGroupSelect', 'Tax',0,6)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Warehouse' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Warehouse', 'Warehouse',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Foc' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Foc', 'Free Of Charge',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxRate' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxRate', 'Tax Rate',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxValue' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxValue', 'Tax Value',0,6)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxOfFinDisValue' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountRate' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountRate', 'Discount Rate',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountValue' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountValue', 'Discount Value',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisRate' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisRate', 'Final Discount Rate',0,6)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisValue' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisValue', 'Final Discount Value',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Total' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Total', 'Total After Discount',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TotalWTax' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TotalWTax', 'Total With Tax',0,6)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinTotalValue' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinTotalValue', 'Final Total Value',0,6)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Remark' AND [Type]=6)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Remark', 'Remark',0,6)

	-- End Property  PurchaseDetail (A/P Invoice)

	-- Create Property  PurchaseDetail (A/P Credit Memo)
		
		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Code' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Code', 'Item Code',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Barcode' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Barcode', 'Barcode',0,7)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='ItemName' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('ItemName', 'Description',0,7)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Qty' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Qty', 'Quantity',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='UoMSelect' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('UoMSelect', 'UoM',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='CurrencyName' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('CurrencyName', 'Currency',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='PurchasPrice' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('PurchasPrice', 'Unit Price',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxGroupSelect' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxGroupSelect', 'Tax',0,7)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Warehouse' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Warehouse', 'Warehouse',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Foc' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Foc', 'Free Of Charge',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxRate' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxRate', 'Tax Rate',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxValue' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxValue', 'Tax Value',0,7)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TaxOfFinDisValue' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountRate' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountRate', 'Discount Rate',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='DiscountValue' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('DiscountValue', 'Discount Value',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisRate' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisRate', 'Final Discount Rate',0,7)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinDisValue' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinDisValue', 'Final Discount Value',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Total' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Total', 'Total After Discount',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='TotalWTax' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('TotalWTax', 'Total With Tax',0,7)

		IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='FinTotalValue' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('FinTotalValue', 'Final Total Value',0,7)

	    IF NOT EXISTS( SELECT [key] FROM PropertyPurchaseDetails Where [Key]='Remark' AND [Type]=7)
		    INSERT INTO PropertyPurchaseDetails([Key],Name, HideColumn, [Type])  VALUES ('Remark', 'Remark',0,7)

--------------------------------------------------------Sale Detail /31-August-2023------------------------------------------------------------------------------

 
		 -- Create Property Sale Detail (Sale Quote)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,1,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,1,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,1,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,1,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,1,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,1,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,1,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,1,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,1,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=1)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,1,0)
		
		 --End Create Property Sale Detail (Sale Quote)
		
		
		
		 -- Create Property Sale Detail (Sale Order)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,2,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,2,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,2,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,2,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,2,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,2,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,2,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,2,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,2,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=2)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,2,0)
		
		 --End Create Property Sale Detail (Sale Order)
		
		 -- Create Property Sale Detail (Sale Delivery)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,3,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,3,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,3,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,3,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,3,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,3,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,3,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,3,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,3,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,3,0)
		
		 --End Create Property Sale Detail (Sale Delivery)
		 
		 -- Create Property Sale Detail (Return Delivery)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,4,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,4,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,4,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,4,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,4,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,4,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,4,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,4,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,4,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=4)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,4,0)
		
		 --End Create Property Sale Detail (Return Delivery)
		
		
		 -- Create Property Sale Detail (A/R Down Payment)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,5,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,5,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,5,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,5,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxDownPaymentValue' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxDownPaymentValue', 'Tax Down Payment Value',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,5,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,5,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,5,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=3)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,5,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,5,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,5,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=5)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,5,0)
		
		 --End  Create Property Sale Detail (A/R Down Payment)
		
		  -- Create Property Sale Detail (A/R Invoice)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,6,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,6,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,6,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,6,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,6,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,6,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,6,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,6,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,6,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,6,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='LoanPartnerName' AND [Type]=6)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('LoanPartnerName', 'Loan Partner',0,6,0)
		
		 --End Create Property Sale Detail (A/R invoice)
		
		   -- Create Property Sale Detail  (A/R Editable)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,7,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,7,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,7,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,7,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,7,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,7,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,7,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,7,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,7,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=7)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,7,0)
		
		 --End Create Property Sale Detail (A/R Editable)
		
		  -- Create Property Sale Detail  (A/R Reserve Invoice)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,8,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,8,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,8,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,8,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,8,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,8,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,8,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,8,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,8,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=8)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,8,0)
		
		  -- END Property Sale Detail  (A/R Reserve Invoice)
		
		    -- Create Property Sale Detail  (A/R Reserve Editable)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,9,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,9,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,9,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,9,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,9,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,9,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,9,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,9,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,9,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=9)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,9,0)
		
		  -- END Property Sale Detail  (A/R Reserve Editable)
		
		    -- Create Property Sale Detail  (A/R Service Contract)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,10,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,10,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,10,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,10,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,10,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,10,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,10,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,10,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,10,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=10)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,10,0)
		
		  -- END Property Sale Detail  (A/R Service Contract)
		
		      -- Create Property Sale Detail  (A/R Credit memo)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemCode' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemCode', 'Item Code',0,11,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='BarCode' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('BarCode', 'BarCode',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='ItemNameKH' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('ItemNameKH', 'Description',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Qty' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Qty', 'Quantity',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UoMs' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UoMs', 'UoM',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Warehouse' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Warehouse', 'Warehouse',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Currency' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Currency', 'Currency',0,11,0)

			IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Cost' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Cost', 'Unit Cost',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='UnitPrice' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('UnitPrice', 'Unit Price',0,11,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TradeOffer' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TradeOffer', 'Trade Offer',0,11,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxGroupList' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxGroupList', 'Tax',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxRate' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxRate', 'Tax Rate',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxValue' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxValue', 'Tax Value',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TaxOfFinDisValue' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TaxOfFinDisValue', 'Tax Of Final Discount Value',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisRate' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisRate', 'Discount Rate',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='DisValue' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('DisValue', 'Discount Value',0,11,0)
			
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisRate' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisRate', 'Final Discount Rate',0,11,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinDisValue' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinDisValue', 'Final Discount Value',0,11,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Total' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Total', 'Total After Discount',0,11,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='TotalWTax' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('TotalWTax', 'Total With Tax',0,11,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='FinTotalValue' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('FinTotalValue', 'Final Total Value',0,11,0)
		
		IF NOT EXISTS( SELECT [key] FROM PropertySaleDetails Where [Key]='Remarks' AND [Type]=11)
		    INSERT INTO PropertySaleDetails([Key],Name, HideColumn, [Type],[Delete])  VALUES ('Remarks', 'Remarks',0,11,0)
		
		  -- END Property Sale Detail  (A/R Credit memo)

--------------------------------------------------------------[EmpCashoutKsms] \31-August-2023------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[EmpCashoutKsms]
AS 
BEGIN
 SELECT
	MAX(T0.ItemID) AS ItemID,
	MAX(T0.EmpID) AS EmpID,
	MAX(T3.Name) AS EmployeeName,
	MAX(T0.ReceiptDID) AS ReceiptID

	from EmpComsions T0
	join tbReceiptDetail T2 ON T0.ReceiptDID = T2.OrderDetailID
	join tbEmployee T3 ON T0.EmpID = T3.ID
	GROUP BY T0.ID;
END

-----------------------------------------------------------------[sp_GetItemSetPrice] 31-August-2023---------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[sp_GetItemSetPrice](
@PriceListID int=0,
@Group1 int=0,
@Group2 int=0,
@Group3 int=0,
@Inactive bit=0,
@Process nvarchar(max)='Add')
AS
BEGIN
    Declare @SysCurrency nvarchar(max)
	select @SysCurrency=cur.[Description] from tbCompany cop inner join tbPriceList pl on cop.PriceListID=pl.ID
	                                                       inner join tbCurrency cur on cur.ID=pl.CurrencyID 
	IF(@Process='Add')
		Begin
			IF @PriceListID!=0 and @Group1=0 
				Begin
					SELECT 
						  pld.ID,
						  item.Code,
						  item.KhmerName,
						  item.EnglishName,
						  uom.Name as Uom,
						  pld.Cost as Cost,
						  convert(float,0) as Makup,
						  pld.UnitPrice as Price,
						  cur.[Description] as Currency,
						  convert(float,pld.Discount) as Discount,
						  pld.TypeDis,
						  item.Process,
						  @SysCurrency as SysCurrency,
						  pld.Barcode as Barcode,
						  pld.InActive
					FROM tbPriceListDetail pld 
										   inner join tbItemMasterData item on pld.ItemID=item.ID
										   inner join tbCurrency cur on pld.CurrencyID=cur.ID
										   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
										   where item.[Delete]=0 and pld.PriceListID=@PriceListID and pld.UnitPrice=0 and pld.InActive=@Inactive
										   order by pld.ItemID
				End
			ELSE IF @PriceListID!=0 and @Group1!=0 
				Begin 
					SELECT 
						 pld.ID,
						  item.Code,
						  item.KhmerName,
						  item.EnglishName,
						  uom.Name as Uom,
						  pld.Cost as Cost,
						  convert(float,0) as Makup,
						  pld.UnitPrice as Price,
						  cur.[Description] as Currency,
						  convert(float,pld.Discount) as Discount,
						  pld.TypeDis,
						  item.Process,
						  @SysCurrency as SysCurrency,
						   pld.Barcode as Barcode,
						    pld.InActive
					FROM tbPriceListDetail pld 
										   inner join tbItemMasterData item on pld.ItemID=item.ID
										   inner join tbCurrency cur on pld.CurrencyID=cur.ID
										   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
										   where item.[Delete]=0 and pld.PriceListID=@PriceListID and item.ItemGroup1ID=@Group1 and pld.UnitPrice=0 and pld.InActive=@Inactive
										   order by pld.ItemID
				End
		
		
		End
	Else
		Begin
			IF @PriceListID!=0 and @Group1=0
				Begin
					SELECT 
						  pld.ID,
						  item.Code,
						  item.KhmerName,
						  item.EnglishName,
						  uom.Name as Uom,
						  pld.Cost as Cost,
						  convert(float,0) as Makup,
						  pld.UnitPrice as Price,
						  cur.[Description] as Currency,
						  convert(float,pld.Discount) as Discount,
						  pld.TypeDis,
						  item.Process,
						  @SysCurrency as SysCurrency,
						  pld.Barcode as Barcode,
						  pld.InActive
					FROM tbPriceListDetail pld 
										   inner join tbItemMasterData item on pld.ItemID=item.ID
										   inner join tbCurrency cur on pld.CurrencyID=cur.ID
										   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
										   where item.[Delete]=0 and pld.PriceListID=@PriceListID and pld.UnitPrice>0 and pld.InActive=@Inactive
										   order by pld.ItemID
				End
			ELSE IF @PriceListID!=0 and @Group1!=0
					Begin 
						SELECT 
							 pld.ID,
							  item.Code,
							  item.KhmerName,
							  item.EnglishName,
							  uom.Name as Uom,
							  pld.Cost as Cost,
							  convert(float,0) as Makup,
							  pld.UnitPrice as Price,
							  cur.[Description] as Currency,
							  convert(float,pld.Discount) as Discount,
							  pld.TypeDis,
							  item.Process,
							  @SysCurrency as SysCurrency,
							   pld.Barcode as Barcode,
							   pld.InActive
						FROM tbPriceListDetail pld 
											   inner join tbItemMasterData item on pld.ItemID=item.ID
											   inner join tbCurrency cur on pld.CurrencyID=cur.ID
											   inner join tbUnitofMeasure uom on pld.UomID=uom.ID
											   where item.[Delete]=0 and pld.PriceListID=@PriceListID and item.ItemGroup1ID=@Group1 and pld.UnitPrice>0 and pld.InActive=@Inactive
											   order by pld.ItemID
					End
				
		End
END














------------------------------------------------------------------[uspGetPropertyItemMasterData] 31-August-2023--------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetPropertyItemMasterData]
AS 
BEGIN
      SELECT *FROM PropertyItemMasterDatas 	
END

----------------------------------------------------------------------[uspGetPropertyPurchaseDetailByType] 31-August-2023----------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetPropertyPurchaseDetailByType](@type int=0)
AS 
BEGIN
		SELECT *FROM PropertyPurchaseDetails WHERE Type=@type
END

-----------------------------------------------------------------[uspGetPropertySaleDetailByType] 31-August-2023---------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetPropertySaleDetailByType](@type int=0)
AS 
BEGIN
		SELECT *FROM PropertySaleDetails WHERE Type=@type and [Delete]=0
END

------------------------------------------------------------------PropertyItemMasterDatas- 31-August-2023-------------------------------------------------------------------

 -- Create Property ItemMaster Data 
		
		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='No' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('No', 'No',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='Code' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('Code', 'Code',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='KhmerName' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('KhmerName', 'Item Name 1',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='EnglishName' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('EnglishName', 'Item Name 2',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='UomName' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('UomName', 'UoM',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='ItemGroupName' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('ItemGroupName', 'Item Group 1',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='Barcode' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('Barcode', 'Barcode',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='Process' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('Process', 'Type',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='Stock' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('Stock', 'Stock',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='Image' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('Image', 'Image',0)

		IF NOT EXISTS( SELECT [Key] FROM PropertyItemMasterDatas Where [Key]='Action' )
		    INSERT INTO PropertyItemMasterDatas([Key],Name, HideColumn)  VALUES ('Action', 'Action',0)
		

-----------------------------------------------------------------ufnGetItemsWithTaxAndRevenue 31-August-2023---------------------------------------------------------------------

GO
CREATE OR ALTER FUNCTION ufnGetItemsWithTaxAndRevenue()
RETURNS TABLE AS RETURN(
	WITH r_cte AS (
		SELECT 
			R.ReceiptID,
			R.DiscountRate + R.BuyXAmGetXDisRate + R.PromoCodeDiscRate + R.CardMemberDiscountRate AS TotalDisRate,
			R.TaxOption
		FROM tbReceipt R
	),
	rd_cte AS (
		SELECT 
			MAX(RD.ReceiptID) AS ReceiptID,
			MAX(RD.ID) AS [ReceiptDetailID],
			MAX(RD.DiscountValue) AS DisValLine,
			MAX(R.TotalDisRate) AS TotalDisRate,
			MAX(R.TaxOption) AS TaxOption,
			MAX(RD.TaxRate) AS TaxRate,	
			MAX(RD.Qty * RD.UnitPrice) AS [TotalBeforeDiscount],
			MAX(RD.Qty * RD.UnitPrice * (1 - RD.DiscountRate / 100)) AS [TotalAfterDiscountLine],
			MAX(RD.Qty * RD.UnitPrice * (1 - RD.DiscountRate / 100) * (1 - R.TotalDisRate / 100)) AS TotalAfterDiscountSum
		FROM tbReceiptDetail RD
		INNER JOIN r_cte R ON R.ReceiptID = RD.ReceiptID
		GROUP BY RD.ID
	),
	rd_tax_cte AS (
		SELECT 
			RD.ReceiptDetailID,
			RD.TotalAfterDiscountLine * RD.TotalDisRate / 100 AS [DisValDoc],
			RD.DisValLine + RD.TotalAfterDiscountLine * RD.TotalDisRate / 100 AS [DisValSum],
			CASE WHEN RD.TaxOption = 0 THEN 0
				WHEN RD.TaxOption = 1 THEN RD.TotalAfterDiscountSum * RD.TaxRate / 100
				WHEN RD.TaxOption = 2 THEN RD.TotalAfterDiscountSum * RD.TaxRate / (100 + RD.TaxRate)
			END AS [TaxValue]
		FROM rd_cte RD
	),
	rd_final_cte AS (
		SELECT
			RD.*,
			RDT.[DisValDoc],
			RDT.[DisValSum],
			RDT.[TaxValue],
			CASE WHEN RD.TaxOption = 0 OR RD.TaxOption = 1 THEN RD.TotalAfterDiscountSum
				ELSE RD.TotalAfterDiscountSum - RDT.TaxValue END 
			AS [Revenue],
			CASE WHEN RD.TaxOption = 0 OR RD.TaxOption = 2 THEN RD.TotalAfterDiscountSum
				ELSE RD.TotalAfterDiscountSum + RDT.TaxValue END 
			AS [TotalAfterTax]
		FROM rd_cte RD
		INNER JOIN rd_tax_cte RDT ON RD.ReceiptDetailID = RDT.ReceiptDetailID
	)
	SELECT * FROM rd_final_cte
);

GO 
--Remodify tax rate from invoice and transfer it to become a tax rate by line. (TaxOptions: 3 called 'InvoiceVAT' is depricated).
UPDATE RD 
SET RD.TaxRate = R.TaxRate
FROM tbReceiptDetail RD 
INNER JOIN tbReceipt R ON RD.ReceiptID = R.ReceiptID AND RD.TaxRate <= 0

GO
UPDATE tbReceipt SET 
TaxOption = 1,
TaxRate = 0
WHERE TaxOption = 3 OR TaxRate > 0

GO
--Update existing empty added fields.
UPDATE RD 
SET
	RD.DisValDoc = TRD.DisValDoc,
	RD.DisValSum = TRD.DisValSum,
	RD.TotalBeforeDiscount = TRD.TotalBeforeDiscount,
	RD.TotalAfterDiscountLine = TRD.TotalAfterDiscountLine,
	RD.TotalAfterDiscountSum = TRD.TotalAfterDiscountSum,
	RD.Revenue = TRD.Revenue,
	RD.TotalAfterTax = TRD.TotalAfterTax
FROM tbReceiptDetail RD
INNER JOIN ufnGetItemsWithTaxAndRevenue() TRD
ON RD.ID = TRD.ReceiptDetailID
WHERE RD.Revenue = 0

GO
;WITH r_cte AS (
	SELECT
	MAX(TRD.ReceiptID) AS ReceiptID,
	SUM(TRD.[TotalBeforeDiscount]) AS [TotalBeforeDiscount],
	SUM(TRD.TotalAfterDiscountSum) AS TotalAfterDiscount,
	SUM(TRD.Revenue) AS TotalRevenue,
	SUM(TRD.TotalAfterTax) AS TotalAfterTax,
	SUM(TRD.TaxValue) AS TotalTaxValue
	FROM ufnGetItemsWithTaxAndRevenue() TRD
	GROUP BY TRD.ReceiptID
)
UPDATE R
SET
	R.TotalBeforeDiscount = TR.TotalBeforeDiscount,
	R.TotalAfterDiscount = TR.TotalAfterDiscount,
	R.TotalRevenue = TR.TotalRevenue,
	R.TotalAfterTax = TR.TotalAfterTax,
	R.TaxValue = TR.TotalTaxValue
FROM tbReceipt R
INNER JOIN r_cte TR
ON R.ReceiptID = TR.ReceiptID
WHERE R.TotalRevenue = 0


----------------------------------------------------------------------[rp_uspGetPurchasAPCashout] 31-August-2023----------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[rp_uspGetPurchasAPCashout]
@OpenShiftID int,
@UserID int
AS 
BEGIN
 SELECT
	MAX(T1.PurchaseAPID) AS PurchaseID,
	MAX(I.ID) AS ItemID,
	MAX(T1.UserID) AS UserID,
	MAX(T1.InvoiceNo) AS InvoiceNo,
	MAX(T1.PostingDate) AS PostingDate,
	MAX(T1.DocumentDate) AS DocumentDate,
	MAX(I.KhmerName) AS KhmerName,
	MAX(I.EnglishName) AS EnglishName,
	MAX(T1.PurRate) AS ExchangeRate,
	MAX(T1.LocalSetRate) AS LocalSetRate,
	MAX(T1.SubTotalSys) AS SubTotalSys,
	MAX(T1.SubTotalAfterDis) AS SubTotalAfterDis,
	MAX(T1.SubTotalAfterDisSys) AS SubTotalAfterDisSys,
	Max(SaleC.Description) As CurrencyName,
	Max(SysC.Description) AS SysCurrencyName,
	MAX(T0.ShiftID) AS OpenShiftID

	from ShiftPurhcese T0
	join tbPurchase_AP T1 ON T0.PurchaseID = T1.PurchaseAPID
	join tbPurchaseAPDetail T2 ON T1.PurchaseAPID = T2.PurchaseAPID
	join tbItemMasterData I on T2.ItemID = I.ID
	join tbBusinessPartner T3 ON T1.VendorID = T3.ID
	join tbCurrency SaleC ON T1.PurCurrencyID = SaleC.ID
	join tbCurrency SysC ON T1.LocalCurID = SysC.ID
	Where T0.ShiftID = @OpenShiftID AND T1.UserID = @UserID
	GROUP BY T0.ID;
END

--------------------------------------------------------------[rp_GetSummarySaleAdminTotal] 31-August-2023------------------------------------------------------------------------
GO
CREATE OR ALTER PROCEDURE [dbo].[rp_GetSummarySaleAdminTotal](@DateFrom date='1900-01-01',@DateTo date='1900-01-01',@BranchID int=0 ,@UserID int=0,@CusID int=0,@Type nvarchar(max))
as
begin
 declare @Count float=0
 declare @SoldAmount float=0
 declare @Amount float=0
 declare @DisItem float=0
 declare @DisTotal float=0
 declare @TotalVat float=0
 declare @GrandTotal float=0
 declare @GrandTotalSys float=0
 IF @Type = 'SQ'
  Begin 
    IF @DateFrom !='1900-01-01' and @DateTo !='1900-01-01' and @BranchID=0 and @UserID=0 and @CusID=0
	  Begin 
	   --detail
	   select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleQuote s inner join tbSaleQuoteDetail sd on s.SQID=sd.SQID
	   Where s.PostingDate >= @DateFrom and s.PostingDate<=@DateTo
	   --Summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleQuote s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo
	   End
	Else if @DateFrom !='1900-01-01' and @DateTo != '1900-01-01' and @BranchID !=0 and @UserID=0 and @CusID=0
	 Begin
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleQuote s inner join tbSaleQuoteDetail sd on s.SQID=sd.SQID
	   where s.PostingDate>=@DateFrom and s.PostingDate<=@DateTo and s.BranchID=@BranchID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleQuote s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID =0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleQuote s inner join tbSaleQuoteDetail sd on s.SQID =sd.SQID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo  and s.BranchID=@BranchID and s.UserID = @UserID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleQuote s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID = @UserID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleQuote s inner join tbSaleQuoteDetail sd on s.SQID =sd.SQID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleQuote s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleQuote s inner join tbSaleQuoteDetail sd on s.SQID =sd.SQID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleQuote s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleQuote s inner join tbSaleQuoteDetail sd on s.SQID =sd.SQID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleQuote s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   End
	  Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID !=0 and @CusID !=0
	  Begin 
	  --detail
	   select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleQuote s inner join tbSaleQuoteDetail sd on s.SQID =sd.SQID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	  select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleQuote s  
	  where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   End
	 End
  ELSE IF @Type ='SO'
    Begin
	IF @DateFrom !='1900-01-01' and @DateTo !='1900-01-01' and @BranchID =0 and @UserID=0 and @CusID=0
	  Begin 
	   --detail
	   select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleOrder s inner join tbSaleOrderDetail sd on s.SOID=sd.SOID
	   Where s.PostingDate >=@DateFrom and s.PostingDate<=@DateTo
	   --Summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleOrder s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo
	   End
	Else if @DateFrom !='1900-01-01' and @DateTo != '1900-01-01' and @BranchID !=0 and @UserID=0 and @CusID=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleOrder s inner join tbSaleOrderDetail sd on  s.SOID=sd.SOID
	   where s.PostingDate>=@DateFrom and s.PostingDate<=@DateTo and s.BranchID=@BranchID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleOrder s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID =0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	    from tbSaleOrder s inner join tbSaleOrderDetail sd on  s.SOID=sd.SOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleOrder s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	    from tbSaleOrder s inner join tbSaleOrderDetail sd on  s.SOID=sd.SOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleOrder s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleOrder s inner join tbSaleOrderDetail sd on  s.SOID=sd.SOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleOrder s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleOrder s inner join tbSaleOrderDetail sd on  s.SOID=sd.SOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleOrder s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from tbSaleOrder s inner join tbSaleOrderDetail sd on  s.SOID=sd.SOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleOrder s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   End
	End
 ELSE IF @Type ='SD'
   Begin
    IF @DateFrom !='1900-01-01' and @DateTo !='1900-01-01' and @BranchID =0 and @UserID=0 and @CusID=0
	  Begin 
	   --detail
	   select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleDelivery s inner join tbSaleDeliveryDetail sd on s.SDID=sd.SDID
	   Where s.PostingDate >=@DateFrom and s.PostingDate<=@DateTo
	   --Summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleDelivery s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo
	   End
	Else if @DateFrom !='1900-01-01' and @DateTo != '1900-01-01' and @BranchID !=0 and @UserID=0 and @CusID=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from tbSaleDelivery s inner join tbSaleDeliveryDetail sd on s.SDID=sd.SDID
	   where s.PostingDate>=@DateFrom and s.PostingDate<=@DateTo and s.BranchID=@BranchID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID =0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	    from tbSaleDelivery s inner join tbSaleDeliveryDetail sd on s.SDID=sd.SDID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	     from tbSaleDelivery s inner join tbSaleDeliveryDetail sd on s.SDID=sd.SDID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from tbSaleDelivery s inner join tbSaleDeliveryDetail sd on s.SDID=sd.SDID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from tbSaleDelivery s inner join tbSaleDeliveryDetail sd on s.SDID=sd.SDID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleDelivery s inner join tbSaleDeliveryDetail sd on s.SDID=sd.SDID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   End
	  End
ELSE IF @Type ='RD'
	Begin
	 IF @DateFrom !='1900-01-01' and @DateTo !='1900-01-01' and @BranchID =0 and @UserID=0 and @CusID=0
	  Begin 
	   --detail
	   select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from ReturnDelivery s inner join ReturnDeliveryDetail sd on s.ID=sd.ReturnDeliveryID
	   Where s.PostingDate >=@DateFrom and s.PostingDate<=@DateTo
	   --Summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from ReturnDelivery s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo
	   End
	Else if @DateFrom !='1900-01-01' and @DateTo != '1900-01-01' and @BranchID !=0 and @UserID=0 and @CusID=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from ReturnDelivery s inner join ReturnDeliveryDetail sd on s.ID=sd.ReturnDeliveryID
	   where s.PostingDate>=@DateFrom and s.PostingDate<=@DateTo and s.BranchID=@BranchID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from ReturnDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID =0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	    from ReturnDelivery s inner join ReturnDeliveryDetail sd on s.ID=sd.ReturnDeliveryID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from ReturnDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	     from ReturnDelivery s inner join ReturnDeliveryDetail sd on s.ID=sd.ReturnDeliveryID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from ReturnDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from ReturnDelivery s inner join ReturnDeliveryDetail sd on s.ID=sd.ReturnDeliveryID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from ReturnDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from ReturnDelivery s inner join ReturnDeliveryDetail sd on s.ID=sd.ReturnDeliveryID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from ReturnDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from ReturnDelivery s inner join ReturnDeliveryDetail sd on s.ID=sd.ReturnDeliveryID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from ReturnDelivery s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   End
	End
 ELSE IF @Type = 'SAR'
  Begin
  IF @DateFrom !='1900-01-01' and @DateTo !='1900-01-01' and @BranchID =0 and @UserID=0 and @CusID=0
	  Begin 
	   --detail
	   select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from tbSaleAR s inner join tbSaleARDetail sd on s.SARID=sd.SARID
	   Where s.PostingDate >=@DateFrom and s.PostingDate<=@DateTo
	   --Summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleAR s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo
	   End
	Else if @DateFrom !='1900-01-01' and @DateTo != '1900-01-01' and @BranchID !=0 and @UserID=0 and @CusID=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from tbSaleAR s inner join tbSaleARDetail sd on s.SARID=sd.SARID
	   where s.PostingDate>=@DateFrom and s.PostingDate<=@DateTo and s.BranchID=@BranchID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleAR s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID =0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from tbSaleAR s inner join tbSaleARDetail sd on s.SARID=sd.SARID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleAR s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from tbSaleAR s inner join tbSaleARDetail sd on s.SARID=sd.SARID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleAR s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from tbSaleAR s inner join tbSaleARDetail sd on s.SARID=sd.SARID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleAR s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	 from tbSaleAR s inner join tbSaleARDetail sd on s.SARID=sd.SARID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo  and s.BranchID=@BranchID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleAR s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from tbSaleAR s inner join tbSaleARDetail sd on s.SARID=sd.SARID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from tbSaleAR s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   End
	 End
 ELSE IF @Type ='SC'
  Begin
   IF @DateFrom !='1900-01-01' and @DateTo !='1900-01-01' and @BranchID =0 and @UserID=0 and @CusID=0
	  Begin 
	   --detail
	   select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from SaleCreditMemos s inner join tbSaleCreditMemoDetail sd on s.SCMOID=sd.SCMOID
	   Where s.PostingDate >=@DateFrom and s.PostingDate<=@DateTo
	   --Summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * s.ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from SaleCreditMemos s  
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo
	   End
	Else if @DateFrom !='1900-01-01' and @DateTo != '1900-01-01' and @BranchID !=0 and @UserID=0 and @CusID=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from SaleCreditMemos s inner join tbSaleCreditMemoDetail sd on s.SCMOID=sd.SCMOID
	   where s.PostingDate>=@DateFrom and s.PostingDate<=@DateTo and s.BranchID=@BranchID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from SaleCreditMemos s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID =0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from  SaleCreditMemos s inner join tbSaleCreditMemoDetail sd on s.SCMOID=sd.SCMOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from SaleCreditMemos s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID
	   End
    Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from SaleCreditMemos s inner join tbSaleCreditMemoDetail sd on s.SCMOID=sd.SCMOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from SaleCreditMemos s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.UserID=@UserID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	   from SaleCreditMemos s inner join tbSaleCreditMemoDetail sd on s.SCMOID=sd.SCMOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from SaleCreditMemos s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID !=0 and @UserID =0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from SaleCreditMemos s inner join tbSaleCreditMemoDetail sd on s.SCMOID=sd.SCMOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from SaleCreditMemos s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.BranchID=@BranchID and s.CusID=@CusID
	   End
	Else if @DateFrom!='1900-01-01' and @DateTo!='1900-01-01' and @BranchID =0 and @UserID !=0 and @CusID !=0
	 Begin 
	  --detail
	  select @DisItem=sum(sd.DisValue * s.ExchangeRate), @SoldAmount=sum(sd.Qty * UnitPrice) 
	  from SaleCreditMemos s inner join tbSaleCreditMemoDetail sd on s.SCMOID=sd.SCMOID
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	  
	   --summary
	   select @Count=count(*), @DisTotal =sum(DisValue * ExchangeRate),@TotalVat=sum(s.VatValue * ExchangeRate),@GrandTotal=sum(s.TotalAmountSys * s.LocalSetRate),@GrandTotalSys=sum(s.TotalAmountSys) from SaleCreditMemos s
	   where s.PostingDate >=@DateFrom and s.PostingDate <=@DateTo and s.UserID=@UserID and s.CusID=@CusID
	   End

	   End
--Return data
 SELECT 
    1 as ID,
	@Count as CountInvoice,
	@SoldAmount as SoldAmount,
	@Amount as AppliedAmount,
	@DisItem as DisCountItem,
	@DisTotal as DisCountTotal,
	@TotalVat as TotalVatRate,
	@GrandTotal as Total,
	@GrandTotalSys as TotalSys

end

----------------------------------------------------------[rp_uspGetCashoutJournalExpense] \31-August-2023----------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[rp_uspGetCashoutJournalExpense]
@OpenShiftID int,
@UserID int
AS 
BEGIN

	DECLARE @glCode nvarchar(MAX);
	SET @glCode = '6'; --GL Account Type 'Expense'
 SELECT
  MAX(T0.ID) AS JEDID,
  MAX(T0.JEID) AS JEID,	
  MAX(T2.Creator) AS UserID,
  MAX(I.ID) AS ItemID,
  MAX(I.Name) AS KhmerName,
  MAX(T0.Remarks) AS Remarks,
  MAX(T0.Debit) AS SubTotalSys,
  Max(SaleC.Description) As CurrencyName,
  Max(SysC.Description) AS SysCurrencyName,
  Max(T2.LocalSetRate) AS LocalSetRate,
  MAX(T1.ShiftID) AS OpenShiftID
  from tbJournalEntryDetail T0 
  join OpenShifJournal T1 ON T1.JEID = T0.JEID
  join tbJournalEntry T2 ON T2.ID = T0.JEID
  join tbGLAccount I on T0.ItemID = I.ID 
  join tbCurrency SaleC ON T2.SSCID = SaleC.ID
  join tbCurrency SysC ON T2.LLCID = SysC.ID
  Where T1.ShiftID = @OpenShiftID AND T2.Creator = @UserID AND I.Code like N''+ @glCode + '%'
 GROUP BY T0.ID;
END
------------------------------------------------------------------tbDental-\31-August-2023-------------------------------------------------------------------

IF NOT EXISTS( SELECT Code FROM tbDental Where Code='1001' )
BEGIN
	INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('1001','11', 0) 
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='1002' )
BEGIN
	INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('1002','12', 0) 
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='1003' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('1003','13', 0)  
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='1004' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('1004','14', 0)  
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='1005' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('1005','15', 0)   
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='1006' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('1006','16', 0)   
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='1007' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('1007','17', 0)  
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='1008' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('1008','18', 0)    
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='1009' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('1009','21', 0)     
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10010' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10010','22', 0)   
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10011' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10011','23', 0)    
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10012' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10012','24', 0)
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10013' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10013','25', 0)    
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10014' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10014','26', 0)    
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10015' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10015','27', 0)   
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10016' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10016','28', 0)   
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10017' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10017','31', 1)  
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10018' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10018','32', 1)  
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10019' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10019','33', 1)   
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10020' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10020','34', 1)
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10021' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10021','35', 1)  
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10022' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10022','36', 1)   
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10023' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10023','37', 1)    
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10024' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10024','38', 1)    
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10025' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10025','41', 1) 
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10026' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10026','42', 1)   
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10027' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10027','43', 1)  
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10028' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10028','44', 1)  
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10029' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10029','45', 1) 
END
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10030' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10030','46', 1) 
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10031' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10031','47', 1)
END 
IF NOT EXISTS( SELECT Code FROM tbDental Where Code='10032' )
BEGIN	 
INSERT INTO tbDental
		(Code, Name, [Type])
	VALUES ('10032','48', 1) 
END 
------------------------------------------------------------[uspUpdateAvgCostWarehouseDetail] \31-August-2023--------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[uspUpdateAvgCostWarehouseDetail](@seriesDID int)
AS BEGIN
	;WITH IM_CTE AS (
		SELECT DISTINCT
			IA.ItemID ItemID,
			IA.Process
		FROM tbInventoryAudit IA 
		WHERE UPPER(IA.Process) = 'AVERAGE' AND IA.SeriesDetailID = @seriesDID
	),
	IA_CTE AS (
		SELECT 
			MAX(IA.ItemID) AS ItemID,
			MAX(IA.Qty) Qty,
			MAX(IA.Trans_Valuse) AS TransValue,
			SUM(IA.Trans_Valuse) / SUM(IA.Qty) AS AvgCost
		FROM tbInventoryAudit IA 
		WHERE IA.ItemID IN(SELECT ItemID FROM IM_CTE)
		GROUP BY IA.ItemID
	)
	UPDATE WD SET WD.AvgCost = TIA.AvgCost FROM IA_CTE TIA
	INNER JOIN tbWarehouseDetail WD ON WD.ItemID = TIA.ItemID
END

--------------------------------------------------------------01-User Defined Types------------------------------------------------------------------------
GO
IF EXISTS (SELECT *
          FROM   sys.objects
          WHERE  object_id = OBJECT_ID(N'[dbo].[pos_uspAddStockout]'))
DROP PROCEDURE [dbo].[pos_uspAddStockout]
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

IF TYPE_ID(N'[dbo].[SeriesDetailMap]') IS NOT NULL
DROP TYPE [dbo].[SeriesDetailMap]
CREATE TYPE [dbo].[SeriesDetailMap] AS TABLE(
	[SeriesDID] [int] NULL,
	[SeriesID] [int] NULL,
	[NextNo] [nvarchar](max) NULL
)
GO

/****** Object:  UserDefinedTableType [dbo].[StockOutMap]    Script Date: 8/12/2023 1:02:59 PM ******/
IF EXISTS (SELECT *
          FROM   sys.objects
          WHERE  object_id = OBJECT_ID(N'[dbo].[pos_uspAddStockout]'))
DROP PROCEDURE [dbo].[pos_uspAddStockout]
IF TYPE_ID(N'[dbo].[StockOutMap]') IS NOT NULL
DROP TYPE [dbo].[StockOutMap]
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

IF EXISTS (SELECT *
FROM   sys.objects
WHERE  object_id = OBJECT_ID(N'[dbo].[pos_uspAddJournalAccountBalance]'))
DROP PROCEDURE [dbo].[pos_uspAddJournalAccountBalance]
IF TYPE_ID(N'[dbo].[JournalMap]') IS NOT NULL
DROP TYPE [dbo].[JournalMap]

CREATE TYPE [dbo].[JournalMap] AS TABLE(
	[ReceiptID] [int] NOT NULL,
	[BPAcctID] [int] NOT NULL,
	[GLAcctID] [int] NOT NULL,
	[Debit] [decimal](24, 6) NOT NULL,
	[Credit] [decimal](24, 6) NOT NULL
)
GO
--------------------------------------------------------------------- pos_ufnGetReceiptItemsWithBoM 02-IssueStock-----------------------------------------------------------------

IF EXISTS (SELECT *
           FROM   sys.objects
           WHERE  object_id = OBJECT_ID(N'[dbo].[pos_ufnGetItemQtyWithBoM]')
                  AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
  DROP FUNCTION [dbo].[pos_ufnGetItemQtyWithBoM]
GO 
CREATE OR ALTER   FUNCTION [dbo].[pos_ufnGetReceiptItemsWithBoM](@receiptId int)
RETURNS TABLE AS RETURN(
	WITH RD_CTE AS (
		SELECT			
			R.SeriesDID AS [SeriesDetailID],
			RD.ReceiptID AS [ReceiptID], 
			R.WarehouseID AS [WarehouseID],
			RD.LineID AS [LineID],
			RD.ItemID AS [ItemID],
			RD.UomID AS [UomID],
			0 AS [NegativeStock],
			RD.Qty AS [BaseQty]
		FROM tbReceipt R
		INNER JOIN tbReceiptDetail RD ON R.ReceiptID = RD.ReceiptID
		WHERE R.ReceiptID = @receiptId
	),
	BM_CTE AS (
		SELECT * FROM RD_CTE
		UNION ALL
		SELECT	
			IRD.SeriesDetailID AS [SeriesDetailID],
			IRD.ReceiptID AS ReceiptID,
			IRD.WarehouseID AS WarehouseID,
			'' AS [LineID],
			BMD.ItemID AS ItemID,
			BMD.UomID AS UomID,
			CONVERT(bit, 1 * BMD.NegativeStock) AS [NegativeStock],
			BMD.Qty * IRD.BaseQty AS BaseQty
		FROM RD_CTE IRD
		LEFT JOIN tbBOMaterial BM ON BM.ItemID = IRD.ItemID
		INNER JOIN tbBOMDetail BMD ON BM.BID = BMD.BID 
		WHERE BM.[Active] = 1
	)
	SELECT		
			MAX(BMD.SeriesDetailID) AS [SeriesDetailID],
			MAX(BMD.ReceiptID) AS [ReceiptID],
			MAX(BMD.WarehouseID) AS [WarehouseID],
			MAX(BMD.LineID) AS [LineID],
			MAX(BMD.ItemID) AS [ItemID],
			MAX(IM.InventoryUoMID) AS [InventoryUomID],
			MAX(BMD.UomID) AS [UomID],
			MAX(GDU.GroupUoMID) AS [GroupUomID],
			CONVERT(bit, MAX(1 * BMD.NegativeStock)) AS [IsAllowedNegativeStock],
			MAX(GDU.Factor) AS [Factor],
			SUM(BMD.BaseQty) AS [BaseQty],
			SUM(BMD.BaseQty * GDU.Factor) AS [Qty],
			MAX(IM.[Process]) AS [Process]
	FROM BM_CTE BMD
	INNER JOIN tbItemMasterData IM ON IM.ID = BMD.ItemID 
	INNER JOIN tbGroupDefindUoM GDU ON BMD.UomID = GDU.AltUOM AND IM.GroupUomID = GDU.GroupUoMID
	GROUP BY BMD.ReceiptID, BMD.ItemID
)


--------------------------------------------------------------------[pos_ufnGetWarehouseDetailMap] 02-IssueStock------------------------------------------------------------------

GO
CREATE OR ALTER FUNCTION [dbo].[pos_ufnGetWarehouseDetailMap](
	@receiptId int,
	@warehouseId int
)
RETURNS TABLE AS 
RETURN (
	WITH
	IM_NO_SB_CTE AS (
		SELECT * FROM pos_ufnGetReceiptItemsWithBoM(@receiptId) WHERE UPPER(Process) NOT IN('SERIAL', 'BATCH')
	),
	CTE
	AS (
		SELECT
			MAX(ISNULL(WD.ID, 0)) AS ID,
			MAX(TIM.ReceiptID) AS ReceiptID,
			MAX(TIM.WarehouseID) AS WarehouseID,
			MAX(TIM.LineID) AS [LineID],
			MAX(TIM.ItemID) AS ItemID,
			MAX(TIM.InventoryUomID) AS [InventoryUomID],
			MAX(TIM.UomID) AS UomID,
			MAX(TIM.GroupUomID) AS GroupUomID,
			Layer = ROW_NUMBER() OVER(ORDER BY WD.ID),
			MAX(TIM.Process) AS [Process],
			MAX(ISNULL(WD.Cost, 0)) AS Cost,
			MAX(ISNULL(WD.AvgCost, 0)) AS AvgCost,
			MAX(ISNULL(RD.Cost, 0)) AS StdCost,
			MAX(ISNULL(WD.InStock, 0)) AS BaseStock,
			MAX(TIM.Qty) AS ItemQty
		FROM IM_NO_SB_CTE TIM
		LEFT JOIN tbWarehouseDetail WD ON WD.ItemID = TIM.ItemID AND WD.WarehouseID = TIM.WarehouseID AND WD.InStock > 0
		LEFT JOIN tbReceiptDetail RD ON RD.ItemID = TIM.ItemID AND RD.ReceiptID = TIM.ReceiptID
		GROUP BY TIM.ItemID, WD.Cost, WD.ID
	),
	CTE1 AS (
		SELECT
			CT.*,
			TotalBaseStock = (SELECT SUM(CC.BaseStock) from CTE CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID)
		FROM CTE CT
	),
	CTE2 AS (
		SELECT 
			C2.*,
			C2.TotalBaseStock - C2.ItemQty AS RemainQty,
			CASE WHEN UPPER(C2.Process) = 'STANDARD' THEN C2.ItemQty ELSE 
				CASE WHEN C2.TotalBaseStock - C2.ItemQty < 0 THEN C2.BaseStock 
				ELSE C2.BaseStock - ABS(C2.TotalBaseStock - C2.ItemQty) END
			END AS OutStock,
		CASE WHEN C2.TotalBaseStock < C2.ItemQty THEN 0 ELSE C2.TotalBaseStock - C2.ItemQty END AS InStock
		FROM CTE1 C2
	),
	CTE3 AS (
		SELECT C2.*,
		(SELECT SUM(CC2.OutStock) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS TotalOutStock,
		(SELECT SUM(CC2.InStock) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS TotalInStock,
		C2.OutStock * C2.Cost AS TransValue,
		C2.OutStock * C2.AvgCost AS AvgTransValue,
		C2.ItemQty * C2.StdCost AS StdTransValue,
		(SELECT SUM(CC2.OutStock * CC2.Cost) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS [TotalTransValue],
		(SELECT SUM(CC2.OutStock * CC2.AvgCost) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS [AvgTotalTransValue],
		(SELECT SUM(CC2.OutStock * CC2.StdCost) FROM CTE2 CC2 WHERE CC2.Layer <= C2.Layer AND CC2.ItemID = C2.ItemID) AS [StdTotalTransValue]
		FROM CTE2 C2		
		WHERE C2.OutStock > 0
	)
	SELECT DISTINCT CTE3.* FROM CTE3
);
GO

--------------------------------------------------------------- pos_ufnGetWarehouseDetailSerialBatchMap 02-IssueStock-----------------------------------------------------------------------

GO
CREATE OR ALTER FUNCTION pos_ufnGetWarehouseDetailSerialBatchMap(@receiptId int, @warehouseId int)
RETURNS TABLE AS RETURN(
	WITH im_cte AS (
		SELECT DISTINCT
			IM.*, 
			RD.ID AS ReceiptDetailID 
		FROM tbReceiptDetail RD
		CROSS APPLY pos_ufnGetReceiptItemsWithBoM(RD.ReceiptID) IM
		WHERE UPPER(IM.Process) IN ('SERIAL','BATCH') AND RD.ReceiptID = @receiptId
	),
	im_sub_cte AS (
		SELECT 
			IM.WarehouseID,
			IM.ReceiptDetailID,
			IM.ItemID,
			IM.Process
		FROM im_cte IM
	),
	im_sr_cte AS (
		SELECT
			WD.ID AS [WDID],
			RDS.LineID AS [LineID],
			IM.ItemID AS [ItemID],
			RDS.SerialNo AS [SerialNo],
			'' AS [BatchNo],
			RDS.OpenQty AS [OpenQty],
			WD.InStock,
			WD.Cost,
			Layer = ROW_NUMBER() OVER(ORDER BY WD.ID)
		FROM im_sub_cte IM
		INNER JOIN tbReceiptDetailSerial RDS ON RDS.ReceiptDetailID = IM.ReceiptDetailID AND RDS.ItemID = IM.ItemID
		INNER JOIN tbWarehouseDetail WD ON WD.WarehouseID = IM.WarehouseID
		WHERE WD.ItemID = IM.ItemID AND WD.InStock > 0 AND WD.SerialNumber = RDS.SerialNo
	),
	im_bc_cte AS (
		SELECT 
			WD.ID AS [WDID],
			RDB.LineID AS [LineID],
			IM.ItemID AS [ItemID],
			'' AS [SerialNo],
			RDB.BatchNo AS [BatchNo],
			RDB.OpenQty AS [OpenQty],
			WD.InStock,
			WD.Cost,
			Layer = ROW_NUMBER() OVER(ORDER BY WD.ID)
		FROM im_sub_cte IM
		INNER JOIN tbReceiptDetailBatch RDB  ON RDB.ReceiptDetailID = IM.ReceiptDetailID AND RDB.ItemID = IM.ItemID
		INNER JOIN tbWarehouseDetail WD ON WD.WarehouseID = IM.WarehouseID
		WHERE WD.ItemID = IM.ItemID AND WD.InStock > 0 AND WD.BatchNo = RDB.BatchNo
	),
	sb_cte AS (
		SELECT * FROM im_sr_cte
		UNION ALL
		SELECT * FROM im_bc_cte
	),
	sbs_cte AS (
		SELECT 
		CT.WDID,
		TotalBaseStock = (SELECT SUM(CC.InStock) from sb_cte CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID),
		TotalOutStock = (SELECT SUM(CC.OpenQty) from sb_cte CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID),
		TotalInStock = (SELECT SUM(CC.InStock) - SUM(CC.OpenQty) from sb_cte CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID),
		TotalTransValue = (SELECT SUM(CC.OpenQty * CC.Cost) from sb_cte CC where CC.Layer <= CT.Layer AND CT.ItemID = CC.ItemID)
		FROM sb_cte CT
	)
	SELECT
			MAX(ISNULL(TWD.[WDID], 0)) AS ID,
			MAX(IM.ReceiptID) AS ReceiptID,
			MAX(IM.WarehouseID) AS WarehouseID,
			MAX(TWD.LineID) AS [LineID],
			MAX(TWD.ItemID) AS ItemID,
			MAX(IM.InventoryUomID) AS [InventoryUomID],
			MAX(IM.UomID) AS UomID,
			MAX(IM.GroupUomID) AS GroupUomID,
			Layer = ROW_NUMBER() OVER(ORDER BY TWD.[WDID]),
			MAX(IM.Process) AS [Process],
			MAX(ISNULL(TWD.Cost, 0)) AS Cost,
			MAX(0) AS AvgCost,
			MAX(0) AS StdCost,
			MAX(ISNULL(TWD.InStock, 0)) AS BaseStock,
			MAX(TWD.OpenQty) AS ItemQty,
			MAX(WDS.TotalBaseStock) AS [TotalBaseStock],
			MAX(TWD.InStock - TWD.OpenQty) AS [RemainQty],
			MAX(TWD.OpenQty) AS [OutStock],
			MAX(TWD.InStock - TWD.OpenQty) AS [InStock],
			MAX(WDS.TotalOutStock) AS [TotalOutStock],
			MAX(WDS.TotalInStock) AS TotalInStock,
			MAX(TWD.Cost * TWD.OpenQty) AS [TransValue],
			MAX(0) [AvgTransValue],
			MAX(0) [StdTransValue],
			MAX(WDS.TotalTransValue) AS [TotalTransValue],
			MAX(0) AS [AvgTotalTransValue],
			MAX(0) AS [StdTotalTransValue]
		FROM sb_cte TWD
		INNER JOIN sbs_cte WDS ON TWD.WDID = WDS.WDID
		INNER JOIN im_cte IM ON TWD.ItemID = IM.ItemID
		GROUP BY TWD.[WDID], TWD.ItemID, TWD.Cost, TWD.SerialNo, TWD.BatchNo
);
-------------------------------------------------------------pos_ufnGetWarehouseDetailMapUnionAll 02-IssueStock-------------------------------------------------------------------------

GO
CREATE OR ALTER FUNCTION pos_ufnGetWarehouseDetailMapUnionAll(@receiptId int, @warehouseId int)
RETURNS TABLE AS RETURN(
	SELECT * FROM pos_ufnGetWarehouseDetailMap(@receiptId, @warehouseId)
	UNION ALL 
	SELECT * FROM pos_ufnGetWarehouseDetailSerialBatchMap(@receiptId, @warehouseId)
);
------------------------------------------------------------[pos_ufnGetInventoryAuditMap] 02-IssueStock--------------------------------------------------------------------------

GO
CREATE OR ALTER  FUNCTION [dbo].[pos_ufnGetInventoryAuditMap](@receiptId int)
RETURNS TABLE AS RETURN(
	WITH
	R_CTE AS (
		SELECT * FROM tbReceipt R WHERE R.ReceiptID = @receiptId
	)
	, IA_CTE AS (
		SELECT 
			MAX(IA.ItemID) AS [ItemID],
			MAX(IA.Trans_Valuse) AS TransValue,
			SUM(IA.Qty) AS [CumulativeQty],
			SUM(IA.Trans_Valuse) AS [CumulativeValue]
		FROM tbInventoryAudit IA 
		GROUP BY IA.ItemID
	)
	SELECT 
		WD.ID AS [WarehouseDetailID],
		WD.ReceiptID AS [ReceiptID],
		WD.LineID AS [LineID],
		WD.ItemID AS [ItemID],
		WD.InventoryUomID AS [InventoryUomID],
		WD.UomID AS [UomID],
		WD.Process AS [Process],
		WD.OutStock AS [OutStock],
		WD.Cost AS [Cost],
		WD.AvgCost AS [AvgCost],
		WD.StdCost AS [StdCost],
		WD.TransValue AS [TransValue],
		WD.AvgTransValue AS [AvgTransValue],
		WD.StdTransValue AS [StdTransValue],
		ISNULL(IA.CumulativeQty, 0) - WD.TotalOutStock AS [CumulativeQty],
		ISNULL(IA.CumulativeQty, 0) - WD.ItemQty AS [StdCumulativeQty],
		ISNULL(IA.CumulativeValue, 0) - WD.TotalTransValue AS [CumulativeValue],
		ISNULL(IA.CumulativeValue, 0) - WD.AvgTotalTransValue AS [AvgCumulativeValue],
		ISNULL(IA.CumulativeValue, 0) - WD.StdTotalTransValue AS [StdCumulativeValue]
	FROM R_CTE R 
	CROSS APPLY pos_ufnGetWarehouseDetailMapUnionAll(R.ReceiptID, R.WarehouseID) WD
	LEFT JOIN IA_CTE IA ON IA.ItemID = WD.ItemID
);
---------------------------------------------------------------------[pos_ufnNewInventoryAudit] 02-IssueStock-----------------------------------------------------------------

GO
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

--------------------------------------------------------------------[pos_uspAddStockout] 02-IssueStock------------------------------------------------------------------

CREATE OR ALTER PROCEDURE [dbo].[pos_uspAddStockout] (
	@warehouseDetailMapSet [WarehouseDetailMap] READONLY,
	@stockOutMapSet [StockOutMap] READONLY
)
AS BEGIN
	INSERT INTO [dbo].[StockOut]
		([FromWareDetialID]
		,[WarehouseID]
		,[UomID]
		,[UserID]
		,[SyetemDate]
		,[TimeIn]
		,[InStock]
		,[CurrencyID]
		,[ExpireDate]
		,[ItemID]
		,[Cost]
		,[MfrSerialNumber]
		,[SerialNumber]
		,[BatchNo]
		,[BatchAttr1]
		,[BatchAttr2]
		,[MfrDate]
		,[AdmissionDate]
		,[Location]
		,[Details]
		,[SysNum]
		,[LotNumber]
		,[MfrWarDateStart]
		,[MfrWarDateEnd]
		,[TransType]
		,[ProcessItem]
		,[BPID]
		,[Direction]
		,[OutStockFrom]
		,[TransID]
		,[Contract]
		,[PlateNumber]
		,[Brand]
		,[Color]
		,[Condition]
		,[Power]
		,[Type]
		,[Year]
		,[BaseOnID]
		,[PurCopyType])
			
		SELECT
		WD.ID AS [FromWareDetialID]
		,WD.WarehouseID AS [WarehouseID]
		,TX.UomID
		,TX.UserID AS UserID
		,WD.SyetemDate
		,WD.TimeIn
		,WDS.OutStock
		,WD.CurrencyID
		,WD.[ExpireDate]
		,WD.ItemID
		,WD.Cost
		,WD.MfrSerialNumber
		,WD.SerialNumber
		,WD.BatchNo
		,WD.BatchAttr1
		,WD.BatchAttr2
		,WD.MfrDate
		,WD.AdmissionDate
		,WD.[Location]
		,WD.Details
		,WD.SysNum
		,WD.LotNumber
		,WD.MfrWarDateStart
		,WD.MfrWarDateEnd
		,14 --TransTypeWD.POS
		,TX.ProcessItem
		,TX.BPID
		,WD.Direction
		,TX.TransID AS OutStockFrom
		,TX.TransID AS TransID
		,TX.[ContractID] AS [Contract]
		,WD.PlateNumber
		,WD.Brand
		,WD.Color
		,WD.Condition
		,WD.[Power]
		,WD.[Type]
		,WD.[Year]
		,WD.BaseOnID
		,WD.PurCopyType
		FROM tbWarehouseDetail WD
		INNER JOIN @warehouseDetailMapSet WDS ON WD.ID = WDS.ID
		INNER JOIN @stockOutMapSet TX ON WD.ItemID = TX.ItemID	AND TX.WarehouseID = WD.WarehouseID
END
-----------------------------------------------------------------pos_uspUpdateStockWarehouseSummary 02-IssueStock---------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE pos_uspUpdateStockWarehouseSummary(@receiptId int)
AS BEGIN
	UPDATE WS 
		SET WS.CumulativeValue = TWS.CumulativeValue,
			WS.InStock = TWS.[InStock],
			WS.[Committed] = TWS.[Committed]
		FROM tbWarehouseSummary WS
		INNER JOIN (
			SELECT	
				MAX(WS.ID) AS [ID],
				MAX(IA.ItemID) AS [ItemID],
				MAX(WS.InStock) - ABS(SUM(IA.Qty)) AS [InStock],
				MAX(WS.CumulativeValue) - ABS(SUM(IA.Trans_Valuse)) AS [CumulativeValue],
				CASE WHEN MAX(WS.[Committed]) > ABS(SUM(IA.Qty)) 
					THEN MAX(WS.[Committed]) - ABS(SUM(IA.Qty)) ELSE 0 END
				AS [Committed]
			FROM tbWarehouseSummary WS
			INNER JOIN pos_ufnNewInventoryAudit(@receiptId) IA ON WS.ItemID = IA.ItemID AND WS.WarehouseID = IA.WarehouseID
			GROUP BY WS.ID, IA.ItemID
		) TWS ON TWS.ID = WS.ID
END;

-------------------------------------------------------------------pos_uspAddInventoryAudit 02-IssueStock-------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE pos_uspAddInventoryAudit(@receiptId int)
AS BEGIN
	INSERT INTO [dbo].[tbInventoryAudit]
    ([WarehouseID]
    ,[BranchID]
    ,[UserID]
    ,[ItemID]
    ,[CurrencyID]
    ,[UomID]
    ,[InvoiceNo]
    ,[Trans_Type]
    ,[Process]
    ,[SystemDate]
    ,[TimeIn]
    ,[Qty]
    ,[Cost]
    ,[Price]
    ,[CumulativeQty]
    ,[CumulativeValue]
    ,[Trans_Valuse]
    ,[ExpireDate]
    ,[LocalCurID]
    ,[LocalSetRate]
    ,[CompanyID]
    ,[DocumentTypeID]
    ,[SeriesDetailID]
    ,[SeriesID]
    ,[TypeItem]
    ,[LineID]
    ,[PostingDate]
    ,[OpenQty])
	SELECT * FROM pos_ufnNewInventoryAudit(@receiptId)
END; 

-----------------------------------------------------------------[pos_uspIssueStock] 02-IssueStock---------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[pos_uspIssueStock](@receiptId int)
AS
BEGIN
	BEGIN TRY
		BEGIN TRAN
		DECLARE @warehouseDetailMapSet [WarehouseDetailMap];
		DECLARE @stockOutMapSet [StockOutMap];
		INSERT INTO @warehouseDetailMapSet 
		SELECT DISTINCT TWD.* FROM tbReceipt R
		CROSS APPLY pos_ufnGetWarehouseDetailMapUnionAll(R.ReceiptID, R.WarehouseID) AS TWD
		WHERE R.ReceiptID = @receiptId
		INSERT INTO @stockOutMapSet
		SELECT 
			WDS.ItemID,
			R.WarehouseID,
			WDS.UomID,
			R.UserDiscountID AS UserID,
			R.ReceiptID AS [TransID],
			IM.ContractID AS [ContractID],
			R.ReceiptID  AS [OutStockFromID],
			R.CustomerID AS [BPID],
			WDS.OutStock AS [InStock],
			CASE 
				WHEN UPPER(IM.Process) = 'FIFO' THEN 1
				WHEN UPPER(IM.Process) = 'FEFO' THEN 2
				WHEN UPPER(IM.Process) = 'STANDARD' THEN 3
				WHEN UPPER(IM.Process) = 'AVERAGE' THEN 4
				WHEN UPPER(IM.Process) IN ('SERIAL', 'BATCH') THEN 5
			END AS [ProcessItem]
		FROM 
		@warehouseDetailMapSet WDS
		INNER JOIN tbItemMasterData IM ON IM.ID = WDS.ItemID
		CROSS APPLY tbReceipt R WHERE R.ReceiptID = WDS.ReceiptID AND UPPER(IM.Process) != 'STANDARD'
		EXEC pos_uspAddStockout	@warehouseDetailMapSet, @stockOutMapSet

		--Update [CumulativeValue] in table [tbWarehouseSummary] from previous inventory audit.
		EXEC pos_uspUpdateStockWarehouseSummary @receiptId

		--Add a new row to table [tbInventoryAudit]
		EXEC pos_uspAddInventoryAudit @receiptId
		
		--Update [InStock] of table [tbWarehouseDetail]
		UPDATE WD 
		SET WD.InStock = WDS.InStock
		FROM tbWarehouseDetail WD
		INNER JOIN (
			SELECT * FROM @warehouseDetailMapSet
		) AS WDS ON WD.ID = WDS.ID;

		--Update [Cost] in table [tbPriceListDetail]
		UPDATE PLD 
		SET PLD.Cost = TC.AvgCost * XR.SetRate * GDU.Factor
		FROM tbPriceListDetail PLD
		INNER JOIN (
			SELECT * FROM pos_ufnGetInventoryAuditMap(@receiptId)
		) AS TC ON PLD.ItemID = TC.ItemID
		INNER JOIN tbExchangeRate XR ON XR.CurrencyID = PLD.CurrencyID
		INNER JOIN tbItemMasterData IM ON IM.ID = PLD.ItemID 
		INNER JOIN tbGroupDefindUoM GDU ON GDU.GroupUoMID = IM.GroupUomID AND GDU.AltUOM = PLD.UomID

		COMMIT
	END TRY
	BEGIN CATCH
	 ROLLBACK
	END CATCH
END
GO

------------------------------------------------------------------[pos_ufnCheckStock] 02-IssueStock--------------------------------------------------------------------

GO
CREATE OR ALTER  FUNCTION [dbo].[pos_ufnCheckStock](@tempOrderId bigint)
RETURNS TABLE AS 
RETURN (
	WITH RD_CTE AS (
		SELECT			
			RD.LineID AS [LineID],
			RD.ItemID AS ItemID,
			RD.UomID AS UomID,
			0 AS [NegativeStock],
			RD.PrintQty AS BaseQty
		FROM TempOrder R
		INNER JOIN TempOrderItem RD ON R.TempOrderID = RD.TempOrderID
		WHERE R.TempOrderID = @tempOrderId
	),
	BM_CTE AS (
		SELECT * FROM RD_CTE
		UNION
		SELECT	
			'0' AS [LineID],
			BMD.ItemID AS ItemID,
			BMD.UomID AS UomID,
			CONVERT(bit, 1 * BMD.NegativeStock) AS [NegativeStock],
			BMD.Qty * IRD.BaseQty AS BaseQty
		FROM RD_CTE IRD
		LEFT JOIN tbBOMaterial BM ON BM.ItemID = IRD.ItemID
		INNER JOIN tbBOMDetail BMD ON BM.BID = BMD.BID 
		WHERE BM.[Active] = 1
	),
	ALL_CTE AS (
		SELECT		
			MAX(BMD.LineID) AS [LineID],
			MAX(BMD.ItemID) AS ItemID,
			MAX(BMD.UomID) AS UomID,
			MAX(GDU.GroupUoMID) AS [GroupUomID],
			CONVERT(bit, MAX(1 * BMD.NegativeStock)) AS [IsAllowedNegativeStock],
			SUM(BMD.BaseQty) AS Qty,
			MAX(IM.[Process]) AS [Process]
		FROM BM_CTE BMD
		INNER JOIN tbItemMasterData IM ON IM.ID = BMD.ItemID AND IM.[Delete] = 0
		INNER JOIN tbGroupDefindUoM GDU ON BMD.UomID = GDU.AltUOM AND IM.GroupUomID = GDU.GroupUoMID
		INNER JOIN tbWarehouseSummary WS ON IM.ID = WS.ItemID
		GROUP BY BMD.ItemID
	)
	SELECT * FROM (
		SELECT
			MAX(IMC.LineID) AS LineID,
			MAX(IMC.ItemID) AS ItemID,
			MAX(IM.Code) AS Code,
			MAX(IM.KhmerName) AS KhmerName,
			MAX(WS.InStock) AS InStock,
			MAX(WS.InStock - WS.[Committed] - IMC.Qty) AS TotalStock,
			MAX(IMC.Qty) AS [OrderQty],
			MAX(WS.[Committed]) AS [Committed],
			MAX(UM.[Name]) AS [Uom],
			MAX(CASE WHEN UPPER(IM.Process) IN ('SERIAL', 'BATCH') THEN 1 ELSE 0 END) AS IsSerailBatch
		FROM ALL_CTE IMC
		INNER JOIN tbItemMasterData IM ON IMC.ItemID = IM.ID
		INNER JOIN tbUnitofMeasure UM ON IMC.UomID = UM.ID
		INNER JOIN tbWarehouseSummary WS ON IM.ID = WS.ItemID
		WHERE UPPER(IM.Process) != 'STANDARD'
		GROUP BY IM.ID
	) T 
)

------------------------------------------------------------------[pos_uspGetNoneIssuedValidStockReceipts] 02-IssueStock --------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[pos_uspGetNoneIssuedValidStockReceipts]
AS
BEGIN
	SELECT DISTINCT _r.* FROM tbReceipt _r INNER JOIN tbReceiptDetail _rd ON _r.ReceiptID = _rd.ReceiptID  
	WHERE _r.ReceiptID 
	NOT IN (
		SELECT DISTINCT r.ReceiptID FROM tbReceipt r 
		CROSS APPLY pos_ufnGetReceiptItemsWithBoM(r.ReceiptID) rd
		INNER JOIN tbItemMasterData im on rd.ItemID = im.ID AND UPPER(im.Process) != 'STANDARD'
		INNER JOIN tbWarehouseSummary ws on ws.ItemID = rd.ItemID and ws.WarehouseID = r.WarehouseID
			AND (ws.InStock <= 0 OR (ws.InStock - ws.[Committed]) < rd.Qty)	
		GROUP BY r.ReceiptID
	) AND _r.SeriesDID NOT IN (SELECT i.SeriesDetailID FROM tbInventoryAudit i)
END;

---------------------------------------------------------------[pos_uspUpdateCommitStockWarehouseSummary] 02-IssueStock -----------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[pos_uspUpdateCommitStockWarehouseSummary](@orderId INT, @warehouseId INT)
AS BEGIN
	UPDATE WS
	SET 
		WS.[Committed] += TOD.TotalPrintQty
	FROM tbWarehouseSummary WS 
	INNER JOIN (
		SELECT
			MAX(OD.OrderID) OrderID,
			MAX(OD.ItemID) ItemID,
			SUM(OD.Qty * GDU.Factor) TotalQty,
			SUM(OD.PrintQty * GDU.Factor) TotalPrintQty
		FROM tbOrderDetail OD 
		INNER JOIN tbOrder O ON OD.OrderID = O.OrderID
		INNER JOIN tbGroupDefindUoM GDU ON OD.UomID = GDU.AltUOM AND OD.GroupUomID = GDU.GroupUoMID
		WHERE O.OrderID = @orderId
		GROUP BY OD.ItemID
	) TOD ON TOD.ItemID = WS.ItemID AND WS.WarehouseID = @warehouseId;

	UPDATE OD
	SET OD.PrintQty = 0
	FROM tbOrderDetail OD 
	INNER JOIN tbWarehouseSummary WS ON WS.ItemID = OD.ItemID AND WS.WarehouseID = @warehouseId
	WHERE OD.OrderID = @orderId
END
--------------------------------------------------------------[pos_ufnGetItemAccounting] Accounting ------------------------------------------------------------------------

GO
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

---------------------------------------------------------------[pos_ufnGetItemBalance] Accounting-----------------------------------------------------------------------

GO
CREATE OR ALTER  FUNCTION [dbo].[pos_ufnGetItemBalance](@receiptId int)
RETURNS TABLE AS RETURN (
	WITH RD_CTE AS (
		SELECT 
			MAX(ISNULL(TG.GLID, 0)) AS [GLAcctID],
			MAX(R.ReceiptID) AS ReceiptID, 
			MAX(R.CustomerID) AS CustomerID, 
			MAX(RD.ItemID) AS ItemID,
			MAX(IM.ItemGroup1ID) AS ItemGroupID,
			MAX(ISNULL(TG.ID, 0)) AS [TaxGroupID],
			MAX(ISNULL(TG.ID,0)) AS [TaxPlID],
			MAX(ISNULL(TG.ID,0)) AS [TaxSPID],
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
		LEFT JOIN TaxGroup TG ON TG.ID IN (R.TaxGroupID, RD.TaxGroupID,RD.PublicLightingTaxGroupID,RD.SpecailTaxGroupID) AND TG.[Active] = 1
		WHERE R.ReceiptID = @receiptId
		GROUP BY RD.ItemID
	)
	SELECT * FROM RD_CTE
);
GO
--------------------------------------------------------------------[pos_uspAddJournalAccountBalance] Accounting------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[pos_uspAddJournalAccountBalance](
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

----------------------------------------------------------------------[pos_uspSetListJournalAccounts]  Accounting----------------------------------------------------------------

GO
CREATE OR ALTER  PROC [dbo].[pos_uspSetListJournalAccounts] (
	@receiptId int,
	@journalEntryId int, 
	@docTypeId int
) AS BEGIN 
	DECLARE @journalMapSet [JournalMap];
	--Debit from Customer (Invoice)
	INSERT INTO @journalMapSet 
	SELECT 
		R.ReceiptID AS [ReceiptID],
		BP.ID AS [BPAcctID],
		GL.ID AS [GLAcctID],
		R.GrandTotal * R.ExchangeRate AS [Debit],
		0 AS [Credit]
	FROM tbReceipt R 
	LEFT JOIN tbBusinessPartner BP ON R.CustomerID = BP.ID
	INNER JOIN tbGLAccount GL ON GL.ID = BP.GLAccID
	WHERE R.ReceiptID = @receiptId
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Credit from Tax Group
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(RD.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		0 AS [Debit],
		SUM(RD.[ItemTaxValue]) AS [Credit]
	FROM pos_ufnGetItemBalance(@receiptId) RD
	INNER JOIN TaxGroup TG ON RD.TaxGroupID = TG.ID
	INNER JOIN tbGLAccount GL ON GL.ID = TG.GLID
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet
	
	--Credit from Tax PublicLightingTax
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(RD.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		0 AS [Debit],
		SUM(RD.[ItemPLTaxValue]) AS [Credit]
	FROM pos_ufnGetItemBalance(@receiptId) RD
	INNER JOIN TaxGroup TG ON RD.TaxPlID = TG.ID
	INNER JOIN tbGLAccount GL ON GL.ID = TG.GLID
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet
	
		--Credit from Tax PublicLightingTax
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(RD.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		0 AS [Debit],
		SUM(RD.[ItemSPTaxValue]) AS [Credit]
	FROM pos_ufnGetItemBalance(@receiptId) RD
	INNER JOIN TaxGroup TG ON RD.TaxSPID = TG.ID
	INNER JOIN tbGLAccount GL ON GL.ID = TG.GLID
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Credit from Freight
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT
		R.ReceiptID AS [ReceiptID],
		0 AS [BPAcctID],
		TFR.GLAcctID AS [GLAcctID],
		0 AS [Debit],
		TFR.AmountReven * R.ExchangeRate
		AS [Credit]
	FROM tbReceipt R
	CROSS APPLY (
		SELECT 
			MAX(GL.ID) AS GLAcctID,
			MAX(FR.ReceiptID) AS ReceiptID,
			MAX(FR.FreightID) AS FreightID,
			SUM(FR.AmountReven) AS AmountReven,
			MAX(FR.FreightReceiptType) AS FreightReceiptType
		FROM FreightReceipt FR
		INNER JOIN Freight F ON F.ID = FR.FreightID
		INNER JOIN tbGLAccount GL ON GL.ID = F.RevenAcctID
		WHERE FR.ReceiptID = R.ReceiptID AND FR.AmountReven > 0
		GROUP BY GL.ID
	) TFR WHERE TFR.ReceiptID = @receiptId
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	-- Credit from Revenue
	DELETE FROM @journalMapSet;
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(TIM.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(TIM.[GLAcctID]) AS [GLAcctID],
		0 AS [Debit],
		SUM(TIM.[RevenueAmount]) AS [Credit]	
	FROM  (
		SELECT
			MAX(TR.ReceiptID) AS [ReceiptID],
			MAX(TR.ItemID) AS [ItemID],
			MAX(TR.ItemGroupID) AS [ItemGroupID],
			MAX(GL.ID) AS [GLAcctID],
			MAX(TR.[RevenueAmount]) AS [RevenueAmount]	
		FROM pos_ufnGetItemBalance(@receiptId) TR
		CROSS APPLY pos_ufnGetItemAccounting(TR.ReceiptID) IA 	
		INNER JOIN tbGLAccount GL ON IA.RevenueAccount = GL.Code
		WHERE TR.ItemGroupID = IA.ItemGroupID OR TR.ItemID = IA.ItemID
		GROUP BY TR.ItemID
	) TIM GROUP BY TIM.GLAcctID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Debit from COGS (Cost Of Good Sold)
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(TIM.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(TIM.[GLAcctID]) AS [GLAcctID],
		ABS(SUM(IA.Trans_Valuse)) AS [Debit],
		0 AS [Credit]
	FROM 
	tbInventoryAudit IA 
	INNER JOIN(
		SELECT
			MAX(IM.[SeriesDetailID]) AS [SeriesDetailID],
			MAX(IM.ReceiptID) AS [ReceiptID],
			MAX(IB.ItemID) AS [ItemID],
			MAX(IB.ItemGroupID) AS [ItemGroupID],
			MAX(GL.ID) AS [GLAcctID]
		FROM pos_ufnGetReceiptItemsWithBoM(@receiptId) IM
		CROSS APPLY pos_ufnGetItemBalance(IM.ReceiptID) IB
		CROSS APPLY pos_ufnGetItemAccounting(IM.ReceiptID) IAC
		INNER JOIN tbGLAccount GL ON GL.Code = IAC.CostofGoodsSoldAccount
		WHERE (IB.ItemGroupID = IAC.ItemGroupID OR IB.ItemID = IAC.ItemID) 
		GROUP BY IB.ItemID, GL.ID
	) TIM ON TIM.SeriesDetailID = IA.SeriesDetailID AND TIM.ItemID = IA.ItemID
	GROUP BY IA.ItemID, TIM.GLAcctID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	-- Credit from Inventory
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(TIM.ReceiptID) AS [ReceiptID],
		0 AS [BPAcctID],
		MAX(TIM.[GLAcctID]) AS [GLAcctID],
		0 AS [Debit],
		ABS(SUM(IA.Trans_Valuse)) AS [Credit]
	FROM 
	tbInventoryAudit IA 
	INNER JOIN(
		SELECT
			MAX(IM.[SeriesDetailID]) AS [SeriesDetailID],
			MAX(IM.ReceiptID) AS [ReceiptID],
			MAX(IB.ItemID) AS [ItemID],
			MAX(IB.ItemGroupID) AS [ItemGroupID],
			MAX(GL.ID) AS [GLAcctID]
		FROM pos_ufnGetReceiptItemsWithBoM(@receiptId) IM
		CROSS APPLY pos_ufnGetItemBalance(IM.ReceiptID) IB
		CROSS APPLY pos_ufnGetItemAccounting(IM.ReceiptID) IAC
		INNER JOIN tbGLAccount GL ON GL.Code = IAC.InventoryAccount
		WHERE (IB.ItemGroupID = IAC.ItemGroupID OR IB.ItemID = IAC.ItemID) 
		GROUP BY IB.ItemID, GL.ID
	) TIM ON TIM.SeriesDetailID = IA.SeriesDetailID AND TIM.ItemID = IA.ItemID
	GROUP BY IA.ItemID, TIM.GLAcctID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	----Debit from Member cards
	--INSERT INTO @journalMapSet 
	--SELECT
	--	@receiptId AS [ReceiptID],
	--	0 AS [BPAcctID],
	--	GL.ID AS [GLAcctID],
	--	MP.Amount AS [Debit],
	--	0 AS [Credit]
	--FROM AccountMemberCards MC
	--INNER JOIN tbGLAccount GL ON GL.ID = MC.UnearnedRevenueID
	--INNER JOIN MultiPaymentMean MP ON MP.ReceiptID = @receiptId AND [Type] = 1 -- PaymentMeanType.CardMember
	--EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Debit from Payment Means
	DELETE FROM @journalMapSet
	INSERT INTO @journalMapSet
	SELECT 
		MAX(R.ReceiptID) AS [ReceiptID],
		MAX(0) AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		SUM(MP.Amount * MP.SCRate * R.ExchangeRate) AS [Debit],
		0 AS [Credit]
	FROM tbReceipt R
	LEFT JOIN MultiPaymentMean MP ON MP.ReceiptID = R.ReceiptID
	INNER JOIN tbPaymentMeans PM ON PM.ID = MP.PaymentMeanID
	INNER JOIN tbGLAccount GL ON GL.ID = PM.AccountID
	WHERE MP.Amount > 0 AND R.ReceiptID = @receiptId
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet

	--Credit from Customer (Invoice)
	DELETE FROM @journalMapSet;
	INSERT INTO @journalMapSet 
	SELECT 
		MAX(R.ReceiptID) AS [ReceiptID],
		MAX(R.CustomerID) AS [BPAcctID],
		MAX(GL.ID) AS [GLAcctID],
		0 AS [Debit],
		SUM(MP.Amount * MP.SCRate * R.ExchangeRate) AS [Credit]
	FROM tbReceipt R
	INNER JOIN tbBusinessPartner BP ON R.CustomerID = BP.ID
	LEFT JOIN MultiPaymentMean MP ON MP.ReceiptID = R.ReceiptID
	INNER JOIN tbPaymentMeans PM ON PM.ID = MP.PaymentMeanID
	INNER JOIN tbGLAccount GL ON GL.ID = BP.GLAccID
	WHERE MP.Amount > 0 AND R.ReceiptID = @receiptId
	GROUP BY GL.ID
	EXEC pos_uspAddJournalAccountBalance @journalEntryId, @docTypeId, @journalMapSet
END

GO
------------------------------------------------------------[pos_uspAddJournalEntry] Accounting--------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[pos_uspAddJournalEntry](@receiptId int)
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
-----------------------------------------------------------Pos_ufnGetGroupNameByReceipt (06-September-2023)---------------------------------------------------------------------------

GO
CREATE OR ALTER   FUNCTION [dbo].[pos_ufnGetGroupNameByReceipt](@receiptId int) 
RETURNS TABLE AS RETURN(
	WITH RG_CTE AS (
		SELECT
			IG.ItemG1ID AS ItemG1ID,
			RD.ReceiptID AS ReceiptID,
			IG.[Name] AS GroupName,
			Layer = ROW_NUMBER() OVER (PARTITION BY RD.ReceiptID ORDER BY IG.ItemG1ID),
			COUNT(*) OVER (PARTITION BY RD.ReceiptID) AS LayerCount
		FROM tbReceiptDetail RD
		INNER JOIN tbItemMasterData IM ON RD.ItemID = IM.ID
		INNER JOIN ItemGroup1 IG ON IG.ItemG1ID = IM.ItemGroup1ID
		WHERE RD.ReceiptID = @receiptId
	),
	RG_CTE2 AS (
		SELECT DISTINCT
		RG1.ReceiptID AS [ReceiptID],
		STUFF(
			(SELECT ', ' + RG.[GroupName] FROM RG_CTE RG 
			WHERE RG.Layer <= RG1.LayerCount AND RG.ReceiptID = RG1.ReceiptID 
			FOR XML PATH ('')), 1, 1, ''
		) AS [GroupName]
		FROM RG_CTE RG1
	)
	SELECT * FROM RG_CTE2
)

-----------------------------------------------------------pos_ufnGetGroupNameBySaleAR (06-September-2023)---------------------------------------------------------------------------

GO
CREATE OR ALTER   FUNCTION [dbo].[pos_ufnGetGroupNameBySaleAR](@salearId int) 
RETURNS TABLE AS RETURN(
	WITH AG_CTE AS (
		SELECT
			IG.ItemG1ID AS ItemG1ID,
			ARD.SARID AS SARID,
			IG.[Name] AS GroupName,
			Layer = ROW_NUMBER() OVER (PARTITION BY ARD.SARID ORDER BY IG.ItemG1ID),
			COUNT(*) OVER (PARTITION BY  ARD.SARID) AS LayerCount
		FROM tbSaleARDetail ARD
		INNER JOIN tbItemMasterData IM ON ARD.ItemID = IM.ID
		INNER JOIN ItemGroup1 IG ON IG.ItemG1ID = IM.ItemGroup1ID
		WHERE ARD.SARID = @salearId
	),
	AG_CTE2 AS (
		SELECT DISTINCT
		AG1.SARID AS SARID,
		STUFF(
			(SELECT ', ' + AG.[GroupName] FROM AG_CTE AG 
			WHERE AG.Layer <= AG1.LayerCount AND AG.SARID = AG1.SARID 
			FOR XML PATH ('')), 1, 1, ''
		) AS [GroupName]
		FROM AG_CTE AG1
	)
	SELECT * FROM AG_CTE2
)

-----------------------------------------------------------financial_rpt_GetEFillingSale (06-September-2023)---------------------------------------------------------------------------

GO
CREATE OR ALTER FUNCTION [dbo].[financial_rpt_GetEFillingSale](
@DateFrom date,
@DateTo date,
@Currency int
)

RETURNS TABLE AS
RETURN(
WITH 

tbsalear_cte AS (
	SELECT MAX( CONVERT(VARCHAR, AR.PostingDate,103 )) AS [Date]
		,MAX(AR.InvoiceNo) AS [InvoiceNo]
		,MAX(BP.Code) AS [CustomerCode]
		,MAX(BP.[Name]) AS [CustomerName1]
		,MAX(BP.Name2) AS [CustomerName2]
		,0 AS [VAT0]
		,CASE WHEN  @Currency =1 THEN MAX(AR.VatValue)* MAX(AR.ExchangeRate) ELSE MAX(AR.LocalSetRate *(AR.VatValue *AR.ExchangeRate)) END AS [VAT10]  
		,CASE WHEN  @Currency =1 THEN MAX(AR.SubTotalAfterDisSys)  ELSE MAX(AR.SubTotalAfterDisSys) * MAX(AR.LocalSetRate) END AS [TotalwithVAT0]
		,CASE WHEN  @Currency =1 THEN MAX(AR.SubTotalAfterDisSys + AR.VatValue) ELSE MAX(AR.SubTotalAfterDisSys + AR.VatValue) * MAX(AR.LocalSetRate) END AS [TotalwithVAT10]
		,'' AS [PLT]
		,MAX(AR.SubTotalAfterDis*1/100) AS [PrepaymentTax1]
		,'CMT' AS [Sector]
		,MAX(GN.GroupName)  AS [Description]
		,CASE WHEN  @Currency =1 THEN MAX(SYC.Description) ELSE MAX(LC.Description) END AS [Currency]
		FROM tbSaleAR AR
		CROSS APPLY pos_ufnGetGroupNameBySaleAR(AR.SARID) GN
		INNER JOIN tbBusinessPartner BP ON AR.CusID = BP.ID
		INNER JOIN tbCompany COM ON AR.CompanyID = COM.ID
		INNER JOIN tbCurrency SYC ON COM.SystemCurrencyID = SYC.ID
		INNER JOIN tbCurrency LC ON COM.LocalCurrencyID = LC.ID
		WHERE AR.PostingDate>=@DateFrom and AR.PostingDate<=@DateTo
		GROUP BY AR.SARID
	
	),
tbreceipt_cte AS (
	 SELECT MAX(CONVERT(VARCHAR, R.PostingDate,103 )) AS [Date]
		,MAX(R.ReceiptNo) AS [InvoiceNo]
		,MAX(BP.Code) AS [CustomerCode]
		,MAX(BP.[Name]) AS [CustomerName1]
		,MAX(BP.Name2) AS [CustomerName2]
		,0 AS [VAT0]
		,CASE WHEN  @Currency =1 THEN MAX(R.TaxValue)* MAX(R.ExchangeRate) ELSE MAX(R.LocalSetRate *(R.TaxValue *R.ExchangeRate)) END AS [VAT10]
		,CASE WHEN  @Currency =1 THEN MAX(R.TotalRevenue)* MAX(R.ExchangeRate) ELSE MAX(R.LocalSetRate *(R.TotalRevenue *R.ExchangeRate)) END AS [TotalwithVAT0]
		,CASE WHEN  @Currency =1 THEN MAX(R.TotalAfterTax)* MAX(R.ExchangeRate) ELSE MAX(R.LocalSetRate *(R.TotalAfterTax *R.ExchangeRate)) END AS [TotalwithVAT10]
		,'' AS [PLT]
		,MAX(R.TotalRevenue *1/100) AS [PrepaymentTax1]
		,'CMT' AS [Sector]
		,MAX(GN.GroupName)  AS [Description]
		,CASE WHEN  @Currency =1 THEN MAX(SYC.Description) ELSE  MAX(LC.Description) END AS [Currency]
		FROM tbReceipt R
		CROSS APPLY pos_ufnGetGroupNameByReceipt(R.ReceiptID) GN
		INNER JOIN tbBusinessPartner BP ON R.CustomerID = BP.ID
		INNER JOIN tbCurrency SYC ON R.SysCurrencyID = SYC.ID
		INNER JOIN tbCurrency LC ON R.SysCurrencyID = LC.ID

		WHERE R.DateOut>=@DateFrom and R.DateOut<=@DateTo 
		GROUP BY R.ReceiptID
),
efilingsale AS(
	SELECT * FROM tbreceipt_cte 
	UNION ALL 
	SELECT * FROM tbsalear_cte
)
	SELECT * FROM efilingsale

);


--------------------------------------------------------------sp_GetCustomer (06-September-2023)------------------------------------------------------------------------
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_GetCustomer] 
	-- Add the parameters for the stored procedure here
	
AS
BEGIN
	DECLARE @SortBy NVARCHAR(50) 
	SET @SortBy = (SELECT TOP 1 Code FROM CustomerSort WHERE [Enable]=1)

		SELECT
			BP.ID AS [No],
			BP.Code,
			BP.[Name],
			BP.[Type],
			G.[Name] AS Group1,
			BP.Point,
			BP.Phone,
			PL.[Name] AS PriceList
			FROM tbBusinessPartner BP
				JOIN tbPriceList PL ON BP.PriceListID=PL.ID
				LEFT JOIN tbGroup1 G ON BP.Group1ID=G.ID
			WHERE BP.[Delete]=0 AND BP.[Type]='Customer'
			ORDER BY 
				(CASE WHEN @SortBy = 'Code' THEN BP.Code
					WHEN @SortBy = 'Name' THEN BP.[Name] 
					WHEN @SortBy = 'Group1' THEN G.[Name] 
					ELSE @SortBy 
				END);	
END

-----------------------------------------------------purchaseap_ufnGetGroupNameByPurchase (06-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER FUNCTION [dbo].[purchaseap_ufnGetGroupNameByPurchase](@receiptId int) 
RETURNS TABLE AS RETURN(
	WITH RG_CTE AS (
		SELECT
			max(IG.ItemG1ID) AS ItemG1ID,
			max(RD.PurchaseAPID) AS ReceiptID,
			max(IG.[Name]) AS GroupName,
			Layer = ROW_NUMBER() OVER (PARTITION BY max(RD.PurchaseAPID) ORDER BY IG.ItemG1ID),
			COUNT(*) OVER (PARTITION BY max(RD.PurchaseAPID)) AS LayerCount
		FROM tbPurchaseAPDetail RD
		INNER JOIN tbItemMasterData IM ON RD.ItemID = IM.ID
		INNER JOIN ItemGroup1 IG ON IG.ItemG1ID = IM.ItemGroup1ID
		WHERE RD.PurchaseAPID = @receiptId 
		Group by IG.ItemG1ID
	),
	RG_CTE2 AS (
		SELECT DISTINCT
		RG1.ReceiptID AS [ReceiptID],
		STUFF(
			(SELECT ', ' + RG.[GroupName] FROM RG_CTE RG 
			WHERE RG.Layer <= RG1.LayerCount AND RG.ReceiptID = RG1.ReceiptID 
			FOR XML PATH ('')), 1, 1, ''
		) AS [GroupName]
		FROM RG_CTE RG1
	)
	SELECT * FROM RG_CTE2
)

-----------------------------------------------------purchaseap_rpt_EFiling (06-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER FUNCTION [dbo].[purchaseap_rpt_EFiling](@DateFrom date,@DateTo date,@type int)
RETURNS TABLE
AS
RETURN
	(
	WITH PUR_CTE1 AS(
	SELECT 
		G1.ItemG1ID AS [ItemGroupID1],
		MAX(PD.PurchaseAPID) AS [PurchaseAPID],
		MAX(G1.[Name]) AS [ItemGroupName]
	FROM ItemGroup1 G1
	INNER JOIN tbItemMasterData ITEM on G1.ItemG1ID = ITEM.ItemGroup1ID
	INNER JOIN tbPurchaseAPDetail PD ON ITEM.ID = PD.ItemID AND ITEM.[Delete] =0
	GROUP BY G1.ItemG1ID, PD.PurchaseAPID
),

TBPURCHASEAP_CTE AS (
	SELECT 
		 MAX( CONVERT(VARCHAR, AP.PostingDate,103 )) AS [Date]
		,MAX(AP.InvoiceNo) AS [InvoiceNo]
		,MAX(BP.Code) AS [SupplierCode]
		,MAX(BP.[Name]) AS [SupplierName1]
		,MAX(BP.Name2) AS [SupplierName2]
		,0 AS [VAT0]
		,CASE WHEN  @type =1 THEN MAX(AP.TaxValue)* MAX(AP.PurRate) ELSE MAX(AP.LocalSetRate *(AP.TaxValue *AP.PurRate)) END AS [VAT10]
		,CASE WHEN  @type =1 THEN MAX(AP.SubTotalAfterDisSys) ELSE MAX(AP.SubTotalAfterDisSys) * MAX(AP.LocalSetRate) END AS [TotalwithVAT0]
		,CASE WHEN  @type =1 THEN (MAX (AP.SubTotalAfterDisSys + (AP.TaxValue * AP.PurRate))) ELSE MAX(AP.LocalSetRate) *(MAX(AP.SubTotalAfterDisSys)+ MAX( (AP.TaxValue * AP.PurRate))) END AS [TotalwithVAT10]
		,'CMT' AS [Sector]
		,MAX(GN.GroupName) AS [Description]
		,MAX(AP.SysCurrencyID) AS [LocalSetRate]
		,MAX(AP.SysCurrencyID) AS [SysCurrencyID]
		,MAX(AP.LocalCurID) AS [LocalCurID]
		--,MAX(CS.[Description]) AS[SysCurrency]
		,CASE WHEN  @type =1 THEN MAX(CS.[Description]) ELSE MAX(CL.[Description]) END AS [SysCurrency]
		FROM tbPurchase_AP AP
		CROSS APPLY purchaseap_ufnGetGroupNameByPurchase(AP.PurchaseAPID) GN
		INNER JOIN tbBusinessPartner BP ON AP.VendorID = BP.ID
		INNER JOIN tbPurchaseAPDetail PDD ON AP.PurchaseAPID = PDD.PurchaseAPID
		INNER JOIN tbCurrency CS ON AP.SysCurrencyID = CS.ID
		INNER JOIN tbCurrency CL ON AP.LocalCurID = CL.ID
		INNER JOIN tbExchangeRate EX ON CS.ID = EX.ID
		WHERE AP.PostingDate >=CONVERT(date,@DateFrom) AND AP.PostingDate<=CONVERT(date,@DateTo)
		GROUP BY PDD.PurchaseAPID
	),

	EFILLING_PURCHASE_AP AS(
	SELECT * FROM TBPURCHASEAP_CTE 
	--UNION ALL 
	--SELECT * FROM tbsalear_cte
	)
	SELECT * FROM EFILLING_PURCHASE_AP
);
-----------------------------------------------------saleAR_ufnGetReceiptItemsWithBoM (06-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER  FUNCTION [dbo].[saleAR_ufnGetReceiptItemsWithBoM](@SARID int)
RETURNS TABLE AS RETURN(
	WITH SARD_CTE AS (
		SELECT			
			SD.SARID AS SARID, 
			S.WarehouseID AS WarehouseID,
			SD.ItemID AS ItemID,
			SD.UomID AS UomID,
			0 AS [NegativeStock],
			SD.Qty AS BaseQty
		FROM tbSaleAR S
		INNER JOIN tbSaleARDetail SD ON S.SARID = SD.SARID
		WHERE S.SARID = @SARID
	),
	BM_CTE AS (
		SELECT * FROM SARD_CTE
		UNION
		SELECT	
			IRD.SARID AS SARID,
			IRD.WarehouseID AS WarehouseID,
			BMD.ItemID AS ItemID,
			BMD.UomID AS UomID,
			CONVERT(bit, 1 * BMD.NegativeStock) AS [NegativeStock],
			BMD.Qty * IRD.BaseQty AS BaseQty
		FROM SARD_CTE IRD
		LEFT JOIN tbBOMaterial BM ON BM.ItemID = IRD.ItemID
		INNER JOIN tbBOMDetail BMD ON BM.BID = BMD.BID 
		WHERE BM.[Active] = 1
	)
	SELECT		
			MAX(BMD.SARID) AS [SARID],
			MAX(BMD.WarehouseID) AS [WarehouseID],
			MAX(BMD.ItemID) AS [ItemID],
			MAX(IM.InventoryUoMID) AS [InventoryUomID],
			MAX(BMD.UomID) AS [UomID],
			MAX(GDU.GroupUoMID) AS [GroupUomID],
			CONVERT(bit, MAX(1 * BMD.NegativeStock)) AS [IsAllowedNegativeStock],
			MAX(GDU.Factor) AS [Factor],
			SUM(BMD.BaseQty) AS [BaseQty],
			SUM(BMD.BaseQty * GDU.Factor) AS [Qty],
			MAX(IM.[Process]) AS [Process]
	FROM BM_CTE BMD
	INNER JOIN tbItemMasterData IM ON IM.ID = BMD.ItemID AND IM.[Delete] = 0
	INNER JOIN tbGroupDefindUoM GDU ON BMD.UomID = GDU.AltUOM AND IM.GroupUomID = GDU.GroupUoMID
	GROUP BY BMD.SARID, BMD.ItemID
)
-----------------------------------------------------saleAR_uspGetNoneIssuedValidStock (06-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER   PROCEDURE [dbo].[saleAR_uspGetNoneIssuedValidStock]
AS
BEGIN
	SELECT DISTINCT _r.* FROM tbSaleAR _r INNER JOIN tbSaleARDetail _rd ON _r.SARID = _rd.SARID 
	WHERE _r.SARID 
	NOT IN (
		SELECT DISTINCT r.SARID FROM tbSaleAR r 
		CROSS APPLY saleAR_ufnGetReceiptItemsWithBoM(r.SARID) rd
		INNER JOIN tbItemMasterData im on rd.ItemID = im.ID AND UPPER(im.Process) != 'STANDARD'
		INNER JOIN tbWarehouseSummary ws on ws.ItemID = rd.ItemID and ws.WarehouseID = r.WarehouseID
			AND (ws.InStock <= 0 OR (ws.InStock - ws.[Committed]) < rd.Qty)	
		GROUP BY r.SARID
	) AND _r.SeriesDID NOT IN (SELECT i.SeriesDetailID FROM tbInventoryAudit i)
END;

-----------------------------------------------------getAllCustomer (06-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE getAllCustomer @type VARCHAR(50)
AS
BEGIN
	SELECT *FROM tbBusinessPartner B WHERE B.[Type]=@type AND B.[Delete]=0
END

-----------------------------------------------------DashboardR1show (09-september-2023)---------------------------------------------------------------------------------
GO
CREATE OR ALTER PROCEDURE [dbo].[DashboardR1show]
AS
	BEGIN
	DECLARE @AVG FLOAT = 0
	DECLARE @receiptmemo FLOAT = 0
	DECLARE @saleaR FLOAT = 0
	DECLARE @salearRes FLOAT = 0
	DECLARE @salearSer FLOAT = 0
	DECLARE @salearedit FLOAT = 0
	DECLARE @saleARMemo FLOAT =0
	DECLARE @TOTALCOUNT FLOAT =0
	DECLARE @TOTALCOUNTMEMO FLOAT =0
	DECLARE @SumAvg FLOAT =0
	DECLARE @SumAvgMemo FLOAT =0
	DECLARE @sumtotalReciept FLOAT =0
	DECLARE @sumtotalSaleAR FLOAT =0
	DECLARE @sumtotalsalearRes FLOAT =0
	DECLARE @sumtotalsalearSer FLOAT =0
	DECLARE @sumtotalsalearedit FLOAT =0
	DECLARE @sumtotalreceiptmemo FLOAT =0
	DECLARE @sumtotalsaleARMemo FLOAT =0
	DECLARE @GRANDTOTALCOUNT FLOAT =0
	DECLARE @GRANDTOTALAVG FLOAT =0
	DECLARE @reDetail FLOAT =0
	DECLARE @memoDetail FLOAT =0
	DECLARE @saleARDetail FLOAT =0
	DECLARE @SaleARredetail FLOAT =0
	DECLARE @saleARSercondetail FLOAT =0
	DECLARE @salememoDetail FLOAT =0
	DECLARE @saleEditDetail FLOAT =0
	DECLARE @ReMemoDetailCount FLOAT =0
	DECLARE @ReDetailQty FLOAT =0
	DECLARE @ReMemoDetailQty FLOAT =0
	DECLARE @saleMemoDetailQty FLOAT =0
	DECLARE @saleDetailQty FLOAT =0
	DECLARE @saleARRDetailQty FLOAT =0
	DECLARE @saleARSerdetailQty FLOAT =0
	DECLARE @saleArEditDetailQty FLOAT =0
	DECLARE @totalCountAvgQty FLOAT =0
	DECLARE @totalQty FLOAT =0
	DECLARE @allavg FLOAT =0
	

  SET @AVG =(SELECT COUNT(*) FROM tbReceipt R WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @saleaR =(SELECT COUNT(*) FROM tbSaleAR R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @salearRes =(SELECT COUNT(*) FROM ARReserveInvoice R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @salearSer =(SELECT COUNT(*) FROM ServiceContract R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @salearedit =(SELECT COUNT(*) FROM SaleAREdites R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));

  SET @receiptmemo =(SELECT COUNT(*) FROM ReceiptMemo R WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @saleARMemo =(SELECT COUNT(*) FROM SaleCreditMemos R WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));

  SET @TOTALCOUNT = @AVG + @saleaR + @salearRes + @salearSer + @salearedit;
  SET @TOTALCOUNTMEMO = @saleARMemo+ @receiptmemo;

  SET @sumtotalReciept = (SELECT convert(float, ISNULL(SUM(r.GrandTotal_Sys),0)) FROM tbReceipt r WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @sumtotalSaleAR = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM tbSaleAR r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @sumtotalsalearRes = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM ARReserveInvoice r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @sumtotalsalearSer = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM ServiceContract r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  SET @sumtotalsalearedit = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM SaleAREdites r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));

  SET @sumtotalreceiptmemo = (SELECT convert(float, ISNULL(SUM(r.GrandTotalSys),0)) FROM ReceiptMemo r WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @sumtotalsaleARMemo = (SELECT convert(float, ISNULL(SUM(r.SubTotalSys),0)) FROM SaleCreditMemos r WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate));
  
  SET @SumAvg = @sumtotalReciept + @sumtotalSaleAR +@sumtotalsalearRes + @sumtotalsalearedit + @sumtotalsalearSer
  SET @SumAvgMemo = @sumtotalreceiptmemo + @sumtotalsaleARMemo

  SET @GRANDTOTALCOUNT = @TOTALCOUNT -@TOTALCOUNTMEMO
  SET @GRANDTOTALAVG = @SumAvg - @SumAvgMemo
   --decimal allavg = totalCount == 0 ? 0 : totalAmount / totalCount;
  

  SET @reDetail =(SELECT Count(*) FROM tbReceipt R INNER JOIN tbReceiptDetail RD ON R.ReceiptID = RD.ReceiptID WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @memoDetail =(SELECT COUNT(*) FROM ReceiptMemo RMEMO INNER JOIN ReceiptDetailMemoKvms RMEMOD ON RMEMO.ID = RMEMOD.ReceiptMemoID WHERE YEAR(GETDATE()) <= YEAR(RMEMO.DateOut));
  SET @saleARDetail =(SELECT COUNT(*) FROM tbSaleAR S INNER JOIN tbSaleARDetail SD ON S.SARID = SD.SARID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @SaleARredetail =(SELECT COUNT(*) FROM ARReserveInvoice S INNER JOIN ARReserveInvoiceDetail SD ON S.ID = SD.ARReserveInvoiceID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleARSercondetail =(SELECT COUNT(*) FROM ServiceContract S INNER JOIN ServiceContractDetail SD ON S.ID = SD.ServiceContractID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @salememoDetail=(SELECT COUNT(*) FROM SaleCreditMemos S INNER JOIN tbSaleCreditMemoDetail SD ON S.SCMOID = SD.SCMOID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleEditDetail=(SELECT COUNT(*) FROM SaleAREdites S INNER JOIN SaleAREditeDetails SD ON S.SARID = SD.SARID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));

  SET @ReDetailQty =(SELECT convert(float, ISNULL(SUM(RD.Qty),0)) FROM tbReceipt R INNER JOIN tbReceiptDetail RD ON R.ReceiptID = RD.ReceiptID WHERE YEAR(GETDATE()) <= YEAR(r.DateOut));
  SET @ReMemoDetailQty =(SELECT convert(float, ISNULL(SUM(RMEMOD.Qty),0)) FROM ReceiptMemo RMEMO INNER JOIN ReceiptDetailMemoKvms RMEMOD ON RMEMO.ID = RMEMOD.ReceiptMemoID WHERE YEAR(GETDATE()) <= YEAR(RMEMO.DateOut));
  SET @saleDetailQty =(SELECT convert(float, ISNULL(SUM(SD.Qty),0)) FROM tbSaleAR S INNER JOIN tbSaleARDetail SD ON S.SARID = SD.SARID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleARRDetailQty =(SELECT convert(float, ISNULL(SUM(SD.Qty),0)) FROM ARReserveInvoice S INNER JOIN ARReserveInvoiceDetail SD ON S.ID = SD.ARReserveInvoiceID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleARSerdetailQty =(SELECT convert(float, ISNULL(SUM(SD.Qty),0)) FROM ServiceContract S INNER JOIN ServiceContractDetail SD ON S.ID = SD.ServiceContractID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleMemoDetailQty=(SELECT convert(float, ISNULL(SUM(SD.Qty),0)) FROM SaleCreditMemos S INNER JOIN tbSaleCreditMemoDetail SD ON S.SCMOID = SD.SCMOID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
  SET @saleArEditDetailQty=(SELECT COUNT(*) FROM SaleAREdites S INNER JOIN SaleAREditeDetails SD ON S.SARID = SD.SARID WHERE YEAR(GETDATE()) <= YEAR(S.PostingDate));
	
   SET @totalCountAvgQty = (@reDetail +@saleARDetail +@SaleARredetail +@saleARSercondetail + @saleEditDetail)-(@memoDetail+@salememoDetail)
   SET @totalQty = (@ReDetailQty +@saleDetailQty +@saleARRDetailQty +@saleARSerdetailQty + @saleArEditDetailQty)-(@ReMemoDetailQty+@saleMemoDetailQty)
   SELECT 
	@SumAvg as SumAvg,
	@SumAvgMemo as SumAvgMemo,
	@GRANDTOTALCOUNT as totalCount,
	@GRANDTOTALAVG as totalAmount,
	@TOTALCOUNT as [Count],
	@TOTALCOUNTMEMO as countMemo,
	@ReDetailQty as ReDetailQty,
	@ReMemoDetailQty as ReMemoDetailQty,
	@saleDetailQty as saleDetailQty,
	@saleARRDetailQty​​ as saleARRDetailQty,
	@saleARSerdetailQty as saleARSerdetailQty,
	@saleMemoDetailQty as saleMemoDetailQty,
	@saleArEditDetailQty as saleArEditDetailQty,
	@totalCountAvgQty as totalCountAvgQty,
	@totalQty as totalQty
END;

-----------------------------------------------------GetRecieptMonthly (09-september-2023)---------------------------------------------------------------------------------
GO
CREATE OR ALTER PROCEDURE [dbo].[GetRecieptMonthly]
AS
BEGIN
	SELECT 
	MAX(item.ID) as [ReceiptID],
	MAX(r.ReceiptID) as [SARID],
	MAX(rd.ID) as [SARDID],
	MAX(item.ID) as [ItemID],
	SUM(rd.Total_Sys) as [SubTotal],
	SUM(r.GrandTotal_Sys)as [GrandTotal],
	MAX(item.KhmerName) as [ItemName],
	MAX(item.ItemGroup1ID)as [Group1ID],
	--MAX(MONTHNAME(s.PostingDate)) as [Month],
	MAX(DATENAME(MONTH,r.DateOut)) as [Month],
	MAX(r.DateOut) as [DateOut],
	MAX(U.Name) AS [GroupName]
	FROM tbReceipt r
	INNER JOIN tbReceiptDetail rd on r.ReceiptID = rd.ReceiptID
	INNER JOIN tbItemMasterData item on rd.ItemID = item.ID
	INNER JOIN ItemGroup1 U ON item.ItemGroup1ID = U.ItemG1ID
	INNER JOIN tbCurrency c on r.SysCurrencyID = c.ID
	WHERE YEAR(GETDATE()) <= YEAR(r.DateOut)
	GROUP BY rd.ItemID
END;

-----------------------------------------------------[GetRecieptMemos] (09-september-2023)---------------------------------------------------------------------------------
GO
CREATE OR ALTER PROCEDURE [dbo].[GetRecieptMemos]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.ReceiptKvmsID) AS [SARID],
		MAX(SD.ID) AS [SARDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SysCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		(MAX(SD.UnitPrice) * MAX(sd.Qty)) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		(MAX(SD.UnitPrice) * MAX(sd.Qty)) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.DateOut) AS [PostingDate],
		SUM(S.GrandTotalSys) AS [GrandTotalSys]
	FROM ReceiptMemo s 
		INNER JOIN ReceiptDetailMemoKvms  sd on s.ID = sd.ReceiptMemoID
	WHERE YEAR(GETDATE()) <= YEAR(s.DateOut) 
	GROUP BY sd.ID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - SD.TotalDisValue) ELSE (SD.TotalSys- SD.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.SARID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID

END

-----------------------------------------------------[GetReciepts] (09-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetReciepts]
AS
BEGIN
   SELECT
	  MAX(r.ReceiptID) as ReceiptID,
	  MAX(rd.ItemID) as ItemID,
	  MAX(item.KhmerName) as ItemName,
      SUM(rd.Total_Sys)- SUM(rd.TaxValue) as SubTotal,                    
      SUM(r.GrandTotal_Sys) as GrandTotal,    
	  MAX(item.ItemGroup1ID) as Group1ID,
	  MAX(rd.Total_Sys) - SUM(rd.TaxValue) as TotalItem,
	  MAX(MONTH(r.DateOut)) as [Month],
	  MAX(r.DateOut) as DateOut
FROM tbReceipt r
inner join tbReceiptDetail rd on rd.ReceiptID = r.ReceiptID
inner join tbItemMasterData item on rd.ItemID = item.ID
inner join tbCurrency c on r.SysCurrencyID = c.ID
WHERE YEAR(GETDATE()) <= YEAR(r.DateOut) 
GROUP BY rd.ID
END



-----------------------------------------------------[GetSaleARs] (09-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleARs]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.SARID) AS [SARID],
		MAX(SD.SARDID) AS [SARDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SaleCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		MAX(SD.TotalSys) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		SUM(SD.TotalSys) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.PostingDate) AS [PostingDate],
		SUM(S.SubTotalSys) AS [GrandTotalSys]
	FROM tbSaleAR s 
		INNER JOIN tbSaleARDetail sd on s.SARID = sd.SARID
	WHERE YEAR(GETDATE()) <= YEAR(s.PostingDate) 
	GROUP BY sd.SARDID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - sd.TotalDisValue) ELSE (SD.TotalSys - sd.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.SARID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID

END



-----------------------------------------------------[GetSaleAREdit] (09-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleAREdit]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.SARID) AS [SARID],
		MAX(SD.SARDID) AS [SARDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SaleCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		MAX(SD.TotalSys) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		SUM(SD.TotalSys) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.PostingDate) AS [PostingDate],
		SUM(S.SubTotalSys) AS [GrandTotalSys]
	FROM SaleAREdites s 
		INNER JOIN SaleAREditeDetails sd on s.SARID = sd.SARID
	WHERE YEAR(GETDATE()) <= YEAR(s.PostingDate) 
	GROUP BY sd.SARDID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - sd.TotalDisValue) ELSE (SD.TotalSys - sd.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.SARID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID

END

-----------------------------------------------------[GetSaleARsMonthly] (09-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER   PROCEDURE [dbo].[GetSaleARsMonthly]
AS
BEGIN
	
	SELECT 
	MAX(item.ID) as [Sarid],
	MAX(s.SARID) as [SARID],
	MAX(sd.SARDID) as [SARDID],
	MAX(item.ID) as [ItemID],
	SUM(s.SubTotal) as [SubTotal],
	SUM(s.TotalAmount)as [GrandTotal],
	MAX(item.KhmerName) as [ItemName],
	MAX(item.ItemGroup1ID)as [Group1ID],
	--MAX(MONTHNAME(s.PostingDate)) as [Month],
	MAX(DATENAME(MONTH,s.PostingDate)) as [Month],
	MAX(U.Name) AS [GroupName]
	FROM tbSaleAR s
	INNER JOIN tbSaleARDetail sd on s.SARID = sd.SARID
	INNER JOIN tbItemMasterData item on sd.ItemID = item.ID
	INNER JOIN ItemGroup1 U ON item.ItemGroup1ID = U.ItemG1ID
	INNER JOIN tbCurrency c on sd.CurrencyID = c.ID
	GROUP BY sd.ItemID

END;

-----------------------------------------------------[GetSaleARReserveMonthly](09-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER   PROCEDURE [dbo].[GetSaleARReserveMonthly]
AS
BEGIN
	
	SELECT 
	MAX(sd.ItemID) as [Sarid],
	MAX(s.ID) as [SARID],
	MAX(sd.ID) as [SARDID],
	MAX(item.ID) as [ItemID],
	SUM(s.SubTotal) as [SubTotal],
	SUM(s.TotalAmount)as [GrandTotal],
	MAX(item.ItemGroup1ID)as [Group1ID],
	MAX(item.KhmerName) as [ItemName],
	--MAX(MONTHNAME(s.PostingDate)) as [Month],
	MAX(DATENAME(MONTH,s.PostingDate)) as [Month],
	MAX(U.Name) AS [GroupName]
	FROM ARReserveInvoice s
	INNER JOIN ARReserveInvoiceDetail sd on s.ID = sd.ARReserveInvoiceID
	INNER JOIN tbItemMasterData item on sd.ItemID = item.ID
	INNER JOIN ItemGroup1 U ON item.ItemGroup1ID = U.ItemG1ID
	INNER JOIN tbCurrency c on sd.CurrencyID = c.ID
	GROUP BY sd.ItemID

END;

-----------------------------------------------------[GetSaleARSercontract](09-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleARSercontract]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.ID) AS [ID],
		MAX(SD.ID) AS [SERDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SaleCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		MAX(SD.TotalSys) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		SUM(SD.TotalSys) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.PostingDate) AS [PostingDate],
		SUM(S.SubTotalSys) AS [GrandTotalSys]
	FROM ServiceContract s 
		INNER JOIN ServiceContractDetail sd on s.ID = sd.ServiceContractID
	WHERE YEAR(GETDATE()) <= YEAR(s.PostingDate) 
	GROUP BY sd.ID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - sd.TotalDisValue) ELSE (SD.TotalSys - sd.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.ID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID

END

-----------------------------------------------------[GetSaleARSercontract](09-september-2023)---------------------------------------------------------------------------------

GO

CREATE OR ALTER PROCEDURE [dbo].[GetSaleCreadiMemos]
AS
BEGIN
	DECLARE @subTotal FLOAT = 0
	DECLARE @disInvoiceValue FLOAT =0
	DECLARE @TotalItem FLOAT =0

	SET @subTotal = (SELECT SUM(rd.TotalSys) FROM SaleCreditMemos r inner join tbSaleCreditMemoDetail rd on r.SCMOID = rd.SCMOID)
	SET @disInvoiceValue = (SELECT SUM(rd.TotalSys) * SUM(r.DisRate/100)  FROM SaleCreditMemos r inner join tbSaleCreditMemoDetail rd on r.SCMOID = rd.SCMOID)
	SET @TotalItem = (SELECT SUM(rd.TotalSys) -@disInvoiceValue  FROM SaleCreditMemos r inner join tbSaleCreditMemoDetail rd on r.SCMOID = rd.SCMOID)
   SELECT
		 
		  MAX(r.SCMOID) as ReceiptID,
		  MAX(rd.ItemID) as ItemID,
		  MAX(item.KhmerName) as ItemName,
		  SUM(rd.TotalSys) as SubTotal,                    
		  SUM(r.SubTotalSys) as GrandTotal,    
		  MAX(item.ItemGroup1ID) as Group1ID,
		  MAX(MONTH(r.PostingDate)) as [Month],
		  MAX(r.PostingDate) as DateOut,
		  MAX(rd.TotalSys)- @disInvoiceValue as TotalItem
	FROM SaleCreditMemos r
	inner join tbSaleCreditMemoDetail rd on rd.SCMOID = r.SCMOID
	inner join tbItemMasterData item on rd.ItemID = item.ID
	WHERE YEAR(GETDATE()) <= YEAR(r.PostingDate) 
	GROUP BY rd.SCMODID

END;

-----------------------------------------------------[GetSaleReserve](09-september-2023)---------------------------------------------------------------------------------

GO
CREATE OR ALTER PROCEDURE [dbo].[GetSaleReserve]
AS
BEGIN  
	WITH SR_CTE AS(
	SELECT 
		MAX(S.ID) AS [ID],
		MAX(SD.ID) AS [ARDID],
		MAX(SD.ItemID) AS [ItemID],
		MAX(s.SaleCurrencyID) AS SaleCurrencyID,
		MAX(S.[Status]) AS [Status],
		MAX(SD.TotalSys) AS [TotalSys],
		SUM(SD.TotalSys) AS [SubtotalSys],
		SUM(SD.TotalSys) * MAX(S.DisRate) / 100 AS [TotalDisValue],
		MAX(S.PostingDate) AS [PostingDate],
		SUM(S.SubTotalSys) AS [GrandTotalSys]
	FROM ARReserveInvoice s 
		INNER JOIN ARReserveInvoiceDetail sd on s.ID = sd.ARReserveInvoiceID
	WHERE YEAR(GETDATE()) <= YEAR(s.PostingDate) 
	GROUP BY sd.ID
),
SR_CTE2 AS (
	SELECT 
		SD.*,
		CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN -1 *(SD.TotalSys - sd.TotalDisValue) ELSE (SD.TotalSys - sd.TotalDisValue) END
		 AS [TotalItem],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.GrandTotalSys) * -1 ELSE (SD.GrandTotalSys) END
		 AS [GrandTotal],
		 CASE WHEN UPPER(SD.[Status]) = 'CANCEL' THEN (SD.SubtotalSys) * -1 ELSE (SD.SubtotalSys) END
		 AS [SubTotal]
	FROM SR_CTE SD
)
SELECT 
	SD.ID as ReceiptID,
	IM.ID as ItemID,
	IM.KhmerName as ItemName,               
	IM.ItemGroup1ID as Group1ID,
	MONTH(SD.PostingDate) as [Month],
	SD.TotalItem,
	SD.GrandTotal,
	SD.SubTotal,
	SD.PostingDate as DateOut
FROM SR_CTE2 SD
INNER JOIN tbItemMasterData IM ON SD.ItemID = IM.ID AND IM.[Delete] = 0
JOIN tbCurrency C ON SD.SaleCurrencyID = C.ID

END

-----------------------------------------------------[GetSaleReserve](09-september-2023)---------------------------------------------------------------------------------
GO
CREATE OR ALTER PROCEDURE getAllCustomer @type VARCHAR(50)
AS
BEGIN
	SELECT *FROM tbBusinessPartner B WHERE B.[Type]=@type AND B.[Delete]=0
END

-----------------------------------------------------[GetCloseShiftDetail](09-september-2023)---------------------------------------------------------------------------------
GO
CREATE OR ALTER PROCEDURE GetCloseShiftDetail @id int 
AS
BEGIN
	SELECT  
		CSD.ID,
		FORMAT (CSD.[Date], 'dd/MM/yyyy hh:mm tt') AS [DateTime],

		FORMAT(CSD.Amount,CONCAT('N',D.Amounts),'en-us') AS Amount, 
		CU.[Description] AS Currency
		FROM tbCloseShift CS
				INNER JOIN tbCloseShiftDetail CSD ON CS.ID=CSD.CloseShiftID
				INNER JOIN tbCurrency SycCU ON CS.SysCurrencyID = SycCU.ID
				INNER JOIN tbCurrency CU ON CSD.CurrID = CU.ID
				LEFT JOIN Displays	D ON SycCU.ID = D.DisplayCurrencyID
		WHERE CS.ID=@id
END

-----------------------------------------------------[GetOpenShiftDetail](09-september-2023)---------------------------------------------------------------------------------
GO

CREATE OR ALTER PROCEDURE GetOpenShiftDetail @id int 
AS
BEGIN
	SELECT  
		OSD.ID,
		FORMAT (OSD.[Date], 'dd/MM/yyyy hh:mm tt') AS [DateTime],

		FORMAT(OSD.Amount,CONCAT('N',D.Amounts),'en-us') AS Amount, 
		CU.[Description] AS Currency,
		OSD.Times
		FROM tbOpenShift OS
				INNER JOIN tbOpenShiftDetail OSD ON OS.ID=OSD.OpentShiftID
				INNER JOIN tbCurrency SycCU ON OS.SysCurrencyID = SycCU.ID
				INNER JOIN tbCurrency CU ON OSD.CurrID = CU.ID
				LEFT JOIN Displays	D ON SycCU.ID = D.DisplayCurrencyID
		WHERE OS.ID=@id
END


-------------16-September-2023--------------------------
		--add conditon where Itemmaster is not true
		












