--EXEC sp_change_users_login 'REPORT'

--EXEC sp_change_users_login 'Update_One', 'DB_Username', 'Login_Username'

--EXEC sp_change_users_login 'Auto_Fix', 'user'

--EXEC sp_change_users_login 'Auto_Fix', 'user', 'login', 'password'

--EXEC sp_changedbowner 'sa'

DECLARE @command varchar(1000) 
SELECT @command = 'USE [?] SELECT DB_NAME(); EXEC sp_change_users_login ''REPORT''' 
EXEC sp_MSforeachdb @command 
