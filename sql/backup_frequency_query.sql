DECLARE @cponly NVARCHAR(200)

SELECT DISTINCT @cponly = 'is_copy_only'
FROM msdb..syscolumns
WHERE name = 'is_copy_only'
	AND id = OBJECT_ID('msdb.dbo.backupset')

DECLARE @sql NVARCHAR(4000)

SET @sql = N'
SELECT database_name,type, AVG(datediff(minute, previous_backup, backup_start_date)/60.0)
FROM (
    SELECT database_name, 
        type,
        backup_start_date, 
        (
            SELECT TOP 1 backup_start_date
            FROM msdb.dbo.backupset AS B
            WHERE type = A.type
                AND database_name = A.database_name
                AND backup_start_date < A.backup_start_date
                AND backup_start_date > DATEADD(day, -40, GETDATE())
                ' + CASE 
		WHEN @cponly IS NOT NULL
			THEN ' AND is_copy_only = 0'
		ELSE ''
		END + '
            ORDER BY backup_start_date DESC
        ) AS previous_backup 
    FROM msdb.dbo.backupset AS A
    WHERE backup_start_date > DATEADD(day, -30, GETDATE())
    ' + CASE 
		WHEN @cponly IS NOT NULL
			THEN ' AND is_copy_only = 0'
		ELSE ''
		END + '
) AS data
GROUP BY database_name,type
'

IF OBJECT_ID('tempdb..#res') IS NOT NULL
	DROP TABLE #res;

CREATE TABLE #res (
	database_name SYSNAME
	,type CHAR(1)
	,hours FLOAT
	,dev VARCHAR(500)
	)

INSERT INTO #res (
	database_name
	,type
	,hours
	)
EXEC (@sql)

IF OBJECT_ID('tempdb..#dev') IS NOT NULL
	DROP TABLE #dev

CREATE TABLE #dev (
	database_name SYSNAME
	,dev VARCHAR(500)
	,type CHAR(1)
	,cnt INT
	)

SET @sql = '
SELECT database_name,dev, type, COUNT(*) AS cnt
FROM (
    SELECT database_name,type, dev = 
        CASE
            WHEN name LIKE ''%Veeam%'' THEN ''Snapshot''
            WHEN physical_device_name LIKE ''{%}%'' THEN ''Snapshot''
            WHEN physical_device_name LIKE ''Legato#%'' THEN ''Networker''
            WHEN physical_device_name LIKE ''TDPSQL%'' THEN ''Tivoli''
            WHEN physical_device_name LIKE ''_:%'' THEN ''Native''
            WHEN physical_device_name LIKE ''\\%'' THEN ''Native''
			WHEN physical_device_name LIKE ''VNBU%'' THEN ''NetBackup''
            WHEN device_type = 7 THEN ''Other''
            ELSE physical_device_name
        END
    FROM msdb.dbo.backupmediafamily AS bmf
    INNER JOIN msdb.dbo.backupset AS bs
        ON bmf.media_set_id = bs.media_set_id
    WHERE backup_start_date > DATEADD(day,-30,GETDATE())
    ' + CASE 
		WHEN @cponly IS NOT NULL
			THEN ' AND is_copy_only = 0'
		ELSE ''
		END + '
) AS d
GROUP BY database_name,dev, type 
'

INSERT INTO #dev
EXEC (@sql)

DELETE d1
FROM #dev AS d1
WHERE EXISTS (
		SELECT *
		FROM #dev AS d2
		WHERE d1.type = d2.type
			AND d2.cnt > d1.cnt
			AND d1.database_name = d2.database_name
		)

UPDATE r
SET dev = d.dev
FROM #dev AS d
INNER JOIN #res AS r ON r.type = d.type
	AND r.database_name = r.database_name

SELECT D.database_name
	,devD
	,D
	,devL
	,L
	,devI
	,I
FROM (
	SELECT database_name
		,hours AS D
		,dev AS devD
	FROM #res
	WHERE type = 'D'
	) AS D
LEFT JOIN (
	SELECT database_name
		,hours AS L
		,dev AS devL
	FROM #res
	WHERE type = 'L'
	) AS L ON 1 = 1
	AND D.database_name = L.database_name
LEFT JOIN (
	SELECT database_name
		,hours AS I
		,dev AS devI
	FROM #res
	WHERE type = 'I'
	) AS I ON 1 = 1
	AND D.database_name = I.database_name
