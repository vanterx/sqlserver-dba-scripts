WITH reg_server
AS (
	SELECT [Customer]
		,SERVER
	FROM ServerList
	WHERE Customer = ''
	)
SELECT 1 AS [Order]
	,'' AS [Object]
	,'Open SSMS, open Powershell from SSMS (right-click server name in Object Explorer), then run the "PS" commands:' AS [Instruction]
	,'' AS [PS]

UNION

SELECT 2 AS [Order]
	,[Customer] AS [Object]
	,'- Navigate to the correct directory' AS [Instruction]
	,'set-location "SQLServer:\SqlRegistration\Database Engine Server Group";' AS [PS]
FROM reg_server

UNION

SELECT 3 AS [Order]
	,[Customer] AS [Object]
	,'- Create a new customer subfolder' AS [Instruction]
	,'new-item "' + [Customer] + '"' AS [PS]
FROM reg_server

UNION

SELECT 4 AS [Order]
	,[Customer] AS [Object]
	,'- Navigate to the new subfolder' AS [Instruction]
	,'cd "SQLSERVER:\sqlregistration\Database Engine Server Group\' + [Customer] + '\"' AS [PS]
FROM reg_server

UNION

SELECT 5 AS [Order]
	,[Server] AS [Object]
	,'- Create the individual entries for each customer server' AS [Instruction]
	,'new-item $(Encode-Sqlname "' + [Server] + '") -itemtype registration -Value "Server=' + [Server] + '; Integrated security=true"' AS [PS]
FROM reg_server;
