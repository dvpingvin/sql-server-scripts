/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Не оставлять включенными! Использовать только для устрания неполадок!    */
/* Интересуют только ожижания связанные с tempdb                            */
/****************************************************************************/

CREATE EVENT SESSION [Latch Waits] ON SERVER
ADD EVENT sqlserver.latch_suspend_end
ADD TARGET package0.ring_buffer
(SET max_events_limit=2000);
GO
-- Дальнейший код анализирует собранные результаты
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
s.name = 'Latch Waits' and st.target_name = 'ring_buffer';
INSERT INTO #tmpXML(EventTime, [Event])
SELECT t.e.value('@timestamp','datetime'), t.e.query('.')
FROM @TargetData.nodes('/RingBufferTarget/event') AS t(e);
;WITH EventInfo
AS
(
SELECT
t.[EventTime] as [Time]
,t.[Event].value('(/event[1]/data[@name="database_id"]/value/text())[1]'
,'smallint') AS [DB]
,t.[Event].value('(/event[1]/data[@name="duration"]/value/text())[1]'
,'bigint') AS [Duration]
FROM
#tmpXML t
)
SELECT
MONTH([Time]) as [Month]
,DAY([Time]) as [Day]
,DATEPART(hour,[Time]) as [Hour]
,DATEPART(minute,[Time]) as [Minute]
,[DB]
,COUNT(*) as [Latch Count]
,CONVERT(DECIMAL(15,3),SUM(Duration / 1000.)) as [Duration (MS)]
FROM
EventInfo ei
GROUP BY
MONTH([Time]),DAY([Time]),DATEPART(hour,[Time]),DATEPART(minute,[Time]),[DB]
ORDER BY
[Month],[Day],[Hour],[Minute],[DB]
OPTION (RECOMPILE, MAXDOP 1);
