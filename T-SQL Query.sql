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


--------------------------------  CROSS JOIN ------------------------------------
SELECT C.*,U.[Name] AS UserName FROM CUSMER C
         CROSS JOIN UERACC U

SELECT C.*,U.[Name] AS UserName FROM CUSMER C
         CROSS JOIN BRANCH U


-------------------------------- UPDATE JOIN SELECT LAST ------------------------------------
    UPDATE WS SET WS.InStock = IA.CumulativeQty, WS.CumulativeValue = IA.CumulativeValue
    FROM tbWarehouseSummary WS
    INNER JOIN tbInventoryAudit IA ON WS.WarehouseID = IA.WarehouseID AND WS.ItemID = IA.ItemID AND IA.ID IN(
    SELECT _IA.ID FROM
    ( 
    	SELECT MAX(IA.ID) AS ID, IA.ItemID AS ItemID FROM tbInventoryAudit IA
    	 JOIN tbWarehouseSummary WS ON IA.WarehouseID = WS.WarehouseID AND IA.ItemID = WS.ItemID
    	--WHERE IA.ItemID = 147 AND IA.WarehouseID = 1
    	GROUP BY IA.ItemID
    ) AS _IA)
    
-------------------------------- SELECT NESTED JSON ------------------------------------
SELECT
    ent.Id AS 'Id',
    ent.Name AS 'Name',
    ent.Age AS 'Age',
    EMails = (
        SELECT
            Emails.Id AS 'Id',
            Emails.Email AS 'Email'
        FROM EntitiesEmails Emails WHERE Emails.EntityId = ent.Id
        FOR JSON PATH
    )
FROM Entities ent
FOR JSON PATH
------------------------------------------- SELECT NESTED JSON AND DEFAULT DATA ---------------------------------------------
-- ##T-SQL
CREATE OR ALTER FUNCTION dbo.get_UserAccountTempate()
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @JsonData NVARCHAR(MAX);
    SET @JsonData =(
            SELECT
                userAccount =(
                    SELECT
                         '' AS [name]
                        ,'' AS [code]
                        ,'' AS [userName]
                        ,'' AS [password]
                        ,'' AS [confirmPassword]
                        ,'' AS [ruleId]
                        ,'' AS [branchId]
                        ,'' AS [gender]
                        ,'' AS [status]
                        ,'' AS [departmentId]
                        FOR JSON PATH
                ),
                rules = (
                        SELECT 
                            MR.Name AS [ruleName]
                            ,MR.RuleID AS [ruleId]
                        FROM [dbo].MARULE MR
                    FOR JSON PATH
                ),
                branches =(
                    SELECT 
                        BR.Name AS [branchName]
                        ,BR.BranchID AS [branchId]
                    FROM [dbo].BRANCH BR
                    FOR JSON PATH
                ),
                departments =(
                    SELECT 
                        DP.Name AS [departmentName]
                        ,DP.DeparmentID AS [departmentId]
                    FROM [dbo].DEPMENT DP
                    FOR JSON PATH
                ),
                statuses =(
                    SELECT 
                        ES.id AS [Id]
                        ,ES.value AS [value]
                    FROM EnumUserStatus ES
                    FOR JSON PATH
                ),
                genders =(
                    SELECT 
                        EG.id AS [Id]
                        ,EG.[value] AS [value]
                    FROM [dbo].EnumGenders EG
                    FOR JSON PATH
                )
            FOR JSON PATH, ROOT('userTemplate')
)
    RETURN @JsonData;
END;
-- C# 
        -- public async Task<string?> GetUserAccountTempateJson(){
        --     string? jsonData ="";
        --     using (SqlConnection connection = new SqlConnection(_connectionString))
        --     {
        --         await connection.OpenAsync();
        --         // Specify the function call in the SQL query
        --         string sqlQuery = "SELECT dbo.GetUserAccountTempateJson() AS JsonData";
        --         using (SqlCommand command = new SqlCommand(sqlQuery, connection))
        --         {
        --             using (SqlDataReader reader = command.ExecuteReader())
        --             {
        --                 if (reader.HasRows)
        --                 {
        --                     while (reader.Read())
        --                     {
        --                         // Assuming the JSON result is in the "JsonData" column
        --                          jsonData = reader["JsonData"].ToString();
        --                         // Process the JSON data as needed
        --                         // Console.WriteLine(jsonData);
        --                     }
        --                 }
        --                 else
        --                 {
        --                     Console.WriteLine("No data returned.");
        --                 }
        --             }
        --         }
        --     }
        --     return jsonData;
        -- }
--------------------------------------------------------------------------------------------
