/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/

CREATE EVENT SESSION [Spills]
ON SERVER
ADD EVENT sqlserver.hash_warning
(
ACTION
(
sqlserver.database_id
,sqlserver.plan_handle
,sqlserver.session_id
,sqlserver.sql_text
,sqlserver.query_hash
,sqlserver.query_plan_hash
)
WHERE ([sqlserver].[is_system]=0)
),
ADD EVENT sqlserver.sort_warning
(
ACTION
(
sqlserver.database_id
,sqlserver.plan_handle
,sqlserver.session_id
,sqlserver.sql_text
,sqlserver.query_hash
,sqlserver.query_plan_hash
)
WHERE ([sqlserver].[is_system]=0)
),
ADD EVENT sqlserver.exchange_spill
(
ACTION
(
sqlserver.database_id
,sqlserver.plan_handle
,sqlserver.session_id
,sqlserver.sql_text
,sqlserver.query_hash
,sqlserver.query_plan_hash
)
WHERE ([sqlserver].[is_system]=0)
)
ADD TARGET package0.ring_buffer;
GO

-- Начинаем сеанс расширенного события
-- Позволим ему выполняться некоторое время и собирать информацию
ALTER EVENT SESSION [Spills]
ON SERVER
STATE = START;
GO
-- Анализируем результаты
DROP TABLE IF EXISTS #tmpXML;
CREATE TABLE #tmpXML
(
EventTime DATETIME2(7) NOT NULL,
[Event] XML
);
DECLARE
@TargetData XML;
SELECT
@TargetData = CONVERT(XML,st.target_data)
FROM
sys.dm_xe_sessions s WITH (NOLOCK)
JOIN sys.dm_xe_session_targets st WITH(NOLOCK) ON
s.address = st.event_session_address
WHERE
s.name = 'Spills' and st.target_name = 'ring_buffer';
INSERT INTO #tmpXML(EventTime, [Event])
SELECT
t.e.value('@timestamp','datetime'), t.e.query('.')
FROM
@TargetData.nodes('/RingBufferTarget/event') AS t(e);
;WITH EventInfo
AS
(
SELECT
t.EventTime
,t.[Event].value('/event[1]/@name','sysname') AS [Event]
,t.[Event].value('(/event[1]/action[@name="session_id"]/value
/text())[1]'
,'smallint') AS [Session]
,t.[Event].value('(/event[1]/action[@name="database_id"]/value
/text())[1]'
,'smallint') AS [DB]
,t.[Event].value('(/event[1]/action[@name="sql_text"]/value/text())[1]'
,'nvarchar(max)') AS [SQL]
,t.[Event]
.value('(/event[1]/data[@name="granted_memory_kb"]/value/text())[1]'
,'bigint') AS [Granted Memory (KB)]
,t.[Event]
.value('(/event[1]/data[@name="used_memory_kb"]/value/text())[1]'
,'bigint') AS [Used Memory (KB)]
,t.[Event]
.value('xs:hexBinary((/event[1]/action[@name="plan_handle"]/value
/text())[1])'
,'varbinary(64)') AS [PlanHandle]
,t.[Event].value('(/event[1]/action[@name="query_hash"]/value
/text())[1]'
,'nvarchar(64)') AS [QueryHash]
,t.[Event]
.value('(/event[1]/action[@name="query_plan_hash"]/value/text())[1]'
,'nvarchar(64)') AS [QueryPlanHash]
FROM
#tmpXML t
)
SELECT
ei.*, qp.query_plan
FROM
EventInfo ei
OUTER APPLY sys.dm_exec_query_plan(ei.PlanHandle) qp
OPTION (RECOMPILE, MAXDOP 1);
