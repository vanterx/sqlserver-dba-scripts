PRINT '-> dm_os_server_diagnostics_log_configurations'

SELECT *
FROM sys.dm_os_server_diagnostics_log_configurations

SET QUOTED_IDENTIFIER ON

DECLARE @hours INT=NULL;
DECLARE @timeStr NVARCHAR(50) = CAST(SYSDATETIMEOFFSET() AS NVARCHAR(50));
DECLARE @timeDiff INT = (
		SELECT CAST(REPLACE(REPLACE(RIGHT(@timeStr, 6), '+', ''), ':00', '') AS INT)
		);

PRINT @timeDiff;

DECLARE @XELFile VARCHAR(256)

SELECT @XELFile = path + 'AlwaysOn_health*.xel'
FROM sys.dm_os_server_diagnostics_log_configurations

--read the AOHealth*.xel files into the table
SELECT cast(event_data AS XML) AS EventData
INTO #AOHealth
FROM sys.fn_xe_file_target_read_file(@XELFile, NULL, NULL, NULL);

PRINT ''
PRINT '==========================='
PRINT 'AlwaysOn_health DDL Events'
PRINT '==========================='

SELECT DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) AS [timestamp],
	--EventData.value('(event/@timestamp)[1]', 'datetime') AS TimeStampUTC,
	EventData.value('(event/data/text)[1]', 'varchar(10)') AS DDLAction
	,EventData.value('(event/data/text)[2]', 'varchar(10)') AS DDLPhase
	,EventData.value('(event/data/value)[5]', 'varchar(20)') AS AGName
	,CAST(REPLACE(REPLACE(EventData.value('(event/data/value)[3]', 'varchar(max)'), CHAR(10), ''), CHAR(13), '') AS VARCHAR(60)) AS DDLStatement
FROM #AOHealth
WHERE EventData.value('(event/@name)[1]', 'varchar(max)') = 'alwayson_ddl_executed'
	AND UPPER(EventData.value('(event/data/value)[3]', 'varchar(60)')) NOT LIKE '%FAILOVER%'
	AND DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) >= dateadd(hour,-ISNULL(@hours,24),getdate())
ORDER BY EventData.value('(event/@timestamp)[1]', 'datetime');

PRINT ''
PRINT '============================='
PRINT 'AlwaysOn_health DDL FAILOVERS'
PRINT '============================='

SELECT DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) AS [timestamp],
	--EventData.value('(event/@timestamp)[1]', 'datetime') AS TimeStampUTC,
	EventData.value('(event/data/text)[1]', 'varchar(10)') AS DDLAction
	,EventData.value('(event/data/text)[2]', 'varchar(10)') AS DDLPhase
	,EventData.value('(event/data/value)[5]', 'varchar(20)') AS AGName
	,CAST(REPLACE(REPLACE(EventData.value('(event/data/value)[3]', 'varchar(max)'), CHAR(10), ''), CHAR(13), '') AS VARCHAR(60)) AS DDLStatement
FROM #AOHealth
WHERE EventData.value('(event/@name)[1]', 'varchar(max)') = 'alwayson_ddl_executed'
	AND UPPER(EventData.value('(event/data/value)[3]', 'varchar(60)')) LIKE '%FAILOVER%'
	AND DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) >= dateadd(hour,-ISNULL(@hours,24),getdate())
ORDER BY EventData.value('(event/@timestamp)[1]', 'datetime');

PRINT ''
PRINT '=========================================='
PRINT 'AlwaysOn_health AR MGR State Change Events'
PRINT '=========================================='

SELECT DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) AS [timestamp],
	--EventData.value('(event/@timestamp)[1]', 'datetime') AS TimeStampUTC,
	EventData.value('(event/data/text)[1]', 'varchar(30)') AS CurrentStateDesc
FROM #AOHealth
WHERE EventData.value('(event/@name)[1]', 'varchar(max)') = 'availability_replica_manager_state_change'
	AND DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) >= dateadd(hour, - ISNULL(@hours, 24), getdate())
ORDER BY EventData.value('(event/@timestamp)[1]', 'datetime');


PRINT ''
PRINT '======================================'
PRINT 'AlwaysOn_health AR State Change Events'
PRINT '======================================'

SELECT DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) AS [timestamp],
	--EventData.value('(event/@timestamp)[1]', 'datetime') AS TimeStampUTC,
	EventData.value('(event/data/value)[4]', 'varchar(20)') AS AGName
	,EventData.value('(event/data/text)[1]', 'varchar(30)') AS PrevStateDesc
	,EventData.value('(event/data/text)[2]', 'varchar(30)') AS CurrentStateDesc
FROM #AOHealth
WHERE EventData.value('(event/@name)[1]', 'varchar(max)') = 'availability_replica_state_change'
	AND DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) >= dateadd(hour, - ISNULL(@hours, 24), getdate())
ORDER BY EventData.value('(event/@timestamp)[1]', 'datetime');


PRINT ''
PRINT '======================================'
PRINT 'Lease Expiration Events'
PRINT '======================================'

SELECT DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) AS [timestamp],
	--EventData.value('(event/@timestamp)[1]', 'datetime') AS TimeStampUTC,
	EventData.value('(event/data/value)[2]', 'varchar(max)') AS AGName
	,EventData.value('(event/data/value)[1]', 'varchar(max)') AS AG_ID
FROM #AOHealth
WHERE EventData.value('(event/@name)[1]', 'varchar(max)') = 'availability_group_lease_expired'
	AND DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) >= dateadd(hour, - ISNULL(@hours, 24), getdate())
ORDER BY EventData.value('(event/@timestamp)[1]', 'datetime');


PRINT ''
PRINT '======================================'
PRINT 'Error events'
PRINT '======================================'

SELECT DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) AS [timestamp],
	--EventData.value('(event/@timestamp)[1]', 'datetime') AS TimeStampUTC,
	EventData.value('(event/data/value)[1]', 'int') AS ErrorNum
	,EventData.value('(event/data/value)[2]', 'int') AS Severity
	,EventData.value('(event/data/value)[3]', 'int') AS STATE
	,EventData.value('(event/data/value)[4]', 'varchar(max)') AS UserDefined
	,EventData.value('(event/data/text)[5]', 'varchar(max)') AS Category
	,EventData.value('(event/data/text)[6]', 'varchar(max)') AS DestinationLog
	,EventData.value('(event/data/value)[7]', 'varchar(max)') AS IsIntercepted
	,EventData.value('(event/data/value)[8]', 'varchar(max)') AS ErrMessage
INTO #error_reported
FROM #AOHealth
WHERE EventData.value('(event/@name)[1]', 'varchar(max)') = 'error_reported'
	AND DATEADD(hour, @timeDiff, EventData.value('(event/@timestamp)[1]', 'datetime')) >= dateadd(hour, - ISNULL(@hours, 24), getdate());


--display results from "error_reported" event data
WITH ErrorCTE (
	ErrorNum
	,ErrorCount
	,FirstDate
	,LastDate
	)
AS (
	SELECT ErrorNum
		,Count(ErrorNum)
		,min([timestamp])
		,max([timestamp]) AS ErrorCount
		--,min(TimeStampUTC)
		--,max(TimeStampUTC) AS ErrorCount
	FROM #error_reported
	GROUP BY ErrorNum
	)
SELECT CAST(ErrorNum AS CHAR(10)) ErrorNum
	,CAST(ErrorCount AS CHAR(10)) ErrorCount
	,CONVERT(CHAR(25), FirstDate, 121) FirstDate
	,CONVERT(CHAR(25), LastDate, 121) LastDate
	,CAST(CASE ErrorNum
			WHEN 35202
				THEN 'A connection for availability group ... has been successfully established...'
			WHEN 1480
				THEN 'The * database * is changing roles ... because the AG failed over ...'
			WHEN 35206
				THEN 'A connection timeout has occurred on a previously established connection ...'
			WHEN 35201
				THEN 'A connection timeout has occurred while attempting to establish a connection ...'
			WHEN 41050
				THEN 'Waiting for local WSFC service to start.'
			WHEN 41051
				THEN 'Local WSFC service started.'
			WHEN 41052
				THEN 'Waiting for local WSFC node to start.'
			WHEN 41053
				THEN 'Local WSFC node started.'
			WHEN 41054
				THEN 'Waiting for local WSFC node to come online.'
			WHEN 41055
				THEN 'Local WSFC node is online.'
			WHEN 41048
				THEN 'Local WSFC service has become unavailable.'
			WHEN 41049
				THEN 'Local WSFC node is no longer online.'
			ELSE m.[text]
			END AS VARCHAR(81)) [Abbreviated Message]
FROM ErrorCTE ec
LEFT JOIN sys.messages m ON ec.ErrorNum = m.message_id
	AND m.language_id = 1033

ORDER BY CAST(ErrorCount AS INT) DESC;

DROP TABLE #AOHealth

DROP TABLE #error_reported
