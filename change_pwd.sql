SET NOCOUNT ON;

USE [master]
GO

DROP TABLE IF EXISTS #ACC_PWD_CHANGE_HISTORY ;
CREATE TABLE #ACC_PWD_CHANGE_HISTORY
(
date_time DATETIME,
server_name SQL_VARIANT,
collation SQL_VARIANT,
login_name SYSNAME NULL,
create_date DATETIME,
modify_date DATETIME,
action NVARCHAR(400),
ErrorMessage NVARCHAR(4000)
);

DECLARE @prom_name SYSNAME
DECLARE @test_name SYSNAME
DECLARE @is_sa_enabled INT
SELECT @prom_name = [name] FROM master.sys.server_principals WHERE UPPER (name) = 'SQLDBA'
SELECT @test_name = [name] FROM master.sys.server_principals WHERE UPPER (name) = 'SQLDBATEST'
SELECT @is_sa_enabled = [is_disabled] FROM master.sys.server_principals WHERE LOWER (name) = 'sa'

IF @prom_name IS NULL 
	INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, server_name, collation, login_name, create_date, modify_date, action, ErrorMessage)
	SELECT GETDATE (), SERVERPROPERTY('SERVERNAME'), SERVERPROPERTY('COLLATION'), 'SQLDBA', NULL, NULL, 'CHANDGE PWD [SQLDBA]', 'SKIPPED: Login ''SQLDBA'' does not exist'
ELSE
BEGIN TRY
	EXEC ('ALTER LOGIN ' + @prom_name + ' WITH PASSWORD = 0x<hash> HASHED, NAME = [SQLDBA], DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF')
	GRANT CONNECT SQL TO [SQLDBA]
	ALTER LOGIN [SQLDBA] ENABLE
	ALTER SERVER ROLE [sysadmin] ADD MEMBER [SQLDBA]
	INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, server_name, collation, login_name, create_date, modify_date, action, ErrorMessage)
	SELECT GETDATE (), SERVERPROPERTY('SERVERNAME'), SERVERPROPERTY('COLLATION'), [name], [create_date], [modify_date], 'CHANDGE PWD [SQLDBA]', 'SUCCESS: ' + ERROR_MESSAGE() AS ErrorMessage
	FROM master.sys.server_principals
	WHERE UPPER (name) =  UPPER (@prom_name); 
END TRY  

BEGIN CATCH  
	IF @prom_name IS NULL SET @prom_name = 'SQLDBA'
	INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, server_name, collation, login_name, create_date, modify_date, action, ErrorMessage)
	SELECT GETDATE (), SERVERPROPERTY('SERVERNAME'), SERVERPROPERTY('COLLATION'), @prom_name, [create_date], [modify_date], 'CHANDGE PWD [SQLDBA]', 'ERROR: ' + ERROR_MESSAGE() AS ErrorMessage
	FROM master.sys.server_principals
	WHERE UPPER (name) =  UPPER (@prom_name); 
END CATCH;

IF @test_name IS NULL 
	INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, server_name, collation, login_name, create_date, modify_date, action, ErrorMessage)
	SELECT GETDATE (), SERVERPROPERTY('SERVERNAME'), SERVERPROPERTY('COLLATION'), 'SQLDBATEST', NULL, NULL, 'CHANDGE PWD [SQLDBATest]', 'SKIPPED: Login ''SQLDBATEST'' does not exist'
ELSE
BEGIN TRY
	EXEC ('ALTER LOGIN ' + @test_name + ' WITH PASSWORD = 0x<hash> HASHED, NAME = [SQLDBATest], DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF')
	GRANT CONNECT SQL TO [SQLDBATest]
	ALTER LOGIN [SQLDBATest] ENABLE
	ALTER SERVER ROLE [sysadmin] ADD MEMBER [SQLDBATest]
	INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, server_name, collation, login_name, create_date, modify_date, action, ErrorMessage)
	SELECT GETDATE (), SERVERPROPERTY('SERVERNAME'), SERVERPROPERTY('COLLATION'), [name], [create_date], [modify_date], 'CHANDGE PWD [SQLDBATest]', 'SUCCESS: ' + ERROR_MESSAGE() AS ErrorMessage
	FROM master.sys.server_principals
	WHERE UPPER (name) =  UPPER (@test_name); 
END TRY  

BEGIN CATCH  
	IF @test_name IS NULL SET @test_name = 'SQLDBATEST'
	INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, server_name, collation, login_name, create_date, modify_date, action, ErrorMessage)
	SELECT GETDATE (), SERVERPROPERTY('SERVERNAME'), SERVERPROPERTY('COLLATION'), @test_name , [create_date], [modify_date], 'CHANDGE PWD [SQLDBATest]', 'ERROR: ' + ERROR_MESSAGE() AS ErrorMessage
	FROM master.sys.server_principals
	WHERE UPPER (name) =  UPPER (@test_name); 
END CATCH;  

IF (SELECT [is_disabled] FROM master.sys.server_principals WHERE LOWER (name) = 'sa') = 1
	INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, server_name, collation, login_name, create_date, modify_date, action, ErrorMessage)
	SELECT GETDATE (), SERVERPROPERTY('SERVERNAME'), SERVERPROPERTY('COLLATION'), 'sa', [create_date], [modify_date], 'DISABLE [sa]', 'SKIPPED: Login ''sa'' is disabled'
	FROM master.sys.server_principals
	WHERE LOWER (name) = 'sa'
ELSE
BEGIN TRY
ALTER LOGIN [sa] DISABLE
	INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, server_name, collation, login_name, create_date, modify_date, action, ErrorMessage)
	SELECT GETDATE (), SERVERPROPERTY('SERVERNAME'), SERVERPROPERTY('COLLATION'), [name], [create_date], [modify_date], 'DISABLE [sa]', 'SUCCESS: ' + ERROR_MESSAGE() AS ErrorMessage
	FROM master.sys.server_principals
	WHERE LOWER (name) = 'sa'
END TRY  

BEGIN CATCH  
	INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, server_name, collation, login_name, create_date, modify_date, action, ErrorMessage)
	SELECT GETDATE (), SERVERPROPERTY('SERVERNAME'), SERVERPROPERTY('COLLATION'), [name], [create_date], [modify_date], 'DISABLE [sa]', 'ERROR' + ERROR_MESSAGE() AS ErrorMessage
	FROM master.sys.server_principals
	WHERE UPPER (name) =  UPPER ('sa'); 
END CATCH;

SELECT * FROM #ACC_PWD_CHANGE_HISTORY
