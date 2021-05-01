^(.{4}) -posição 4

\r\n\Z --REMOVER ULTIMA LINHA
^ -inicio
$ -fim da linha


dir | rename-item -NewName {$_.name -replace "_headers",""}

-- Verificar tamanho do log
dbcc sqlperf(logspace)

select 
 name,
 log_reuse_wait_desc
from sys.databases


--OPTION(RECOMPILE, querytraceon 9481)

-- SP_WHOISACTIVE

exec sp_whoisactive @get_task_info =2, @get_plans = 1, @delta_interval = 1, @get_outer_command = 1

exec sp_whoisactive @get_task_info =2, @get_plans = 1, @delta_interval = 1, @show_sleeping_spids = 0, @get_outer_command = 1

--@find_block_leaders = 1 -- retorna quantos processos a sessao esta bloqueando


sp_whoisactive @find_block_leaders = 1, @sort_order = '[blocked_session_count] DESC'

--filtrando sp_whoisactive
--EXEC sp_WhoIsActive @filter_type = 'login', @filter = 'sa'

EXEC sp_whoisactive @get_outer_command = 1, @delta_interval = 1,@get_plans = 1,
	@output_column_list = '[database_name][collection_time][d%][session_id][blocking_session_id][sql_text][login_name][wait_info][status][percent_complete][host_name][database_name][sql_command]'



select * from sys.dm_exec_sessions where login_name= 'bizagi'

select * from msdb.dbo.sysjobs where CONVERT(binary(16), job_id)=

--------------------------------------------------------------------------------

SELECT
S.SPID [SPID],
S.PHYSICAL_IO [LEITURA FISICA],
S.CPU,
DER.SESSION_ID [SESSÃO],
DER.PERCENT_COMPLETE [PORCENTAGEM],
S.BLOCKED [BLOQUEADO],
DER.BLOCKING_SESSION_ID [BLOQUEANDO],
DER.COMMAND [COMANDO],
SUBSTRING(CONVERT(VARCHAR,DATEADD(SECOND,DER.TOTAL_ELAPSED_TIME/1000,'00:00:00'),21),12,8) [TEMPO],
T.TEXT [QUERY], 
S.PROGRAM_NAME [NOME DO PROGRAMA],
DB_NAME(S.DBID) BANCO
FROM 
SYS.DM_EXEC_REQUESTS DER
JOIN
SYS.SYSPROCESSES S ON S.SPID = DER.SESSION_ID
CROSS APPLY
SYS.DM_EXEC_SQL_TEXT(DER.SQL_HANDLE) T
WHERE
DER.SESSION_ID <> @@SPID
]
-----------------------------------------------------------------------------------

select SUBSTRING(TEXTData,1,50) TextData, SUM(Duration) Duration, SUM(Reads) Reads, SUM(CPU) CPU,  ApplicationName,LoginName
from traces..queries_profile 
where  LoginName = 'RECUPERA' 
group by SUBSTRING(TEXTData,1,50), ApplicationName,LoginName
order by  CPU DESC


-- VERIFICAR LOCAL DOS databases
SELECT a.name, b.name AS 'Logical filename', b.filename
FROM sys.sysdatabases a
INNER JOIN sys.sysaltfiles b on a.dbid = b.dbid
ORDER BY A.name


-- Comitar e limpar buffers
CHECKPOINT
DBCC DROPCLEANBUFFERS
DBCC FREEPROCCACHE 

-- "Commita" os dados do buffer que foram alterados e estão em cache para o disco e limpa os buffers. Usado antes do DBCC DROPCLEANBUFFERS 
CHECKPOINT

-- Remove todos os buffers limpos do pool de buffers e os objetos de columnstore do pool de objetos columnstore.
DBCC DROPCLEANBUFFERS

-- Use DBCC FREEPROCCACHE para limpar o cache do plano cuidadosamente. A limpeza do cache (plano) de procedimento faz com que todos os planos sejam removidos e as execuções de consulta de entrada compilarão um novo plano, em vez de reutilizar um plano anteriormente armazenado em cache.
DBCC FREEPROCCACHE 


-- ULTIMA VEZ QUE O SQL SERVER FOI REINICIADO
SELECT * FROM sys.databases WHERE database_id = 2


EXEC sp_helpdb @dbname= 'MSDB'

De <https://stackoverflow.com/questions/18014392/select-sql-server-database-size> 



--Obter PLE (Page Life Expectancy)
SELECT [object_name],
[counter_name],
[cntr_value] FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Manager%'
AND [counter_name] = 'Page life expectancy'

-- <10: muito baixo, pode gerar erros, asserts e dumps
-- <300: baixo
-- 1000: razoável
-- 5000: bom

-- Habilitar aplicativos menos seguros para enviar email Gmail
https://myaccount.google.com/lesssecureapps


-- VERIFICAR FILA DE E-MAILS 
SELECT  
    A.send_request_date AS DataEnvio,  
    A.sent_date AS DataEntrega,  
    (CASE      
        WHEN A.sent_status = 0 THEN '0 - Aguardando envio'  
        WHEN A.sent_status = 1 THEN '1 - Enviado'  
        WHEN A.sent_status = 2 THEN '2 - Falhou'  
        WHEN A.sent_status = 3 THEN '3 - Tentando novamente'  
    END) AS Situacao,  
    A.from_address AS Remetente,  
    A.recipients AS Destinatario,  
    A.subject AS Assunto,  
    A.reply_to AS ResponderPara,  
    A.body AS Mensagem,  
    A.body_format AS Formato,  
    A.importance AS Importancia,  
    A.file_attachments AS Anexos,  
    A.send_request_user AS Usuario,  
    B.description AS Erro,  
    B.log_date AS DataFalha  
FROM   
    msdb.dbo.sysmail_mailitems                  A    WITH(NOLOCK)  
    LEFT JOIN msdb.dbo.sysmail_event_log        B    WITH(NOLOCK)    ON A.mailitem_id = B.mailitem_id
ORDER BY DataEnvio DESC

-- verificar  EMAILS falhos
SELECT TOP 50
    SEL.event_type,
    SEL.log_date,
    SEL.description,
    SF.mailitem_id,
    SF.recipients,
    SF.copy_recipients,
    SF.blind_copy_recipients,
    SF.subject,
    SF.body,
    SF.sent_status,
    SF.sent_date
FROM msdb.dbo.sysmail_faileditems AS SF 
JOIN msdb.dbo.sysmail_event_log AS SEL ON SF.mailitem_id = SEL.mailitem_id
order by log_date DESC



--VERIFICAR TEMPO GASTO COM PROCESSOS DE SHRINK, BACKUP, RESTORE, CHECKDB
SELECT
	DB_NAME(database_id) [Nm_Database],
	session_id as SPID,
	command, s.text AS Query,
	start_time,
	percent_complete,
	dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time
FROM sys.dm_exec_requests r
	CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) s
WHERE r.command in ('BACKUP DATABASE','BACKUP LOG','RESTORE DATABASE','RESTORE LOG','DbccSpaceReclaim')




-- COPIAR ARQUIVOS CMD E RENOMEAR ADICIONANDO DATA E HORA
COPY "D:\Database\Duration.trc" "D:\Database\TempTraces\Duration_%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%.trc"



-- VERIFICAR DATA DE START (INICIO) DO SQL SERVER AGENT
SELECT [SQL Server Start Time] = CONVERT(VARCHAR(23), a.sql_start, 121),
        [SQL Agent Start Time] = CONVERT(VARCHAR(23), a.agent_start, 121),
        [SQL Uptime] = CONVERT(VARCHAR(15),
                       RIGHT(10000000+Datediff(dd, 0, Getdate()-a.sql_start), 4)
                       + ' '
                       + CONVERT(VARCHAR(20), Getdate()-a.sql_start, 108)),
        [Agent Uptime] = CONVERT(VARCHAR(15),
 RIGHT(10000000+Datediff(dd, 0, Getdate()-a.agent_start), 4)
 + ' '
 + CONVERT(VARCHAR(20), Getdate()-a.agent_start, 108))
 FROM   (SELECT SQL_Start = Min(aa.login_time),
                Agent_Start = NULLIF(Min(CASE
                                           WHEN aa.program_name LIKE 'SQLAgent %'
                                         THEN
                                           aa.login_time
                                           ELSE '99990101'
                                         END), CONVERT(DATETIME, '99990101'))
         FROM   master.dbo.sysprocesses aa
         WHERE  aa.login_time > '20000101') a


-- VERIFICA EM QUAL BANCO UMA TABELA ESTA - POR NOME
EXEC
    sys.sp_msforeachdb 
    'SELECT ''?'' DatabaseName, Name FROM [?].sys.Tables WHERE Name LIKE ''%product%'''


-- ATIVAR DATABASE MAIL

USE master
Go
EXEC sp_configure 'show advanced options', 1 --Enable advance option
Go
RECONFIGURE
Go
EXEC sp_configure 'Database Mail XPs,' 1 --Enable database Mail option
Go
RECONFIGURE
Go
EXEC sp_configure 'show advanced options', 0 --Disabled advanced option
Go
RECONFIGURE
Go


-- tamanho das tabelas

SELECT 
    t.NAME AS TableName,
    s.Name AS SchemaName,
    p.rows,
    SUM(a.total_pages) * 8 AS TotalSpaceKB, 
    CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB,
    SUM(a.used_pages) * 8 AS UsedSpaceKB, 
    CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB, 
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB,
    CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
FROM 
    sys.tables t
INNER JOIN      
    sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
WHERE 
    t.NAME NOT LIKE 'dt%' 
    AND t.is_ms_shipped = 0
    AND i.OBJECT_ID > 255 
GROUP BY 
    t.Name, s.Name, p.Rows
ORDER BY 
    TotalSpaceMB DESC, t.Name

