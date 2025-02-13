-- =============================================
-- Improvements Author: Sergey Izosimov
-- Improvements date: 02.11.2024
-- =============================================

USE [master]
GO

DECLARE @db_name SYSNAME
DECLARE @query NVARCHAR(MAX)

DROP TABLE IF EXISTS #t
CREATE TABLE #t ([db_name] SYSNAME, [result] NVARCHAR(4000))
INSERT INTO #t ([db_name]) SELECT [name] FROM sys.databases WHERE database_id > 0;

DROP TABLE IF EXISTS #guest_access
CREATE TABLE #guest_access ([db_name] SYSNAME, [hasdbaccess] INT)

WHILE EXISTS(SELECT [result] FROM #t WHERE [result] IS NULL)
BEGIN
	SELECT TOP 1 @db_name = [db_name]  FROM #t WHERE [result] IS NULL

	SELECT @query = 'USE ' + QUOTENAME(@db_name) + N';
	INSERT INTO #guest_access
	SELECT DB_NAME(), hasdbaccess FROM sys.sysusers WHERE name=''guest''
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

SELECT [db_name], [hasdbaccess] FROM #guest_access
WHERE [db_name] NOT IN ('master', 'msdb', 'tempdb')
