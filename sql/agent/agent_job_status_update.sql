-- uses sp_help_jobactivity which gets info from sysjobservers
select j.name,s.last_run_outcome
,replace(replace('UPDATE msdb..sysjobservers set last_run_outcome=1 where job_id=''$jobid'' -- $jobname','$jobid',s.job_id),'$jobname',j.name)
from msdb..sysjobs j
join msdb..sysjobservers s on j.job_id=s.job_id
where s.last_run_outcome=0


-- sysjobhistory table
;with cte as (
	select j.name,n=ROW_NUMBER() over (partition by h.job_id order by h.instance_id desc)
	, h.instance_id,h.run_status
	from msdb..sysjobhistory h
	join msdb..sysjobs j on j.job_id=h.job_id
	where h.step_id=0)
select *,cmd='update msdb..sysjobhistory set run_status=1 where instance_id='+convert(varchar(100),instance_id)+' -- '+name
from cte where n=1
and run_status=0
