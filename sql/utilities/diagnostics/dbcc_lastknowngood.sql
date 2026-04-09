IF OBJECT_ID('tempdb..#DBINFO') IS NOT NULL
	DROP TABLE #DBINFO;

IF OBJECT_ID('tempdb..#DBINFO_Final') IS NOT NULL
	DROP TABLE #DBINFO_Final;

DECLARE @db_name SYSNAME;

CREATE TABLE #DBINFO (
	ParentObject NVARCHAR(100)
	,[Object] NVARCHAR(128)
	,[Field] NVARCHAR(128)
	,[VALUE] NVARCHAR(128)
	)

CREATE TABLE #DBINFO_Final (
	[DBName] SYSNAME
	,ParentObject NVARCHAR(100)
	,[Object] NVARCHAR(128)
	,[Field] NVARCHAR(128)
	,[VALUE] NVARCHAR(128)
	)

DECLARE db_cursor CURSOR
FOR
SELECT name
FROM sys.databases
WHERE database_id > 4
	AND state_desc = 'ONLINE'
	AND is_read_only = 0
	AND create_date < DATEADD(DAY, - 7, GETDATE())

OPEN db_cursor

FETCH NEXT
FROM db_cursor
INTO @db_name

WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT #DBINFO
	EXECUTE ('DBCC DBINFO(''' + @db_name + ''') WITH TABLERESULTS')

	INSERT INTO #DBINFO_Final
	SELECT DISTINCT @db_name [dbname]
		,*
	FROM #DBINFO
	WHERE [Field] = 'dbi_dbccLastKnownGood'
		

	DELETE #DBINFO

	FETCH NEXT
	FROM db_cursor
	INTO @db_name
END

CLOSE db_cursor

DEALLOCATE db_cursor

SELECT *
FROM #DBINFO_Final
WHERE DATEDIFF(DAY, [VALUE], GETDATE()) > 7
