DECLARE @name VARCHAR(500)

CREATE TABLE #DirTree (
	id INT IDENTITY(1, 1)
	,subdirectory NVARCHAR(512)
	,depth INT
	,isfile BIT
	);

CREATE TABLE #trace (
	[EventClass] [int] NULL
	,[EventName] [nvarchar](128) NULL
	,[TextData] [ntext] NULL
	,[ObjectID] [int] NULL
	,[ObjectName] [nvarchar](256) NULL
	,[DatabaseName] [nvarchar](256) NULL
	,[SessionLoginName] [nvarchar](256) NULL
	,[StartTime] [datetime] NULL
	,[ApplicationName] [nvarchar](256) NULL
	,[HostName] [nvarchar](256) NULL
	,[NTUserName] [nvarchar](256) NULL
	,[NTDomainName] [nvarchar](256) NULL
	);

DECLARE @path NVARCHAR(260)

SELECT @path = LEFT(path, Len(path) - Charindex('\', Reverse(path)))
FROM sys.traces
WHERE is_default = 1

INSERT #DirTree (
	subdirectory
	,depth
	,isfile
	)
EXEC master.sys.xp_dirtree @path
	,1
	,1;

DECLARE db_cursor CURSOR
FOR
SELECT @path + '\' + subdirectory
FROM #DirTree
WHERE [isfile] = 1
	AND subdirectory LIKE '%.trc'

OPEN db_cursor

FETCH NEXT
FROM db_cursor
INTO @name

WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT INTO #trace
	SELECT gt.EventClass
		,e.name AS EventName
		,gt.TextData
		,gt.ObjectID
		,gt.ObjectName
		,gt.DatabaseName
		,gt.SessionLoginName
		,gt.StartTime
		,gt.ApplicationName
		,gt.HostName
		,gt.NTUserName
		,gt.NTDomainName
	FROM sys.fn_trace_gettable(@name, DEFAULT) AS gt
	JOIN sys.trace_events e ON gt.EventClass = e.trace_event_id
	ORDER BY gt.StartTime DESC

	FETCH NEXT
	FROM db_cursor
	INTO @name
END

CLOSE db_cursor

DEALLOCATE db_cursor

SELECT *
FROM #trace

DROP TABLE #DirTree

DROP TABLE #trace
