
    -- Verifica se tem app com MARS habilitado
SELECT conn.session_id,
       sess.program_name,
       sess.host_name,
       sess.client_interface_name,
       sess.login_name,
       sess.status,
       conn.net_transport,
       conn.protocol_version,
       conn.net_packet_size,
       sess.row_count,
       wait.wait_type,
       wait.wait_duration_ms,
       wait.resource_description,
       conn.num_reads,
       conn.num_writes,
       sess.login_time,
       conn.connection_id,
       conn.parent_connection_id,
       conn.most_recent_sql_handle
FROM sys.dm_exec_connections conn
    JOIN sys.dm_exec_sessions sess
        ON sess.session_id = conn.session_id
    LEFT OUTER JOIN sys.dm_os_waiting_tasks wait
        ON wait.session_id = conn.session_id
WHERE EXISTS
      (
          SELECT *
          FROM sys.dm_exec_connections b
          WHERE b.net_transport = 'Session' -- Se tiver alguma conexão com MARS, net_transport vai ser = "Session"
          AND conn.session_id = b.session_id
      )
ORDER BY conn.session_id;
GO
