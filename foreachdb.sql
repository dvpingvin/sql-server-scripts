USE [master]
GO

DECLARE @db_name SYSNAME
DECLARE @query NVARCHAR(MAX)

DROP TABLE IF EXISTS #t
CREATE TABLE #t ([db_name] SYSNAME, [result] NVARCHAR(MAX) )
INSERT INTO #t ([db_name]) SELECT [name] FROM sys.databases WHERE database_id > 4;

WHILE EXISTS(SELECT [result] FROM #t WHERE [result] IS NULL)
BEGIN
	SELECT TOP 1 @db_name = [db_name]  FROM #t WHERE [result] IS NULL

	SELECT @query = 'USE ' + QUOTENAME(@db_name) + N';
	SELECT DB_NAME(); -- Replace with your query
	'
	RAISERROR (@query,0,1) WITH NOWAIT

	BEGIN TRY
		EXECUTE sp_executesql @query
		UPDATE #t SET [result] ='OK' WHERE [db_name] = @db_name
	END TRY
	BEGIN CATCH
		UPDATE #t SET [result] =ERROR_MESSAGE() WHERE [db_name] = @db_name
	END CATCH
END

SELECT * FROM #t
