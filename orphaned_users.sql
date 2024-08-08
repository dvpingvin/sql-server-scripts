USE [master]
GO
 
DECLARE @db_name SYSNAME
DECLARE @query NVARCHAR(MAX)
 
DROP TABLE IF EXISTS #t
CREATE TABLE #t ([db_name] SYSNAME, [result] NVARCHAR(4000) )
INSERT INTO #t ([db_name]) SELECT [name] FROM sys.databases WHERE database_id > 0;

DROP TABLE IF EXISTS #orphaned_users
CREATE TABLE #orphaned_users([db_name] SYSNAME, [type_desc]  NVARCHAR(60), [sid] VARBINARY(85), [name] SYSNAME, [authentication_type_desc] NVARCHAR(60) )
 
WHILE EXISTS(SELECT [result] FROM #t WHERE [result] IS NULL)
BEGIN
    SELECT TOP 1 @db_name = [db_name]  FROM #t WHERE [result] IS NULL
 
    SELECT @query = 'USE ' + QUOTENAME(@db_name) + N';
	INSERT INTO #orphaned_users
	SELECT DB_NAME(), dp.type_desc, dp.sid, dp.name AS user_name  , dp.authentication_type_desc
	FROM sys.database_principals AS dp  
	LEFT JOIN sys.server_principals AS sp  
		ON dp.sid = sp.sid  
	WHERE sp.sid IS NULL  
		AND dp.authentication_type_desc IN (''INSTANCE'', ''WINDOWS''); 
    '
    RAISERROR (@query,0,1) WITH NOWAIT
 
    BEGIN TRY
        EXECUTE sp_executesql @query
        UPDATE #t SET [result] ='OK' WHERE [db_name] = @db_name
    END TRY
    BEGIN CATCH
        UPDATE #t SET [result] = ERROR_MESSAGE() WHERE [db_name] = @db_name
    END CATCH
END  

SELECT [db_name], [type_desc], [sid], [name], [authentication_type_desc]  
FROM #orphaned_users
GO
