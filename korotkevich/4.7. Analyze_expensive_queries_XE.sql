/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Анализ данных собранных в 4.6.									        */
/* В версии SQL Server 2016 и более старых нужно поменять способ получения  */
/* [Event Time] (см. комментарии) в скрипте                                 */
/****************************************************************************/

CREATE TABLE #EventData
(
event_data XML NOT NULL,
file_name NVARCHAR(260) NOT NULL,
file_offset BIGINT NOT NULL,
timestamp_utc datetime2(7) NOT NULL -- SQL Server 2017+
);
INSERT INTO #EventData(event_data, file_name, file_offset, timestamp_utc)
SELECT CONVERT(XML,event_data), file_name, file_offset, timestamp_utc
FROM sys.fn_xe_file_target_read_file
('C:\ExtEvents\Expensive Queries*.xel',NULL,NULL,NULL);
;WITH EventInfo([Event],[Event Time],[DB],[Statement],[SQL],[User Name]
,[Client],[App],[CPU Time],[Duration],[Logical Reads]
,[Physical Reads],[Writes],[Rows],[Query Hash],[Plan Hash]
,[PlanHandle],[Stmt Offset],[Stmt Offset End],File_Name,File_Offset)
AS
(
SELECT
event_data.value('/event[1]/@name','SYSNAME') AS [Event]
,timestamp_utc AS [Event Time] -- SQL Server 2017+
/*,event_data.value('/event[1]/@timestamp','DATETIME')
AS [Event Time] -- Версии до SQL Server 2017 */
,event_data.value
('((/event[1]/action[@name="database_id"]/value/text())[1])'
,'INT') AS [DB]
,event_data.value
('((/event[1]/data[@name="statement"]/value/text())[1])'
,'NVARCHAR(MAX)') AS [Statement]
,event_data.value
('((/event[1]/action[@name="sql_text"]/value/text())[1])'
,'NVARCHAR(MAX)') AS [SQL]
,event_data.value
('((/event[1]/action[@name="username"]/value/text())[1])'
,'NVARCHAR(255)') AS [User Name]
,event_data.value
('((/event[1]/action[@name="client_hostname"]/value/text())[1])'
,'NVARCHAR(255)') AS [Client]
,event_data.value
('((/event[1]/action[@name="client_app_name"]/value/text())[1])'
,'NVARCHAR(255)') AS [App]
,event_data.value
('((/event[1]/data[@name="cpu_time"]/value/text())[1])'
,'BIGINT') AS [CPU Time]
,event_data.value
('((/event[1]/data[@name="duration"]/value/text())[1])'
,'BIGINT') AS [Duration]
,event_data.value
('((/event[1]/data[@name="logical_reads"]/value/text())[1])'
,'INT') AS [Logical Reads]
,event_data.value
('((/event[1]/data[@name="physical_reads"]/value/text())[1])'
,'INT') AS [Physical Reads]
,event_data.value
('((/event[1]/data[@name="writes"]/value/text())[1])'
,'INT') AS [Writes]
,event_data.value
('((/event[1]/data[@name="row_count"]/value/text())[1])'
,'INT') AS [Rows]
,event_data.value(
'xs:hexBinary(((/event[1]/action[@name="query_hash"]/value/text())[1]))'
,'BINARY(8)') AS [Query Hash]
,event_data.value(
'xs:hexBinary(((/event[1]/action[@name="query_plan_hash"]/value/text())[1]))'
,'BINARY(8)') AS [Plan Hash]
,event_data.value(
'xs:hexBinary(((/event[1]/action[@name="plan_handle"]/value/text())[1]))'
,'VARBINARY(64)') AS [PlanHandle]
,event_data.value
('((/event[1]/data[@name="offset"]/value/text())[1])'
,'INT') AS [Stmt Offset]
,event_data.value
('((/event[1]/data[@name="offset_end"]/value/text())[1])'
,'INT') AS [Stmt Offset End]
,file_name
,file_offset
FROM
#EventData
)
SELECT
ei.*
,TRY_CONVERT(XML,qp.Query_Plan) AS [Plan]
INTO #Queries
FROM
EventInfo ei
OUTER APPLY
sys.dm_exec_text_query_plan
(
ei.PlanHandle
,ei.[Stmt Offset]
,ei.[Stmt Offset End]
) qp
OPTION (MAXDOP 1, RECOMPILE);
