/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/

CREATE EVENT SESSION [Spill_Count]
ON SERVER
ADD EVENT sqlserver.exchange_spill,
ADD EVENT sqlserver.hash_warning,
ADD EVENT sqlserver.sort_warning
ADD TARGET package0.event_counter;
-- Начинаем сеанс и позволяем ему собирать данные
ALTER EVENT SESSION [Spill_Count]
ON SERVER
STATE = START;
GO
-- Анализируем данные
DECLARE
@TargetData XML
SELECT
@TargetData = CONVERT(XML,st.target_data)
FROM
sys.dm_xe_sessions s WITH (NOLOCK)
JOIN sys.dm_xe_session_targets st WITH(NOLOCK) ON
s.address = st.event_session_address
WHERE
s.name = 'Spill_Count' and st.target_name = 'event_counter';
;WITH EventInfo
AS
(
SELECT
t.e.value('@name','sysname') AS [Event]
,t.e.value('@count','bigint') AS [Count]
FROM
@TargetData.nodes
('/CounterTarget/Packages/Package[@name="sqlserver"]/Event')
AS t(e)
)
SELECT [Event], [Count]
FROM EventInfo
OPTION (RECOMPILE, MAXDOP 1);
