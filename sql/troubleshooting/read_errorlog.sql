IF OBJECT_ID('tempdb..#enumlog') IS NOT NULL 
    DROP TABLE #enumlog ;
IF OBJECT_ID('tempdb..#elog') IS NOT NULL 
    DROP TABLE #elog ;
 
DECLARE @ArchiveNo int ; 
DECLARE @interval_type int = 0; -- 0 : Day \ 1 : Hr
DECLARE @interval int=1;
DECLARE @logtime datetime ;

IF @interval_type =0 
BEGIN
SET @logtime = Convert(DateTime, DATEDIFF(DAY, @interval, GETDATE()))
END
ELSE
BEGIN
SET @logtime = Convert(DateTime,DATEADD(HOUR, -@interval, GETDATE()))
END

CREATE TABLE #enumlog  (ArchiveNo int, TheDate datetime, SizeByte bigint)
CREATE TABLE #elog (LogDate datetime, ProcessInfo varchar(10),TheText nVarchar(2000), ln int identity(1,1))
PRINT  @logtime;

INSERT INTO #enumlog EXEC xp_enumerrorlogs

DECLARE db_cursor CURSOR FOR 
select ArchiveNo from #enumlog
where TheDate > =  @logtime -- round off to midnight
ORDER BY ArchiveNo DESC


OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @ArchiveNo  

WHILE @@FETCH_STATUS = 0  
BEGIN  

     INSERT INTO #elog EXEC sp_readerrorlog @ArchiveNo,1

      FETCH NEXT FROM db_cursor INTO @ArchiveNo
END 

CLOSE db_cursor  
DEALLOCATE db_cursor 

DELETE from #elog
WHERE LogDate < =  @logtime

SELECT * from #elog
ORDER BY LogDate DESC;
