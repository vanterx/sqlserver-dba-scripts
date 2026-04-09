--------------------------------------------------------------------------------------------------------------------------------
-- Errorlog based checks subsection
-- Because it is a string based search, add other search conditions as deemed fit.
--------------------------------------------------------------------------------------------------------------------------------
RAISERROR (N'  |-Starting Errorlog based checks', 10, 1) WITH NOWAIT
DECLARE @lognumber int, @logcount int
DECLARE @sqlcmd NVARCHAR(max), @params NVARCHAR(600), @sqlmajorver int
DECLARE @ErrorSeverity int, @ErrorState int, @ErrorMessage NVARCHAR(4000)
SELECT @sqlmajorver = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);
DECLARE @langid smallint
SELECT @langid = lcid FROM sys.syslanguages WHERE name = @@LANGUAGE


BEGIN
	SET @lognumber = 0 

	IF EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#dbcc'))
	DROP TABLE #dbcc;
	IF NOT EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#dbcc'))
	CREATE TABLE #dbcc (rowid int IDENTITY(1,1) PRIMARY KEY, logid int NULL, logdate DATETIME, spid VARCHAR(50), logmsg VARCHAR(4000)) 
	IF EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#dbcc'))
	CREATE INDEX [dbcc_logmsg] ON dbo.[#dbcc](logid) 

	IF EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#avail_logs'))
	DROP TABLE #avail_logs;
	IF NOT EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#avail_logs'))
	CREATE TABLE #avail_logs (lognum int, logdate DATETIME, logsize int) 

	-- Get the number of available logs 
	INSERT INTO #avail_logs 
	EXEC xp_enumerrorlogs 

	SELECT @logcount = MAX(lognum) FROM #avail_logs 

	WHILE @lognumber < @logcount 
	BEGIN
		-- Cycle thru sql error logs
		SELECT @sqlcmd = 'EXEC master..sp_readerrorlog ' + CONVERT(VARCHAR(3),@lognumber) + ', 1, ''15 seconds'''
		BEGIN TRY
			INSERT INTO #dbcc (logdate, spid, logmsg) 
			EXECUTE (@sqlcmd);
			UPDATE #dbcc SET logid = @lognumber WHERE logid IS NULL;
		END TRY
		BEGIN CATCH
			SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
			SELECT @ErrorMessage = 'Errorlog based subsection - Error raised in TRY block 1. ' + ERROR_MESSAGE()
			RAISERROR (@ErrorMessage, 16, 1);
		END CATCH
		SELECT @sqlcmd = 'EXEC master..sp_readerrorlog ' + CONVERT(VARCHAR(3),@lognumber) + ', 1, ''deadlock'''
		BEGIN TRY
			INSERT INTO #dbcc (logdate, spid, logmsg) 
			EXECUTE (@sqlcmd);
			UPDATE #dbcc SET logid = @lognumber WHERE logid IS NULL;
		END TRY
		BEGIN CATCH
			SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
			SELECT @ErrorMessage = 'Errorlog based subsection - Error raised in TRY block 2. ' + ERROR_MESSAGE()
			RAISERROR (@ErrorMessage, 16, 1);
		END CATCH
		SELECT @sqlcmd = 'EXEC master..sp_readerrorlog ' + CONVERT(VARCHAR(3),@lognumber) + ', 1, ''stack dump'''
		BEGIN TRY
			INSERT INTO #dbcc (logdate, spid, logmsg) 
			EXECUTE (@sqlcmd);
			UPDATE #dbcc SET logid = @lognumber WHERE logid IS NULL;
		END TRY
		BEGIN CATCH
			SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
			SELECT @ErrorMessage = 'Errorlog based subsection - Error raised in TRY block 3. ' + ERROR_MESSAGE()
			RAISERROR (@ErrorMessage, 16, 1);
		END CATCH
		SELECT @sqlcmd = 'EXEC master..sp_readerrorlog ' + CONVERT(VARCHAR(3),@lognumber) + ', 1, ''Error:'''
		BEGIN TRY
			INSERT INTO #dbcc (logdate, spid, logmsg) 
			EXECUTE (@sqlcmd);
			UPDATE #dbcc SET logid = @lognumber WHERE logid IS NULL;
		END TRY
		BEGIN CATCH
			SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
			SELECT @ErrorMessage = 'Errorlog based subsection - Error raised in TRY block 4. ' + ERROR_MESSAGE()
			RAISERROR (@ErrorMessage, 16, 1);
		END CATCH
		SELECT @sqlcmd = 'EXEC master..sp_readerrorlog ' + CONVERT(VARCHAR(3),@lognumber) + ', 1, ''A significant part of sql server process memory has been paged out'''
		BEGIN TRY
			INSERT INTO #dbcc (logdate, spid, logmsg) 
			EXECUTE (@sqlcmd);
			UPDATE #dbcc SET logid = @lognumber WHERE logid IS NULL;
		END TRY
		BEGIN CATCH
			SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
			SELECT @ErrorMessage = 'Errorlog based subsection - Error raised in TRY block 5. ' + ERROR_MESSAGE()
			RAISERROR (@ErrorMessage, 16, 1);
		END CATCH
		SELECT @sqlcmd = 'EXEC master..sp_readerrorlog ' + CONVERT(VARCHAR(3),@lognumber) + ', 1, ''cachestore flush'''
		BEGIN TRY
			INSERT INTO #dbcc (logdate, spid, logmsg) 
			EXECUTE (@sqlcmd);
			UPDATE #dbcc SET logid = @lognumber WHERE logid IS NULL;
		END TRY
		BEGIN CATCH
			SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
			SELECT @ErrorMessage = 'Errorlog based subsection - Error raised in TRY block 6. ' + ERROR_MESSAGE()
			RAISERROR (@ErrorMessage, 16, 1);
		END CATCH
		-- Next log 
		--SET @lognumber = @lognumber + 1 
		SELECT @lognumber = MIN(lognum) FROM #avail_logs WHERE lognum > @lognumber
	END 

	IF (SELECT COUNT([rowid]) FROM #dbcc) > 0
	BEGIN
		--SELECT 'Maintenance_Monitoring_checks' AS [Category], 'Errorlog' AS [Check], '[WARNING: Errorlog contains important messages.]' AS [Deviation];

		;WITH cte_dbcc (err, errcnt, logdate, logmsg) 
			AS (SELECT CASE WHEN logmsg LIKE 'Error: [^a-z]%' THEN RIGHT(LEFT(#dbcc.logmsg, CHARINDEX(',', #dbcc.logmsg)-1), CHARINDEX(',', #dbcc.logmsg)-8) 
					WHEN logmsg LIKE 'SQL Server has encountered % longer than 15 seconds %' THEN CONVERT(CHAR(3),833)
					WHEN logmsg LIKE 'A significant part of sql server process memory has been paged out%' THEN CONVERT(CHAR(5),17890)
					ELSE NULL END AS err,
				COUNT(logmsg) AS errcnt, 
				logdate,
				CASE WHEN logmsg LIKE 'SQL Server has encountered % longer than 15 seconds %' THEN 'SQL Server has encountered XXX occurrence(s) of IO requests taking longer than 15 seconds to complete on file YYY'
					WHEN logmsg LIKE 'A significant part of sql server process memory has been paged out%' THEN 'A significant part of sql server process memory has been paged out.'
					ELSE logmsg END AS logmsg
				FROM #dbcc
				GROUP BY logmsg, logdate
				)	
		SELECT 'Maintenance_Monitoring_checks' AS [Category],'Errorlog_Summary' AS [Information], 
			err AS [Error_Number],
			SUM(errcnt) AS Error_Count, 
			MIN(logdate) AS [First_Logged_Date], 
			MAX(logdate) AS [Last_Logged_Date],
			logmsg AS [Logged_Message],
			CASE WHEN logmsg LIKE 'Error: 825%' THEN 'IO transient failure. Possible corruption'
				WHEN logmsg LIKE 'Error: 833%' OR logmsg LIKE 'SQL Server has encountered % longer than 15 seconds %' THEN 'Long IO detected: http://support.microsoft.com/kb/897284'
				WHEN logmsg LIKE 'Error: 855%' OR logmsg LIKE 'Error: 856%' THEN 'Hardware memory corruption'
				WHEN logmsg LIKE 'Error: 3452%' THEN 'Metadata inconsistency in DB. Run DBCC CHECKIDENT'
				WHEN logmsg LIKE 'Error: 3619%' THEN 'Chkpoint failed. No Log space available'
				WHEN logmsg LIKE 'Error: 9002%' THEN 'No Log space available'
				WHEN logmsg LIKE 'Error: 17204%' OR logmsg LIKE 'Error: 17207%' THEN 'Error opening file during startup process'
				WHEN logmsg LIKE 'Error: 17179%' THEN 'No AWE - LPIM related'
				WHEN logmsg LIKE 'Error: 17890%' THEN 'sqlservr process paged out'
				WHEN logmsg LIKE 'Error: 2508%' THEN 'Catalog views inaccuracies in DB. Run DBCC UPDATEUSAGE'
				WHEN logmsg LIKE 'Error: 2511%' THEN 'Index Keys errors'
				WHEN logmsg LIKE 'Error: 3271%' THEN 'IO nonrecoverable error'
				WHEN logmsg LIKE 'Error: 5228%' OR logmsg LIKE 'Error: 5229%' THEN 'Online Index operation errors'
				WHEN logmsg LIKE 'Error: 5242%' THEN 'Page structural inconsistency'
				WHEN logmsg LIKE 'Error: 5243%' THEN 'In-memory structural inconsistency'
				WHEN logmsg LIKE 'Error: 5250%' THEN 'Corrupt page. Error cannot be fixed'
				WHEN logmsg LIKE 'Error: 5901%' THEN 'Chkpoint failed. Possible corruption'
				WHEN logmsg LIKE 'Error: 17130%' THEN 'No lock memory'
				WHEN logmsg LIKE 'Error: 17300%' THEN 'Unable to run new system task'
				WHEN logmsg LIKE 'Error: 802%' THEN 'No BP memory'
				WHEN logmsg LIKE 'Error: 845%' OR logmsg LIKE 'Error: 1105%' OR logmsg LIKE 'Error: 1121%' THEN 'No disk space available'
				WHEN logmsg LIKE 'Error: 1214%' THEN 'Internal parallelism error'
				WHEN logmsg LIKE 'Error: 823%' OR logmsg LIKE 'Error: 824%' THEN 'IO failure. Possible corruption'
				WHEN logmsg LIKE 'Error: 832%' THEN 'Page checksum error. Possible corruption'
				WHEN logmsg LIKE 'Error: 3624%' OR logmsg LIKE 'Error: 17065%' OR logmsg LIKE 'Error: 17066%' OR logmsg LIKE 'Error: 17067%' THEN 'System assertion check failed. Possible corruption'
				WHEN logmsg LIKE 'Error: 5572%' THEN 'Possible FILESTREAM corruption'
				WHEN logmsg LIKE 'Error: 9100%' THEN 'Possible index corruption'
				-- How To Diagnose and Correct Errors 17883, 17884, 17887, and 17888 (http://technet.microsoft.com/library/cc917684.aspx)
				WHEN logmsg LIKE 'Error: 17883%' THEN 'Non-yielding scheduler: http://technet.microsoft.com/library/cc917684.aspx'
				WHEN logmsg LIKE 'Error: 17884%' OR logmsg LIKE 'Error: 17888%' THEN 'Deadlocked scheduler: http://technet.microsoft.com/library/cc917684.aspx'
				WHEN logmsg LIKE 'Error: 17887%' THEN 'IO completion error: http://technet.microsoft.com/library/cc917684.aspx'
				WHEN logmsg LIKE 'Error: 1205%' THEN 'Deadlocked transaction'
				WHEN logmsg LIKE 'Error: 610%' THEN 'Page header invalid. Possible corruption'
				WHEN logmsg LIKE 'Error: 8621%' THEN 'QP stack overflow during optimization. Please simplify the query'
				WHEN logmsg LIKE 'Error: 8642%' THEN 'QP insufficient threads for parallelism'
				WHEN logmsg LIKE 'Error: 701%' THEN 'Insufficient memory'
				-- How to troubleshoot SQL Server error 8645 (http://support.microsoft.com/kb/309256)
				WHEN logmsg LIKE 'Error: 8645%' THEN 'Insufficient memory: http://support.microsoft.com/kb/309256'
				WHEN logmsg LIKE 'Error: 605%' THEN 'Page retrieval failed. Possible corruption'
				-- How to troubleshoot Msg 5180 (http://support.microsoft.com/kb/2015747)
				WHEN logmsg LIKE 'Error: 5180%' THEN 'Invalid file ID. Possible corruption: http://support.microsoft.com/kb/2015747'
				WHEN logmsg LIKE 'Error: 8966%' THEN 'Unable to read and latch on a PFS or GAM page'
				WHEN logmsg LIKE 'Error: 9001%' OR logmsg LIKE 'Error: 9002%' THEN 'Transaction log errors.'
				WHEN logmsg LIKE 'Error: 9003%' OR logmsg LIKE 'Error: 9004%' OR logmsg LIKE 'Error: 9015%' THEN 'Transaction log errors. Possible corruption'
				-- How to reduce paging of buffer pool memory in the 64-bit version of SQL Server (http://support.microsoft.com/kb/918483)
				WHEN logmsg LIKE 'A significant part of sql server process memory has been paged out%' THEN 'SQL Server process was trimmed by the OS. Preventable if LPIM is granted'
				WHEN logmsg LIKE '%cachestore flush%' THEN 'CacheStore flush'
			ELSE '' END AS [Comment],
			CASE WHEN logmsg LIKE 'Error: [^a-z]%' THEN (SELECT REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(text,'%.*ls','%'),'%d','%'),'%ls','%'),'%S_MSG','%'),'%S_PGID','%'),'%#016I64x','%'),'%p','%'),'%08x','%'),'%u','%'),'%I64d','%'),'%s','%'),'%ld','%'),'%lx','%'), '%%%', '%') 
					FROM sys.messages WHERE message_id = (CONVERT(int, RIGHT(LEFT(cte_dbcc.logmsg, CHARINDEX(',', cte_dbcc.logmsg)-1), CHARINDEX(',', cte_dbcc.logmsg)-8))) AND language_id = @langid) 
				ELSE '' END AS [Look_for_Message_example]
		FROM cte_dbcc
		GROUP BY err, logmsg
		ORDER BY SUM(errcnt) DESC;
	

	END
	ELSE
	BEGIN
		SELECT 'Maintenance_Monitoring_checks' AS [Category], 'Errorlog' AS [Check], '[OK]' AS [Deviation]
	END;
END
--------------------------------------------------------------------------------------------------------------------------------
-- System health error checks subsection
--------------------------------------------------------------------------------------------------------------------------------

IF @sqlmajorver > 10
BEGIN
	RAISERROR (N'  |-Starting System health checks', 10, 1) WITH NOWAIT
	
	IF EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#SystemHealthSessionData'))
	DROP TABLE #SystemHealthSessionData;
	IF NOT EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#SystemHealthSessionData'))
	CREATE TABLE #SystemHealthSessionData (target_data XML)
		
	-- Store the XML data in a temporary table
	INSERT INTO #SystemHealthSessionData
	SELECT CAST(xet.target_data AS XML)
	FROM sys.dm_xe_session_targets xet
	INNER JOIN sys.dm_xe_sessions xe ON xe.address = xet.event_session_address
	WHERE xe.name = 'system_health'
	
	IF (SELECT COUNT(*) FROM #SystemHealthSessionData a WHERE CONVERT(VARCHAR(max), target_data) LIKE '%error_reported%') > 0
	BEGIN
		SELECT 'Maintenance_Monitoring_checks' AS [Category], 'SystemHealth_Errors' AS [Check], '[WARNING: System Health Session contains important messages.]' AS [Deviation];

		-- Get statistical information about all the errors reported
		;WITH cteHealthSession (EventXML) AS (SELECT C.query('.') EventXML
			FROM #SystemHealthSessionData a
			CROSS APPLY a.target_data.nodes('/RingBufferTarget/event') AS T(C)
		),
		cteErrorReported (EventTime, ErrorNumber) AS (SELECT EventXML.value('(/event/@timestamp)[1]', 'datetime') AS EventTime,
			EventXML.value('(/event/data[@name="error_number"]/value)[1]', 'int') AS ErrorNumber
			FROM cteHealthSession
			WHERE EventXML.value('(/event/@name)[1]', 'VARCHAR(500)') = 'error_reported'
		)
		SELECT 'Maintenance_Monitoring_checks' AS [Category], 'SystemHealth_Errors_Summary' AS [Information],
			ErrorNumber AS [Error_Number],
			MIN(EventTime) AS [First_Logged_Date],
			MAX(EventTime) AS [Last_Logged_Date],
			COUNT(ErrorNumber) AS Error_Count,
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(b.text,'%.*ls','%'),'%d','%'),'%ls','%'),'%S_MSG','%'),'%S_PGID','%'),'%#016I64x','%'),'%p','%'),'%08x','%'),'%u','%'),'%I64d','%'),'%s','%'),'%ld','%'),'%lx','%'), '%%%', '%') AS [Look_for_Message_example] 
		FROM cteErrorReported a
		INNER JOIN sys.messages b ON a.ErrorNumber = b.message_id
		WHERE b.language_id = @langid
		GROUP BY a.ErrorNumber, b.[text]
				
		-- Get detailed information about all the errors reported
		;WITH cteHealthSession AS (SELECT C.query('.').value('(/event/@timestamp)[1]', 'datetime') AS EventTime,
			C.query('.').value('(/event/data[@name="error_number"]/value)[1]', 'int') AS ErrorNumber,
			C.query('.').value('(/event/data[@name="severity"]/value)[1]', 'int') AS ErrorSeverity,
			C.query('.').value('(/event/data[@name="state"]/value)[1]', 'int') AS ErrorState,
			C.query('.').value('(/event/data[@name="message"]/value)[1]', 'VARCHAR(MAX)') AS ErrorText,
			C.query('.').value('(/event/action[@name="session_id"]/value)[1]', 'int') AS SessionID,
			C.query('.').value('(/event/data[@name="category"]/text)[1]', 'VARCHAR(10)') AS ErrorCategory
			FROM #SystemHealthSessionData a
			CROSS APPLY a.target_data.nodes('/RingBufferTarget/event') AS T(C)
			WHERE C.query('.').value('(/event/@name)[1]', 'VARCHAR(500)') = 'error_reported')
		SELECT 'Maintenance_Monitoring_checks' AS [Category], 'SystemHealth_Errors_Detail' AS [Information], 
			EventTime AS [Logged_Date],
			ErrorNumber AS [Error_Number],
			ErrorSeverity AS [Error_Sev],
			ErrorState AS [Error_State],
			ErrorText AS [Logged_Message],
			SessionID
		FROM cteHealthSession
		ORDER BY EventTime
	END
	ELSE
	BEGIN
		SELECT 'Maintenance_Monitoring_checks' AS [Category], 'SystemHealth_Errors' AS [Check], '[OK]' AS [Deviation]
	END;
END;
