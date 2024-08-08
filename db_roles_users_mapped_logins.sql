USE [master]
GO
 
DECLARE @db_name SYSNAME
DECLARE @query NVARCHAR(MAX)
 
DROP TABLE IF EXISTS #t
CREATE TABLE #t ([db_name] SYSNAME, [result] NVARCHAR(4000) )
INSERT INTO #t ([db_name]) SELECT [name] FROM sys.databases WHERE database_id > 0;

DROP TABLE IF EXISTS #db_roles
CREATE TABLE #db_roles ([db_name] SYSNAME, [role_name] SYSNAME NULL, [user_id] INT, [user_name] SYSNAME, [user_type_desc] NVARCHAR(60), [user_default_schema] SYSNAME NULL, [user_authentication_type] NVARCHAR(60), [sid] VARBINARY(85), [mapped_login] SYSNAME NULL, [login_type] NVARCHAR(60) )
 
WHILE EXISTS(SELECT [result] FROM #t WHERE [result] IS NULL)
BEGIN
    SELECT TOP 1 @db_name = [db_name]  FROM #t WHERE [result] IS NULL
 
    SELECT @query = 'USE ' + QUOTENAME(@db_name) + N';
	INSERT INTO #db_roles
	SELECT DB_NAME(), USER_NAME([role_principal_id]) AS [role], dp.[principal_id], dp.[name], dp.[type_desc], [default_schema_name], [authentication_type_desc], dp.[sid], sp.[name], sp.[type_desc]
	FROM sys.database_role_members rm
	RIGHT JOIN sys.database_principals dp ON dp.principal_id = rm.member_principal_id
	LEFT JOIN [master].sys.server_principals AS sp ON dp.[sid] = sp.[sid]
	WHERE dp.type <> ''R''
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

SELECT [db_name], [role_name], [user_id], [user_name], [user_type_desc], [user_default_schema], [user_authentication_type], [sid], [mapped_login], [login_type] FROM #db_roles
