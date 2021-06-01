select DB_NAME(database_id),login_name,status,COUNT(1) from sys.dm_exec_sessions group by DB_NAME(database_id),login_name,status


--2008

SELECT   des.login_name,
        d.name AS database_name, des.program_name, count(1) qtd,des.[status]
FROM    sys.dm_exec_sessions des
JOIN    sys.sysprocesses p ON des.session_id = p.spid
LEFT JOIN sys.databases d ON p.dbid = d.database_id
WHERE   des.session_id > 50
  AND   p.ecid =0
 group by des.[status], des.login_name,
        d.name,   des.program_name
      order by qtd desc


/*
DECLARE @SPID AS VARCHAR(5) 
IF( Object_id('tempdb..#Processos') IS NOT NULL )
  DROP TABLE #processos
SELECT Cast(spid AS VARCHAR(5)) AS spid 
INTO   #processos 
FROM   master.dbo.sysprocesses A 
       JOIN master.dbo.sysdatabases B 
         ON A.dbid = B.dbid 
WHERE  B.NAME = 'AX60_IBRAME_PROD' 
       AND spid > 50 -- APENAS PROCESSOS DE USUARIO 
       and loginame ='COPPER\dynamics.service.p'
       and a.status = 'sleeping'
-- SELECT * FROM #Processos 

WHILE ( (SELECT Count(*)
         FROM   #processos) > 0 ) 
BEGIN
      SET @SPID = (SELECT TOP 1 spid
                            FROM   #processos) 
      EXEC ('Kill ' + @SPID) 
      DELETE FROM #processos 
      WHERE  spid = @SPID 
  END
  
  */