DBCC FREEPROCCACHE;

OPTION(RECOMPILE, QUERYTRACEON 9481)


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
 and last_updated < '20210517'
 ORDER BY last_updated
 
 
 --RODRIGO
 
IF OBJECT_ID('tempdb..#Tabs') IS NOT NULL
    DROP TABLE #Tabs;


SELECT
     DBName = DB_NAME()
    ,ObjName = QUOTENAME(Q.name)+'.'+QUOTENAME(T.name)
    ,R.* 
    ,S.*
INTO #Tabs 
FROM 
    sys.tables T CROSS APPLY (
        SELECT rows = SUM(P.rows) FROM sys.partitions P WHERE P.index_id <= 1 AND P.object_id = T.object_id
    ) R
    CROSS APPLY (
        SELECT TotalStats = COUNT(*)
        ,MinUp = MIN(STATS_DATE(S.object_id,S.stats_id))
        ,MaxUp = MAX(STATS_DATE(S.object_id,S.stats_id))
        FROM sys.stats S WHERE S.object_id = T.object_id
    ) S
    INNER JOIN
    sys.schemas Q
        ON Q.schema_id = T.schema_id


SELECT
    *
    ,'USE '+QUOTENAME(DbName)+'; UPDATE STATISTICS '+ObjName+' WITH FULLSCAN'
FROM
    #Tabs
WHERE
    TotalStats >= 1
    AND
    MaxUp <= DATEADD(dd,-7,GETDATE())
ORDER BY
    rows


