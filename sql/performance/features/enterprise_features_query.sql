    IF OBJECT_ID('tempdb.dbo.##enterprise_features') IS NOT NULL
      DROP TABLE ##enterprise_features
     
    CREATE TABLE ##enterprise_features
      (
         dbname       SYSNAME,
         feature_name VARCHAR(100),
         feature_id   INT
      )
     
    EXEC sp_msforeachdb
    N' USE [?] 
    IF (SELECT COUNT(*) FROM sys.dm_db_persisted_sku_features) >0 
    BEGIN 
       INSERT INTO ##enterprise_features 
        SELECT dbname=DB_NAME(),feature_name,feature_id 
        FROM sys.dm_db_persisted_sku_features 
    END '
    SELECT *
    FROM   ##enterprise_features 
    
   ----------------------------------
   
   -- Check Version and Build and Save the Output
SELECT @@VERSION [Version]
 
-- Check Instance Name and Save the Output
SELECT @@SERVICENAME
 
-- Check Version and Build and Save the Output
SELECT CONVERT (varchar, SERVERPROPERTY('collation')) AS 'Server Collation';
 
-- Check Version and Build and Save the Output
SELECT * FROM sys.configurations
WHERE name LIKE '%stream%'
 
-- List current file location of all databases and Save the Output
SELECT name, physical_name AS current_file_location
FROM sys.master_files
WHERE database_id != 2
 
-- Infoimation about SQL Server Services Accounts and Save the Output
SELECT servicename, process_id, startup_type_desc, status_desc,
last_startup_time, service_account, is_clustered, cluster_nodename, [filename]
FROM sys.dm_server_services WITH (NOLOCK) OPTION (RECOMPILE);
 
-- Check Certifications and Keys and save backup
SELECT * FROM sys.asymmetric_keys
SELECT * FROM sys.certificates
SELECT * FROM sys.column_encryption_keys -- Since SQL Server 2016
SELECT * FROM sys.column_encryption_key_values -- Since SQL Server 2016
SELECT * FROM sys.column_master_keys -- Since SQL Server 2016
SELECT * FROM sys.crypt_properties
SELECT * FROM sys.cryptographic_providers
SELECT * FROM sys.dm_database_encryption_keys
SELECT * FROM sys.key_encryptions
SELECT * FROM sys.openkeys
SELECT * FROM sys.security_policies -- Since SQL Server 2016
SELECT * FROM sys.symmetric_keys
 
USE [master]
GO
SELECT D.name AS 'Database Name'
,c.name AS 'Cert Name'
,E.encryptor_type AS 'Type'
,CASE
 WHEN E.encryption_state = 3 THEN 'Encrypted'
 WHEN E.encryption_state = 2 THEN 'In Progress'
 ELSE 'Not Encrypted'
end as state,
E.encryption_state, E.percent_complete, E.key_algorithm, E.key_length, E.* FROM sys.dm_database_encryption_keys E
right join sys.databases D on D.database_id = E.database_id
left join sys.certificates c ON E.encryptor_thumbprint=c.thumbprint
 

-- Select port number and Save the Output
SELECT DISTINCT local_tcp_port
FROM sys.dm_exec_connections
WHERE local_tcp_port IS NOT NULL

