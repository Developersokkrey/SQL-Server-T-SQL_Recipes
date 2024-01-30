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
GO
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
-------------------------------------------------- Get data with Enum ------------------------------------------
GO
ALTER   FUNCTION [dbo].[get_UserAccountsAll]()
RETURNS TABLE AS 
RETURN(
SELECT 
     UA.Name AS [name]
    ,UA.Code AS [code]
    ,MR.Name AS [ruleName]
    ,BR.Name AS [branchName]
    ,DP.Name AS [departmentName]
    ,EG.value AS [genderValue]
    ,EG.id AS [gender]
    ,ES.value AS [statusValue]
    ,ES.id AS [status]
    FROM UERACC UA
    INNER JOIN [dbo].[BRANCH] BR ON UA.BranchID = BR.BranchID
    INNER JOIN [dbo].[DEPMENT] DP ON UA.DepartmentID = DP.DeparmentID
    INNER JOIN [dbo].[MARULE] MR ON UA.RuleID = MR.RuleID
    INNER JOIN [dbo].[EnumGenders] EG ON UA.Gender = EG.id
    INNER JOIN [dbo].[EnumUserStatus] ES ON UA.[Status] = ES.Id
)
GO
--C#
        -- public async Task<DataTable> GetAllUserAccountsAsync()
        -- {
        --     using SqlConnection cn = new SqlConnection(_connectionString);
        --     await cn.OpenAsync();
        --     using SqlCommand cmd = cn.CreateCommand();
        --     // cmd.CommandType = CommandType.Text;
        --     cmd.CommandText = "SELECT * FROM get_UserAccountsAll()";
        --     // cmd.Parameters.AddWithValue("@CompID", compID);
        --     using SqlDataAdapter sda = new(cmd);
        --     await cmd.ExecuteNonQueryAsync();
        --     DataTable dt = new DataTable();
        --     sda.Fill(dt);
        --     return dt;
        -- }
-------------------------------------- select nested json from store procure param---------------------------------
-- {
--     "person": {
--         "name": "John",
--         "age": 30,
--         "address": {
--             "city": "New York",
--             "zipcode": "10001"
--         }
--     }
-- }
-----
GO
ALTER PROCEDURE GetPersonInfo
    @JsonParam NVARCHAR(MAX)
AS
BEGIN
    SELECT
        JSON_VALUE(@JsonParam, '$.person.name') AS Name,
        JSON_VALUE(@JsonParam, '$.person.age') AS Age,
        JSON_VALUE(@JsonParam, '$.person.address.city') AS City,
        JSON_VALUE(@JsonParam, '$.person.address.zipcode') AS Zipcode ;
END;
------
DECLARE @JsonData NVARCHAR(MAX);
SET @JsonData = '{"person": {"name": "John", "age": 30, "address": {"city": "New York", "zipcode": "10001"}}}';

EXEC GetPersonInfo @JsonParam = @JsonData;
-------------------------------------------- select nested json from store procure param ----------------------------
GO
CREATE OR ALTER PROCEDURE sp_ParseNESTEDJSON
    @JsonParam NVARCHAR(MAX)
AS
BEGIN
    SELECT 
     JSON_VALUE(@JsonParam, '$.Header.HCustomerID') AS HCustomerID,
     JSON_VALUE(@JsonParam, '$.Header.HCompID') AS HCompID,
     JSON_VALUE(@JsonParam, '$.Header.HCode') AS HCode,
     JSON_VALUE(@JsonParam, '$.Header.HName1') AS HName1,
     JSON_VALUE(@JsonParam, '$.Header.HName2') AS HName2,
     JSON_VALUE(@JsonParam, '$.Header.HPhone') AS HPhone,
     JSON_VALUE(@JsonParam, '$.Header.HAddress') AS HAddress,
     JSON_VALUE(@JsonParam, '$.Header.HLocation') AS HLocation,
     JSON_VALUE(@JsonParam, '$.Header.HCompany') AS HCompany,
     ---
     JSON_VALUE(@JsonParam, '$.Header.Detail.CustomerID') AS CustomerID,
     JSON_VALUE(@JsonParam, '$.Header.Detail.CompID') AS CompID,
     JSON_VALUE(@JsonParam, '$.Header.Detail.Code') AS Code,
     JSON_VALUE(@JsonParam, '$.Header.Detail.Name1') AS Name1,
     JSON_VALUE(@JsonParam, '$.Header.Detail.Name2') AS Name2,
     JSON_VALUE(@JsonParam, '$.Header.Detail.Phone') AS Phone,
     JSON_VALUE(@JsonParam, '$.Header.Detail.Address') AS [Address],
     JSON_VALUE(@JsonParam, '$.Header.Detail.Location') AS [Location],
     JSON_VALUE(@JsonParam, '$.Header.Detail.Company') AS [Company]
END
----
GO
DECLARE @JsonData  NVARCHAR(MAX);
SET @JsonData  = '
    {
         "Header": 
         {
            "HCustomerID": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            "HCompID": "ce58dd11-c5b5-4019-9e28-9b5149491fb1",
            "HCode": "CU001",
            "HName1": "CU001",
            "HName2": "CU001",
            "HPhone": "CU001",
            "HAddress": "CU001",
            "HLocation": "CU001",
            "HCompany": null,
            "Detail":
                {
                    "CustomerID": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                    "CompID": "ce58dd11-c5b5-4019-9e28-9b5149491fb1",
                    "Code": "CU002",
                    "Name1": "CU002",
                    "Name2": "CU002",
                    "Phone": "CU002",
                    "Address": "CU002",
                    "Location": "CU002",
                    "Company": null
                },
                {
                    "CustomerID": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                    "CompID": "ce58dd11-c5b5-4019-9e28-9b5149491fb1",
                    "Code": "CU002",
                    "Name1": "CU002",
                    "Name2": "CU002",
                    "Phone": "CU002",
                    "Address": "CU002",
                    "Location": "CU002",
                    "Company": null
                }
        }
    }
    '

EXEC sp_ParseNESTEDJSON @JsonParam = @JsonData;
-------------------------------------------- SELECT INFORMATION_SCHEMA.COLUMNS --------------------------------------------------------
SELECT TABLE_NAME, COLUMN_NAME,IS_NULLABLE,DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME='ARDownPayment'
------------------------------------------ SELECT SCOPE_IDENTITY ------------------------------------
-- Create tables
CREATE TABLE YourTable
(
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Column1 VARCHAR(255),
    Column2 VARCHAR(255)
);

CREATE TABLE YourTable1
(
    ID INT IDENTITY(1,1) PRIMARY KEY,
    YourTableID INT FOREIGN KEY REFERENCES YourTable(ID),
    Column1 VARCHAR(255),
    Column2 VARCHAR(255)
);

-- Insert values into the first table
INSERT INTO YourTable (Column1, Column2) VALUES ('Value1', 'Value2');

-- Insert values into the second table with a foreign key reference
INSERT INTO YourTable1 (YourTableID, Column1, Column2)
VALUES (SCOPE_IDENTITY(), 'Value1', 'Value2');
----------------------------------------  INSERT INTO [CUSMER]  -----------------------
    ALTER PROCEDURE sp_ParseJSON
     @json NVARCHAR(MAX)
        AS
        BEGIN
                INSERT INTO [CUSMER] 
                SELECT NEWID(),[CompID],[Code],[Name1],[Name2],[Phone],[Address],[Location]
                FROM OPENJSON(@Json)
                WITH (
                    [CompID] NVARCHAR(MAX),
                    [Code] NVARCHAR(MAX),
                    [Name1] NVARCHAR(MAX),
                    [Name2] NVARCHAR(MAX),        
                    [Phone] NVARCHAR(MAX),        
                    [Address] NVARCHAR(MAX),        
                    [Location] NVARCHAR(MAX)      
                )
            -- SELECT * FROM test
            --INSERT INTO [CUSMER] ([CustomerID],[CompID],[Code],[Name1],[Name2],[Phone],[Address],[Location])
        END
--------------
EXEC sp_ParseJSON '[{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"ce58dd11-c5b5-4019-9e28-9b5149491fb1","Code":"CU001","Name1":"CU001","Name2":"CU001","Phone":"CU001","Address":"CU001","Location":"CU001","Company":null},{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"ce58dd11-c5b5-4019-9e28-9b5149491fb1","Code":"CU002","Name1":"CU002","Name2":"CU002","Phone":"CU002","Address":"CU002","Location":"CU002","Company":null},{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"ce58dd11-c5b5-4019-9e28-9b5149491fb1","Code":"CU003","Name1":"CU003","Name2":"CU003","Phone":"CU003","Address":"CU003","Location":"CU003","Company":null},{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"ce58dd11-c5b5-4019-9e28-9b5149491fb1","Code":"CU004","Name1":"CU004","Name2":"CU004","Phone":"CU004","Address":"CU004","Location":"CU004","Company":null},{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"ce58dd11-c5b5-4019-9e28-9b5149491fb1","Code":"CU005","Name1":"CU005","Name2":"CU005","Phone":"CU005","Address":"CU005","Location":"CU005","Company":null}]'


SELECT * FROM COMPAN
SELECT * FROM CUSMER
SELECT TABLE_NAME, COLUMN_NAME,IS_NULLABLE,DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME='CUSMER'
-------------------------------------------------------------------------------- insert nested json from store procure param

    ALTER PROCEDURE sp_ParseJSON
     @json NVARCHAR(MAX)
        AS
        BEGIN
                -- INSERT INTO [CUSMER] 
                -- SELECT
                -- NEWID()  AS CustomerID,
                -- JSON_VALUE(@Json, '$.CompID') AS CompID,
                -- JSON_VALUE(@Json, '$.Code') AS Code,
                -- JSON_VALUE(@Json, '$.Name1') AS Name1,
                -- JSON_VALUE(@Json, '$.Name2') AS Name2,
                -- JSON_VALUE(@Json, '$.Phone') AS Phone,
                -- JSON_VALUE(@Json, '$.Address') AS [Address],
                -- JSON_VALUE(@Json, '$.Location') AS [Location]
                 SELECT
                    NEWID() AS CustomerID,
                    JSON_VALUE(value, '$.CompID') AS CompID,
                    JSON_VALUE(value, '$.Code') AS Code,
                    JSON_VALUE(value, '$.Name1') AS Name1,
                    JSON_VALUE(value, '$.Name2') AS Name2,
                    JSON_VALUE(value, '$.Phone') AS Phone,
                    JSON_VALUE(value, '$.Address') AS [Address],
                    JSON_VALUE(value, '$.Location') AS [Location]
                FROM OPENJSON(@json);
                -- INSERT INTO [CUSMER] 
                -- SELECT NEWID(),*
                -- FROM OPENJSON(@Json)
                -- WITH (
                --     [CompID] NVARCHAR(MAX),
                --     [Code] NVARCHAR(MAX),
                --     [Name1] NVARCHAR(MAX),
                --     [Name2] NVARCHAR(MAX),        
                --     [Phone] NVARCHAR(MAX),        
                --     [Address] NVARCHAR(MAX),        
                --     [Location] NVARCHAR(MAX)      
                -- )
            -- SELECT * FROM test
            --INSERT INTO [CUSMER] ([CustomerID],[CompID],[Code],[Name1],[Name2],[Phone],[Address],[Location])
        END
--------------
EXEC sp_ParseJSON '[{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"93cfc975-517d-43c8-841b-766ec4d53f79","Code":"CU001","Name1":"CU001","Name2":"CU001","Phone":"CU001","Address":"CU001","Location":"CU001","Company":null},{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"93cfc975-517d-43c8-841b-766ec4d53f79","Code":"CU002","Name1":"CU002","Name2":"CU002","Phone":"CU002","Address":"CU002","Location":"CU002","Company":null},{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"93cfc975-517d-43c8-841b-766ec4d53f79","Code":"CU003","Name1":"CU003","Name2":"CU003","Phone":"CU003","Address":"CU003","Location":"CU003","Company":null},{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"93cfc975-517d-43c8-841b-766ec4d53f79","Code":"CU004","Name1":"CU004","Name2":"CU004","Phone":"CU004","Address":"CU004","Location":"CU004","Company":null},{"CustomerID":"3fa85f64-5717-4562-b3fc-2c963f66afa6","CompID":"93cfc975-517d-43c8-841b-766ec4d53f79","Code":"CU005","Name1":"CU005","Name2":"CU005","Phone":"CU005","Address":"CU005","Location":"CU005","Company":null}]'
 

SELECT * FROM COMPAN
SELECT * FROM CUSMER
SELECT TABLE_NAME, COLUMN_NAME,IS_NULLABLE,DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME='CUSMER'
