---- Backup To URL (using SAS Token) :
--- =================================== --- 
DECLARE @TSQL AS NVARCHAR(MAX)
    ,@ContainerName AS NVARCHAR(MAX)
    ,@StorageAccountName AS VARCHAR(MAX)
    ,@SASKey AS VARCHAR(MAX);
SELECT @StorageAccountName = ''; --- Find this from Azure Portal
SELECT @ContainerName = ''; --- Find this from Azure Portal
SELECT @SASKey = '?sv='; --- Find this from Azure Portal
IF NOT EXISTS (
        SELECT *
        FROM sys.credentials
        WHERE name = '''https://' + @StorageAccountName + '.blob.core.windows.net/' + @ContainerName + ''''
        )
BEGIN
    SELECT @TSQL = 'CREATE CREDENTIAL [https://' + @StorageAccountName + '.blob.core.windows.net/' + @ContainerName + '] WITH IDENTITY = ''SHARED ACCESS SIGNATURE'', SECRET = ''' + REPLACE(@SASKey, '?sv=', 'sv=') + ''';'
    PRINT @TSQL;
END
