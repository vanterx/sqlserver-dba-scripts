/*
declare @rc int
declare @TraceID int
declare @maxfilesize bigint
set @maxfilesize = 1024

DECLARE @TraceFileName nvarchar(256)
SELECT @TraceFileName ='C:\_temp\Replay_' + REPLACE(REPLACE(convert(nvarchar(20),GetDate(),120),':','-'),' ','_')

exec @rc = sp_trace_create @TraceID output, 0, @TraceFileName , @maxfilesize, NULL 
if (@rc != 0) goto error


--List all SQL Traces 
SELECT * FROM sys.traces

--To stop an individual trace running in SQL Server.

EXEC sp_trace_setstatus [ @traceid = ] trace_id , [ @status = ] status  
/*
EXEC sp_trace_setstatus 2,0

0 = Stop Trace
1 = Start Trace
2 = Close/Delete Trace
*/

*/
