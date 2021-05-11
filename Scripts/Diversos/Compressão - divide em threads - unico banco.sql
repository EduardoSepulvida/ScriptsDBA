USE [Traces]
GO

DECLARE @database sysname = 'DESENVP12'
		,@threads int = 15


SET NOCOUNT ON		

IF (OBJECT_ID('tempdb..##TEMP_POWER_COMPRESSAO_DADOS') IS NOT NULL)
	DROP TABLE ##TEMP_POWER_COMPRESSAO_DADOS

CREATE TABLE ##TEMP_POWER_COMPRESSAO_DADOS(
	[Nm_Database] [varchar](256)  NOT NULL,
	[Schema] [sysname] NOT NULL,
	[Table] [sysname] NOT NULL,
	[Index] [sysname] NULL,
	[Partition] [int] NOT NULL,
	[Compression] [nvarchar](60) NULL,
	[fill_factor] [tinyint] NOT NULL,
	[rows] [bigint] NULL,
	[Ds_Comando] [nvarchar](480) NULL
) ON [PRIMARY]


IF (OBJECT_ID('tempdb..##TEMP_POWER_COMPRESSAO_DADOS_HEAP') IS NOT NULL)
	DROP TABLE ##TEMP_POWER_COMPRESSAO_DADOS_HEAP

CREATE TABLE ##TEMP_POWER_COMPRESSAO_DADOS_HEAP (
	[Nm_Database] [varchar](256)  NOT NULL,
	[Schema] [sysname] NOT NULL,
	[Table] [sysname] NOT NULL,
	[Rows] nvarchar(256) NULL,
	[Compression] [nvarchar](60) NULL,
	[Ds_Comando] [nvarchar](312) NOT NULL
) ON [PRIMARY]


DECLARE @SQL VARCHAR(max) , @DB sysname

DECLARE curDB CURSOR FORWARD_ONLY STATIC FOR  
SELECT @database name  

	
	         
	OPEN curDB  
	FETCH NEXT FROM curDB INTO @DB  
	WHILE @@FETCH_STATUS = 0  
	   BEGIN  
		   SELECT @SQL = 'USE [' + @DB +']' + CHAR(13) + 
			 '
			
			;INSERT INTO ##TEMP_POWER_COMPRESSAO_DADOS
SELECT ''' + @DB + ''' AS [Nm_Database],
	   [s].[name] AS [Schema],
	   [t].[name] AS [Table], 
       [i].[name] AS [Index],  
       [p].[partition_number] AS [Partition],
       [p].[data_compression_desc] AS [Compression], 
       [i].[fill_factor],
       [p].[rows],
			 ''ALTER INDEX ['' + [i].[name] + ''] ON [' + @DB + '].['' + [s].[name] + ''].['' + [t].[name] + 
			 ''] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE'' +
			 CASE WHEN [i].[fill_factor] BETWEEN 1 AND 89 THEN '', FILLFACTOR = 90'' ELSE '''' END + '' )'' AS Ds_Comando
FROM [sys].[partitions] AS [p]
INNER JOIN sys.tables AS [t] 
     ON [t].[object_id] = [p].[object_id]
INNER JOIN sys.indexes AS [i] 
     ON [i].[object_id] = [p].[object_id] AND i.index_id = p.index_id
INNER JOIN sys.schemas AS [s]
		 ON [t].[schema_id] = [s].[schema_id]
WHERE [p].[index_id] > 0
			AND [i].[name] IS NOT NULL
			AND [p].[rows] > 10000
			AND [p].[data_compression_desc] = ''NONE''
--ORDER BY [p].[rows]									-- PARA VERIFICAR O TAMANHO DOS INDICES
--ORDER BY [s].[name], [t].[name], [i].[name]		-- ORDENA POR TABELA PARA PODER RODAR EM PARALELO
	
-- Data (table) compression (heap)
INSERT INTO ##TEMP_POWER_COMPRESSAO_DADOS_HEAP
SELECT DISTINCT 
	   ''' + @DB + ''' AS [Nm_Database],
	   [s].[name] AS [Schema],
	   [t].[name] AS [Table],
       [p].[rows],
	   [p].[data_compression_desc] AS [Compression], 
	   --[i].[fill_factor],
       ''ALTER TABLE [' + @DB + '].['' + [s].[name] + ''].['' + [t].[name] + ''] REBUILD WITH (DATA_COMPRESSION = PAGE)'' AS Ds_Comando
FROM [sys].[partitions] AS [p]
INNER JOIN sys.tables AS [t] 
     ON [t].[object_id] = [p].[object_id]
INNER JOIN sys.indexes AS [i] 
     ON [i].[object_id] = [p].[object_id]
INNER JOIN sys.schemas AS [s]
		 ON [t].[schema_id] = [s].[schema_id]
WHERE [p].[index_id]  = 0
			AND [p].[rows] > 10000
			AND [p].[data_compression_desc] = ''NONE''
				
		 '            
		exec (@SQL )
	   
		set @SQL = ''
	   
		FETCH NEXT FROM curDB INTO @DB  
	END  
	   
CLOSE curDB  
DEALLOCATE curDB


--SELECT * FROM ##TEMP_POWER_COMPRESSAO_DADOS 
--SELECT * FROM ##TEMP_POWER_COMPRESSAO_DADOS_HEAP	



IF (OBJECT_ID('tempdb..##TEMP_DADOS_TOTAL') IS NOT NULL)
	DROP TABLE ##TEMP_DADOS_TOTAL
SELECT
		t.Nm_Database
		,t.[Schema]
		,t.[Table]
		,t.[Index]
		,t.[rows]
		,HASHBYTES('SHA2_256',t.Nm_Database+t.[Schema]+t.[Table]) [hash]
		,SUM(t.[rows]) OVER(PARTITION BY t.Nm_Database,t.[Schema],t.[Table])total
		,t.Ds_Comando
	INTO ##TEMP_DADOS_TOTAL
	FROM ##TEMP_POWER_COMPRESSAO_DADOS t
	WHERE Nm_Database = @database
UNION
SELECT
		t.Nm_Database
		,t.[Schema]
		,t.[Table]
		,null
		,t.[Rows]
		,HASHBYTES('SHA2_256',t.Nm_Database+t.[Schema]+t.[Table]) [hash]
		,SUM(CAST(t.[Rows] AS INT)) OVER(PARTITION BY t.Nm_Database,t.[Schema],t.[Table])total
		,t.Ds_Comando
	FROM ##TEMP_POWER_COMPRESSAO_DADOS_HEAP	 t
	WHERE Nm_Database = @database


DECLARE  @count int = 1
		,@thread_table varchar(max) = ''
		,@string varchar(max) = ''
		,@thread_atual int = 1
		,@thread_controle int = 1
		,@table varchar(max)
	


--CRIA AS TABELAS TEMPORARIAS
WHILE @count <= @threads
BEGIN 
	
	SET @thread_table ='##temp_pwt_compression_thread'+cast(@count as varchar)
	SET @string = '
	
	IF (OBJECT_ID(''tempdb..'+@thread_table+''') IS NOT NULL)
		DROP TABLE '+@thread_table+'
	CREATE TABLE '+ @thread_table + '(
		 [Nm_Database] sysname
		,[Schema] sysname
		,[Table] sysname
		,[Index] sysname NULL
		,[rows] varchar(256)
		,[total] int
		,[Ds_Comando] varchar(312)
	)'
	
	EXEC sp_sqlexec @string

	PRINT @string
	
	SET @count +=1

END

--DISTRIBUI OS COMANDOS

WHILE (SELECT COUNT(1) FROM ##TEMP_DADOS_TOTAL)>0
BEGIN 
	
	PRINT 'CONTROLE:' +CAST(@thread_controle  AS VARCHAR)
	PRINT 'ATUAL: '+ CAST(@thread_atual AS VARCHAR)

	IF @thread_controle = 1
	BEGIN
		IF @thread_atual < @threads 
		BEGIN 
			SET @thread_atual += 1
		END
		ELSE
		BEGIN
			SET @thread_controle = -1
		END
	END
	ELSE
	BEGIN
		IF @thread_atual > 1 
		BEGIN 
			SET @thread_atual -= 1
		END
		ELSE
		BEGIN
			SET @thread_controle = 1
		END
	END

	SET @string = '
		INSERT INTO ##temp_pwt_compression_thread'+CAST(@thread_atual AS VARCHAR)+
		'
		SELECT [Nm_Database] ,[Schema] ,[Table] ,[Index] ,[rows] ,[total] ,[Ds_Comando] 
		FROM ##TEMP_DADOS_TOTAL WHERE [hash] = (select top 1 hash from ##TEMP_DADOS_TOTAL ORDER BY total DESC)
		'
	EXEC sp_sqlexec @string

	DELETE ##TEMP_DADOS_TOTAL WHERE [hash] = (select top 1 hash from ##TEMP_DADOS_TOTAL ORDER BY total DESC)

	PRINT @string


END


--consulta os comandos
SET @count = 1

WHILE @count <= @threads
BEGIN

	SET @string = '
	SELECT * FROM ##temp_pwt_compression_thread'+cast(@count as varchar)+' ORDER BY total DESC
	'
	EXEC sp_sqlexec @string

	SET @count +=1
END

/*
SELECT 
	S.name as 'Schema'
	,T.name as 'Table'
	,I.name as 'Index'
	,DDIPS.page_count
	,'ALTER INDEX '+I.name+' ON '+S.name+'.'+T.name+' REBUILD' COMANDO
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS DDIPS
INNER JOIN sys.tables T on T.object_id = DDIPS.object_id
INNER JOIN sys.schemas S on T.schema_id = S.schema_id
INNER JOIN sys.indexes I ON I.object_id = DDIPS.object_id
AND DDIPS.index_id = I.index_id
WHERE DDIPS.database_id = DB_ID()
and I.name is not null
AND DDIPS.avg_fragmentation_in_percent > 15
and page_count >= 1000
ORDER BY DDIPS.avg_fragmentation_in_percent desc*/