USE master
GO

SELECT DISTINCT (request_owner_guid) AS uow_guid
	,dtl.[request_session_id]
	,db_name(syp.dbid) dbname
	,syp.[loginame]
	,syp.[hostname]
	,syp.[status]
	,syp.program_name
	,(SELECT [text]
	  FROM sys.dm_exec_sql_text(syp.sql_handle)
	  ) AS querytext
	,syp.[lastwaittype]
	,syp.[cpu]
	,syp.[memusage]
	,syp.[physical_io]
FROM sys.dm_tran_locks dtl
INNER JOIN sys.sysprocesses syp ON dtl.request_session_id = syp.spid
WHERE request_owner_guid <> '00000000-0000-0000-0000-000000000000'
GO
