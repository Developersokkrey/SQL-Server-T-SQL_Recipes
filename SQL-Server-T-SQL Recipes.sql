--------------------------------------------CROSS APPLY---------------------------------------
GO
SELECT RET.* FROM tbReceipt AS R
CROSS APPLY 
(SELECT * FROM tbReceiptDetail AS RD WHERE R.ReceiptID = RD.ReceiptID) RET

-------------------------------------------ALTER DATABASE----------------------------------------
 GO
 ALTER DATABASE JinoMart05092023updated MODIFY NAME = JinoMart05092023updated1;

 ----------------------------------------@@VERSION------------------------------------------

 SELECT @@VERSION AS SQLVERSSION 