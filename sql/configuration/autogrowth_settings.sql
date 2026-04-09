DECLARE @NewDataFileGrowth VARCHAR(100) = '512GB'
DECLARE @NewLogGrowth VARCHAR(100) = '256MB'
DECLARE @TempDBNewDataFileGrowth VARCHAR(100) = '1024GB'
DECLARE @TempDBNewLogGrowth VARCHAR(100) = '512MB'

SELECT CASE 
		WHEN lower(physical_name) LIKE '%.ldf' and lower(DB_NAME(mf.database_id)) !='tempdb'
			THEN 'ALTER DATABASE [' + DB_NAME(mf.database_id) + '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' + @NewLogGrowth + ');'
		WHEN lower(physical_name) LIKE '%.mdf' and lower(DB_NAME(mf.database_id)) !='tempdb'
			THEN 'ALTER DATABASE [' + DB_NAME(mf.database_id) + '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' + @NewDataFileGrowth + ');'
		WHEN lower(physical_name) LIKE '%.ldf' and lower(DB_NAME(mf.database_id)) ='tempdb'
			THEN 'ALTER DATABASE [' + DB_NAME(mf.database_id) + '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' + @TempDBNewLogGrowth + ');'
		WHEN lower(physical_name) LIKE '%.mdf' and lower(DB_NAME(mf.database_id)) ='tempdb'
			THEN 'ALTER DATABASE [' + DB_NAME(mf.database_id) + '] MODIFY FILE (NAME = [' + mf.name + '], FILEGROWTH = ' + @TempDBNewDataFileGrowth + ');'
	    ELSE 'Error - Invalid Option'
		END AS ChangeAutoGrowSettings
	,DB_NAME(mf.database_id) database_name
	,mf.name logical_name
	,CONVERT(DECIMAL(20, 2), (CONVERT(DECIMAL, size) / 128)) [file_size_MB]
	,CASE mf.is_percent_growth
		WHEN 1
			THEN 'Yes'
		ELSE 'No'
		END AS [is_percent_growth]
	,CASE mf.is_percent_growth
		WHEN 1
			THEN CONVERT(VARCHAR, mf.growth) + '%'
		WHEN 0
			THEN CONVERT(VARCHAR, mf.growth / 128) + ' MB'
		END AS [growth_in_increment_of]
	,CASE mf.is_percent_growth
		WHEN 1
			THEN CONVERT(DECIMAL(20, 2), (((CONVERT(DECIMAL, size) * growth) / 100) * 8) / 1024)
		WHEN 0
			THEN CONVERT(DECIMAL(20, 2), (CONVERT(DECIMAL, growth) / 128))
		END AS [next_auto_growth_size_MB]
	,CASE mf.max_size
		WHEN 0
			THEN 'No growth is allowed'
		WHEN 1
			THEN 'File will grow until the disk is full'
		ELSE CONVERT(VARCHAR, mf.max_size)
		END AS [max_size]
	,physical_name
FROM sys.master_files mf
	where 
	  CASE mf.is_percent_growth
	  WHEN 1 THEN CONVERT(VARCHAR, mf.growth) + '%'
	  WHEN 0 THEN CONVERT(VARCHAR, mf.growth / 128) + ' MB'
	  END IN ('10%', '1 MB') or ( mf.is_percent_growth =0 and ( mf.growth / 128) > 64)
