DECLARE @db_name VARCHAR(50) -- database name 

DECLARE db_cursor CURSOR
FOR
SELECT name
FROM MASTER.dbo.sysdatabases
WHERE name IN (
		'master'
		,'msdb'
		,'model'
		,'tempdb'
		)

OPEN db_cursor

FETCH NEXT
FROM db_cursor
INTO @db_name

WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC [sp_helpdb] @dbname = @db_name

	FETCH NEXT
	FROM db_cursor
	INTO @db_name
END

CLOSE db_cursor

DEALLOCATE db_cursor
