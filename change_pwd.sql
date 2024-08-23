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

INSERT INTO #ACC_PWD_CHANGE_HISTORY (date_time, login_name, action, ErrorMessage)
VALUES 
(GETDATE (), 'SQLDBA', 'CHANDGE PWD [SQLDBA]', 'INITIATION'),
(GETDATE (), 'SQLDBATest', 'CHANDGE PWD [SQLDBATest]', 'INITIATION'),
(GETDATE (), 'sa', 'DISABLE [sa]', 'INITIATION')

IF @prom_name IS NULL
       UPDATE #ACC_PWD_CHANGE_HISTORY SET date_time = GETDATE (), ErrorMessage = 'SKIPPED: Login ''SQLDBA'' does not exist' WHERE UPPER (login_name) = 'SQLDBA';
ELSE
       BEGIN TRY
             EXEC ('ALTER LOGIN ' + @prom_name + ' WITH PASSWORD = 0x<hash> HASHED, NAME = [SQLDBA], DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF')
             GRANT CONNECT SQL TO [SQLDBA]
             ALTER LOGIN [SQLDBA] ENABLE
             ALTER SERVER ROLE [sysadmin] ADD MEMBER [SQLDBA]
             UPDATE #ACC_PWD_CHANGE_HISTORY SET date_time = GETDATE (), ErrorMessage = 'SUCCESS: ' + ERROR_MESSAGE()     WHERE UPPER (login_name) =  UPPER (@prom_name); 
       END TRY  

       BEGIN CATCH
             UPDATE #ACC_PWD_CHANGE_HISTORY SET date_time = GETDATE (), ErrorMessage = 'ERROR: ' + ERROR_MESSAGE() WHERE UPPER (login_name) =  UPPER (@prom_name); 
       END CATCH;

IF @test_name IS NULL 
       UPDATE #ACC_PWD_CHANGE_HISTORY SET date_time = GETDATE (), ErrorMessage = 'SKIPPED: Login ''SQLDBATEST'' does not exist' WHERE UPPER (login_name) = 'SQLDBATEST';
ELSE
       BEGIN TRY
             EXEC ('ALTER LOGIN ' + @test_name + ' WITH PASSWORD = 0x<hash> HASHED, NAME = [SQLDBATest], DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF')
             GRANT CONNECT SQL TO [SQLDBATest]
             ALTER LOGIN [SQLDBATest] ENABLE
             ALTER SERVER ROLE [sysadmin] ADD MEMBER [SQLDBATest]
             UPDATE #ACC_PWD_CHANGE_HISTORY SET date_time = GETDATE (), ErrorMessage = 'SUCCESS: ' + ERROR_MESSAGE() WHERE UPPER (login_name) =  UPPER (@test_name); 
       END TRY  

       BEGIN CATCH  
             UPDATE #ACC_PWD_CHANGE_HISTORY SET date_time = GETDATE (), ErrorMessage = 'ERROR: ' + ERROR_MESSAGE() WHERE UPPER (login_name) =  UPPER (@test_name); 
       END CATCH;  

IF (SELECT [is_disabled] FROM master.sys.server_principals WHERE LOWER (name) = 'sa') = 1
       UPDATE #ACC_PWD_CHANGE_HISTORY SET date_time = GETDATE (), ErrorMessage = 'SKIPPED: Login ''sa'' is disabled' WHERE LOWER (login_name) = 'sa'
ELSE
       BEGIN TRY
             ALTER LOGIN [sa] DISABLE
             UPDATE #ACC_PWD_CHANGE_HISTORY SET date_time = GETDATE (), ErrorMessage = 'SUCCESS: ' + ERROR_MESSAGE() WHERE LOWER (login_name) = 'sa'
       END TRY  

       BEGIN CATCH
             UPDATE #ACC_PWD_CHANGE_HISTORY SET date_time = GETDATE (), ErrorMessage = 'ERROR' + ERROR_MESSAGE() WHERE LOWER (login_name) = 'sa'
       END CATCH;

UPDATE #ACC_PWD_CHANGE_HISTORY
SET
[server_name] = SERVERPROPERTY('SERVERNAME'),
[collation] = SERVERPROPERTY('COLLATION')

UPDATE tt
SET
tt.[login_name] = sp.[name],
tt.[create_date] = sp.[create_date], 
tt.[modify_date] = sp.[modify_date]
FROM master.sys.server_principals AS sp
JOIN #ACC_PWD_CHANGE_HISTORY AS tt ON sp.[name] = tt.[login_name]
WHERE LOWER(tt.[login_name]) IN ('zabbix_mssql', 'zabbix_mssql_ts', 'sqldba', 'sqldbatest', 'sa')

SELECT * FROM UPDATE #ACC_PWD_CHANGE_HISTORY
