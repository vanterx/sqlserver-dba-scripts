set nocount on
declare @jobname sysname = '_AdhocBkp'
declare @recipients varchar(max) =
'email@emai.com'

declare @last_email datetime, @send_email bit, @msg varchar(max), @subject varchar(200)
declare @percent_completed numeric(4,1), @min_remaining int, @eta datetime, @progress int
declare @jobid uniqueidentifier, @binjobid varchar(34) -- job id as it appears in program_name

select @jobid = job_id, @binjobid = convert(varchar(34),convert(binary(16),job_id),1)
from msdb..sysjobs where name = @jobname

set @progress = 0
while exists (-- the job is still running
	select 1
	from msdb..sysjobactivity a
	where a.run_requested_date is not null and a.stop_execution_date is null
	and a.session_id = (select top 1 session_id from msdb..syssessions order by agent_start_date desc)
	and a.job_id = @jobid
)
begin
waitfor delay '00:01:00'
--get ETA and %complete
select @percent_completed = r.percent_complete
, @min_remaining = estimated_completion_time/60000
, @eta = dateadd(MS,estimated_completion_time,GETDATE())
from sys.dm_exec_requests r
join sys.dm_exec_sessions s on r.session_id=s.session_id
where s.program_name like 'SQLAgent%'+@binjobid+'%'
set @msg = replace(replace(replace(replace('The backup is $percent% complete.\nETA is about $ETA ($remaining min)\n\n', '\n',char(13)+char(10))
	,'$percent',convert(varchar(10),@percent_completed) )
	,'$ETA',convert(varchar(5),@eta,108) )
	,'$remaining',convert(varchar(100),@min_remaining) )
set @subject = '- Backup Progress - '+convert(varchar(10),@percent_completed)+'%'

set @send_email = 0
if (@percent_completed >= 10.0 and @percent_completed < 50.0) and @progress < 10 select @send_email = 1, @progress=10
if (@percent_completed >= 50.0 and @percent_completed < 80.0) and @progress < 50 select @send_email = 1, @progress=50
if (@percent_completed >= 80.0 and @percent_completed < 95.0) and @progress < 80 select @send_email = 1, @progress=80
if (@percent_completed >= 95.0 and @percent_completed < 100.0) and @progress < 95 select @send_email = 1, @progress=95
--debug 
--print convert(varchar,getdate(),120)+' | progress = '+convert(varchar,@progress)+'; percent = '+convert(varchar(10),@percent_completed)+'%; send_email = '+convert(varchar,@send_email)+'; @last_email = '+coalesce(convert(varchar,@last_email,120),'NULL')+'; datediff = '+coalesce(convert(varchar,DATEDIFF(second,@last_email,getdate())),'NULL')
if @send_email = 1
	if @last_email is null or DATEDIFF(second,@last_email,getdate())>600 -- don't send more often than 10 min
	begin
		EXEC msdb.dbo.sp_send_dbmail 
			@recipients = @recipients
			,@subject = @subject
			,@body = @msg
		set @last_email = getdate()
	end
end -- while loop

-- send email that the job is done.
declare @run_datetime datetime, @duration time, @run_status int, @NL char(2)=char(13)+char(10)

SELECT @run_status=last_run_outcome
,@run_datetime = convert(datetime,convert(varchar(20),last_run_date)+' '+stuff(stuff(right('000000'+convert(varchar(20),last_run_time),6),5,0,':'),3,0,':'))
,@duration = convert(time,stuff(stuff(right('000000'+convert(varchar(20),last_run_duration),6),5,0,':'),3,0,':'))
,@msg = last_outcome_message
FROM  msdb.dbo.sysjobservers
WHERE job_id = @jobid

SELECT  @msg=''
 + 'JOB RUN:	'''+@jobname+''' was run on '+format(@run_datetime,'d/MM/yyyy a\t h:mm:ss tt') +@NL
 + 'DURATION:	' +convert(varchar(2),datepart(hour,@duration))+' hours, '+convert(varchar(2),datepart(MINUTE,@duration))+' minutes, '+convert(varchar(2),datepart(SECOND,@duration))+' seconds'+ @NL
 + 'STATUS: 	' + case @run_status 
	when 0 then 'Failed' 
	when 1 then 'Succeeded' 
	when 2 then 'Retry' 
	when 3 then 'Canceled' 
	else '??' end + @NL
 + 'MESSAGES:	' + @msg

SELECT @subject='[The job '+case when @run_status=1 then 'succeeded' else 'failed' end+'.] SQL Server Job System: '''+@jobname+''' completed on \\'+@@SERVERNAME+'.'

if @msg <> '' 
begin
	exec msdb.dbo.sp_send_dbmail
	@recipients=@recipients,
	@subject=@subject,
	@body=@msg
end
