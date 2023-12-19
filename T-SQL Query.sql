-------------------------------- SELECT DISTINCT ------------------------------------
SELECT 
    R.*
FROM tbReceipt R
INNER JOIN(
    SELECT DISTINCT R.ReceiptID FROM tbReceipt R
         INNER JOIN (SELECT ReceiptID FROM tbReceiptDetail
         ) AS RD 
         ON R.ReceiptID = RD.ReceiptID
) TR ON TR.ReceiptID = R.ReceiptID
