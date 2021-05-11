DBCC FREEPROCCACHE;

OPTION(RECOMPILE, QUERYTRACEON 9481)

SELECT SCHEMA_NAME(schema_id) AS SchemaName,
       OBJECT_NAME(o.object_id) AS ObjectName,
       type AS ObjectType,
       s.name AS StatsName,
       STATS_DATE(o.object_id, stats_id) AS StatsDate
FROM sys.stats s
    INNER JOIN sys.objects o
        ON o.object_id = s.object_id
WHERE OBJECTPROPERTY(o.object_id, N'ISMSShipped') = 0
      AND LEFT(s.name, 4) != '_WA_'
ORDER BY ObjectType,
         SchemaName,
         ObjectName,
         StatsName;



--DESABILITAR AUTO STATISTICS NA TABELA
[18:00, 16/10/2020] +55 14 99818-0312: e pra quem te procurando a reposta... pra desligar o auto update na tabela, só chamar a sp_autostats...
[18:01, 16/10/2020] +55 14 99818-0312: ou direto na estatística... usar o no_recompute


SELECT DISTINCT STA.name,st.name, STP.rows, STP.rows_sampled ,
 (rows_sampled * 100)/STP.rows AS SamplePercent,
 rowmodctr,
 last_updated AS LastUpdated,
 ' UPDATE STATISTICS ' +'['+ss.name+']'+'.['+OBJECT_NAME(st.object_id) +']'+' '+'['+st.name +']'+ ' WITH FULLSCAN, MAXDOP=1'
 FROM sys.stats AS st
 CROSS APPLY sys.dm_db_stats_properties (st.object_id, st.stats_id) AS STP
 JOIN sys.tables STA ON st.[object_id] = STA.object_id
 JOIN sys.schemas ss on ss.schema_id = STA.schema_id
 join sys.sysobjects B with(nolock) on st.object_id = B.id
	join sys.sysindexes C with(nolock) on C.id = B.id and st.name = C.name
 WHERE 1=1
 and (rows_sampled * 100)/STP.rows <=80
 --AND STA.name in('NOTA_FISCAL','PEDIDO','ITEM')
 and last_updated < '202100505'
 ORDER BY last_updated