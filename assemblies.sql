USE [master]
GO

DECLARE @db_name SYSNAME
DECLARE @query NVARCHAR(MAX)

DROP TABLE IF EXISTS #t
CREATE TABLE #t ([db_name] SYSNAME, [result] NVARCHAR(4000) )
INSERT INTO #t ([db_name]) SELECT [name] FROM sys.databases WHERE database_id > 0;

ALTER TABLE #t ADD [assembly_name] SYSNAME, [assembly_owner] NVARCHAR(128), [clr_name] NVARCHAR(4000), [permission_set_desc] NVARCHAR(60)

WHILE EXISTS(SELECT [result] FROM #t WHERE [result] IS NULL)
BEGIN
	SELECT TOP 1 @db_name = [db_name]  FROM #t WHERE [result] IS NULL

	SELECT @query = 'USE ' + QUOTENAME(@db_name) + N';
	UPDATE #t
	SET
	#t.[assembly_name] = qr.[assembly_name],
	#t.[assembly_owner] = qr.[assembly_owner],
	#t.[clr_name] = qr.[clr_name],
	#t.[permission_set_desc] = qr.[permission_set_desc]
	FROM (
	SELECT DB_NAME() AS [db_name], [name] AS [assembly_name], USER_NAME(principal_id) AS [assembly_owner], [clr_name], [permission_set_desc] 
	FROM sys.assemblies
	) AS qr
	
	-- WHERE [name] <> ''Microsoft.SqlServer.Types''
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

SELECT * FROM #t
