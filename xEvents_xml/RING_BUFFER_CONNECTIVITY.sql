WITH RingBufferData AS (
SELECT
timestamp,
CONVERT(xml, record) AS record_xml
FROM
sys.dm_os_ring_buffers
WHERE
ring_buffer_type = 'RING_BUFFER_CONNECTIVITY'
)
SELECT
timestamp,
record_xml.value('(//Record/@id)[1]', 'int') AS record_id_value,
record_xml.value('(//Record/@type)[1]', 'varchar(100)') AS record_type,
record_xml.value('(//Record/@time)[1]', 'varchar(100)') AS record_timestamp,
--record_xml.value('(//Record/ConnectivityTraceRecord/RecordTime)[1]', 'datetime') AS record_time,
DATEADD(hour, 3, record_xml.value('(//Record/ConnectivityTraceRecord/RecordTime)[1]', 'datetime')) AS [timestampMSK(UTC+3)],
record_xml.value('(//Record/ConnectivityTraceRecord/RecordType)[1]', 'varchar(100)') AS connectivity_type,
record_xml.value('(//Record/ConnectivityTraceRecord/RecordSource)[1]', 'varchar(100)') AS record_source,
record_xml.value('(//Record/ConnectivityTraceRecord/Spid)[1]', 'int') AS spid,
record_xml.value('(//Record/ConnectivityTraceRecord/OSError)[1]', 'int') AS os_error,
record_xml.value('(//Record/ConnectivityTraceRecord/SniConsumerError)[1]', 'int') AS sni_error,
record_xml.value('(//Record/ConnectivityTraceRecord/State)[1]', 'varchar(100)') AS state,
record_xml.value('(//Record/ConnectivityTraceRecord/RemoteHost)[1]', 'varchar(100)') AS remote_host,
record_xml.value('(//Record/ConnectivityTraceRecord/RemotePort)[1]', 'varchar(20)') AS remote_port,
record_xml.value('(//Record/ConnectivityTraceRecord/LocalHost)[1]', 'varchar(100)') AS local_host,
record_xml.value('(//Record/ConnectivityTraceRecord/TdsBufInfo/TdsFlags)[1]', 'varchar(200)') AS tds_flags,
record_xml.value('(//Record/ConnectivityTraceRecord/TdsBufInfo/InputBufError)[1]', 'int') AS tds_input_error,
record_xml.value('(//Record/ConnectivityTraceRecord/TdsBufInfo/OutputBufError)[1]', 'int') AS tds_output_error,
record_xml.value('(//Record/ConnectivityTraceRecord/TdsBufInfo/InputBufBytes)[1]', 'int') AS tds_disconnect_flags
FROM
RingBufferData
WHERE
record_xml.value('(//Record/ConnectivityTraceRecord/TdsBufInfo/InputBufError)[1]', 'int') = 10054
