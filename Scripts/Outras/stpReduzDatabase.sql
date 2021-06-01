DECLARE @database sysname
		,@Script nvarchar(max)

SET @database = 'StackOverflow2010'


SET NOCOUNT ON

IF OBJECT_ID('tempdb..#temp_database_size') IS NOT NULL
	DROP TABLE #temp_database_size

CREATE TABLE #temp_database_size (
	 DRIVE CHAR(1)
	,BASE SYSNAME
	,TAMANHO_ARQUIVO DECIMAL(15, 2)
	,ESPACO_UTILIZADO DECIMAL(15, 2)
	,ESPACO_LIVRE DECIMAL(15, 2)
	,PORCENTAGEM_LIVRE DECIMAL(15, 2)
	,ARQUIVO VARCHAR(100)
	,CAMINHO_ARQUIVO VARCHAR(255)
	)


SET @Script = ' USE ['+@database+'];

   INSERT INTO #temp_database_size
   SELECT  SUBSTRING(A.FILENAME, 1, 1) AS DRIVE
	  ,DB_NAME() AS BASE
	  ,CONVERT(DECIMAL(12, 2), ROUND(A.SIZE / 128.000, 2)) AS TAMANHO_ARQUIVO
	  ,CONVERT(DECIMAL(12, 2), ROUND(FILEPROPERTY(A.NAME, ''SPACEUSED'') / 128.000, 2)) AS ESPACO_UTILIZADO
	  ,CONVERT(DECIMAL(12, 2), ROUND((A.SIZE - FILEPROPERTY(A.NAME, ''SPACEUSED'')) / 128.000, 2)) AS ESPACO_LIVRE
	  ,(CONVERT(DECIMAL(12, 2), ROUND((A.SIZE - FILEPROPERTY(A.NAME, ''SPACEUSED'')) / 128.000, 2)) / CONVERT(DECIMAL(12, 2), ROUND(A.SIZE / 128.000, 2)))*100 AS PORCENTAGEM_LIVRE
	  ,A.NAME AS ARQUIVO
	  ,A.FILENAME AS CAMINHO_ARQUIVO
	FROM dbo.sysfiles A
	ORDER BY ARQUIVO
		,DRIVE
   '
EXEC sp_executesql @Script

DELETE FROM #temp_database_size WHERE BASE <> @database



IF OBJECT_ID('tempdb..#temp_index_size') IS NOT NULL
	DROP TABLE #temp_index_size

CREATE TABLE #temp_index_size (
	 [index_name] SYSNAME
	,[columns] VARCHAR(MAX)
	,[include] VARCHAR(MAX)
	,[index_type] VARCHAR(MAX)
	,[unique] VARCHAR(MAX)
	,[table_view] VARCHAR(MAX)
	,[object_type] VARCHAR(MAX)
	,[IndexSizeMB] DECIMAL(34,3)
)

SET @Script = ' USE ['+@database+'];
insert into #temp_index_size
select i.[name] as index_name
	,LEFT(list, ISNULL(splitter-1,len(list))) [columns]
	,SUBSTRING(list, indCol.splitter+1, 1000) [include]
	,case when i.[type] = 1 then ''Clustered index''
		when i.[type] = 2 then ''Nonclustered unique index''
		when i.[type] = 3 then ''XML index''
		when i.[type] = 4 then ''Spatial index''
		when i.[type] = 5 then ''Clustered columnstore index''
		when i.[type] = 6 then ''Nonclustered columnstore index''
		when i.[type] = 7 then ''Nonclustered hash index''
		end as index_type,
	case when i.is_unique = 1 then ''Unique''
		else ''Not unique'' end as [unique],
	schema_name(t.schema_id) + ''.'' + t.[name] as table_view, 
	case when t.[type] = ''U'' then ''Table''
		when t.[type] = ''V'' then ''View''
		end as [object_type]
	,size.IndexSizeKB/1024. IndexSizeMB

from sys.objects t
    inner join sys.indexes i
        on t.object_id = i.object_id
    cross apply (select col.[name] + '', ''
                    from sys.index_columns ic
                        inner join sys.columns col
                            on ic.object_id = col.object_id
                            and ic.column_id = col.column_id
                    where ic.object_id = t.object_id
                        and ic.index_id = i.index_id
                            order by key_ordinal
                            for xml path ('''') ) D (column_names)
	cross apply(SELECT SUM(s.[used_page_count]) * 8 AS IndexSizeKB
		from sys.dm_db_partition_stats  s
		where s.[object_id] = i.[object_id]
		AND s.[index_id] = i.[index_id]
	)size
	outer apply (select NULLIF(charindex(''|'',indexCols.list),0) splitter , list
             from (select cast((
                          select case when sc.is_included_column = 1 and sc.ColPos= 1 then''|''else '''' end +
                                 case when sc.ColPos > 1 then '', '' else ''''end + name
                            from (select sc.is_included_column, index_column_id, name
                                       , ROW_NUMBER()over (partition by sc.is_included_column
                                                            order by sc.index_column_id)ColPos
                                   from sys.index_columns  sc
                                   join sys.columns        c on sc.object_id= c.object_id
                                                            and sc.column_id = c.column_id
                                  where sc.index_id= i.index_id
                                    and sc.object_id= i.object_id) sc
                   order by sc.is_included_column
                           ,ColPos
                     for xml path (''''),type) as varchar(max)) list)indexCols) indCol
where t.is_ms_shipped <> 1
and i.index_id > 0
and i.[type] not in(1,5)
order by i.[name]
   '
   
EXEC sp_executesql @Script

IF OBJECT_ID('tempdb..#temp_index_size_scripts') IS NOT NULL
	DROP TABLE #temp_index_size_scripts

SELECT	
	*
	,ROW_NUMBER() OVER(ORDER BY IndexSizeMB DESC) rnk
	,SUM(IndexSizeMB) OVER(ORDER BY IndexSizeMB DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS IndexSizeMB_Cumulative 
	,'CREATE NONCLUSTERED INDEX ' + index_name + ' ON ' + table_view + ' (' + columns + ') ' + CASE WHEN [include] IS NOT NULL THEN ' INCLUDE(' + [include] + ')' ELSE '' END + ' WITH(DATA_COMPRESSION=PAGE)' ScriptCreateIndex
	,'DROP INDEX ' + index_name + ' ON ' + table_view ScriptDropIndex
INTO #temp_index_size_scripts
FROM #temp_index_size 
ORDER BY rnk


DECLARE @size DECIMAL(34,3)
		,@rnk INT 
		,@ScriptDrop VARCHAR(MAX)
		,@ScriptCreate VARCHAR(MAX)


/* 9GB - PARA TER ESPAÇO LIVRE PASSIVEL DE FRAGMENTAÇÃO  NO SHRINK*/
SELECT @size = ESPACO_UTILIZADO - 9216. FROM #temp_database_size WHERE CAMINHO_ARQUIVO LIKE '%.mdf'

SELECT @rnk = MAX(rnk) + 1 FROM #temp_index_size_scripts WHERE IndexSizeMB_Cumulative <= @size



IF OBJECT_ID('tempdb..#temp_index_size_scripts_DROP') IS NOT NULL
	DROP TABLE #temp_index_size_scripts_DROP

SELECT * INTO #temp_index_size_scripts_DROP FROM #temp_index_size_scripts

PRINT '/* 
--SCRIPT PARA DROPAR: '
WHILE (SELECT COUNT(1) FROM #temp_index_size_scripts_DROP WHERE rnk <= @rnk) > 0
BEGIN

	SELECT TOP 1 @ScriptDrop = ScriptDropIndex, @ScriptCreate = ScriptCreateIndex, @size = IndexSizeMB FROM #temp_index_size_scripts_DROP WHERE rnk <= @rnk ORDER BY IndexSizeMB_Cumulative 
	--EXEC sp_executesql @Script
	PRINT ''
	PRINT @ScriptDrop
	PRINT '-- ' + CAST(@size AS VARCHAR(120)) + 'MB'
	
	
	DELETE #temp_index_size_scripts_DROP WHERE @ScriptDrop = ScriptDropIndex

END

PRINT '*/

'


PRINT '/* 
--INDICES DROPADOS: '
WHILE (SELECT COUNT(1) FROM #temp_index_size_scripts WHERE rnk <= @rnk) > 0
BEGIN

	SELECT TOP 1 @ScriptDrop = ScriptDropIndex, @ScriptCreate = ScriptCreateIndex FROM #temp_index_size_scripts WHERE rnk <= @rnk ORDER BY IndexSizeMB_Cumulative
	--EXEC sp_executesql @Script
	PRINT ''
	PRINT @ScriptCreate
	
	
	DELETE #temp_index_size_scripts WHERE @ScriptDrop = ScriptDropIndex

END

PRINT '*/

'
PRINT ''
PRINT ''



DECLARE  @intervalo_reducao int = 1024					-- Intervalo em MB que deseja gerar o shrink

IF OBJECT_ID('tempdb..#TEMP') IS NOT NULL
	DROP TABLE #TEMP

IF OBJECT_ID('tempdb..#ESPACO_DATABASES') IS NOT NULL
	DROP TABLE #ESPACO_DATABASES

CREATE TABLE #ESPACO_DATABASES (
	DRIVE CHAR(1)
	,BASE SYSNAME
	,GROUP_ID BIT
	,TAMANHO_ARQUIVO DECIMAL(15, 2)
	,ESPACO_UTILIZADO DECIMAL(15, 2)
	,ESPACO_LIVRE DECIMAL(15, 2)
	,ARQUIVO VARCHAR(100)
	,CAMINHO_ARQUIVO VARCHAR(255)
	)
	

SET @Script = ' USE ['+@database+'];

   INSERT INTO #ESPACO_DATABASES
   SELECT  SUBSTRING(A.FILENAME, 1, 1) AS DRIVE
		  ,'''+@database+''' AS BASE
		  ,GROUPID AS GROUP_ID
		  ,CONVERT(DECIMAL(12, 2), ROUND(A.SIZE / 128.000, 2)) AS TAMANHO_ARQUIVO
		  ,CONVERT(DECIMAL(12, 2), ROUND(FILEPROPERTY(A.NAME, ''SPACEUSED'') / 128.000, 2)) AS ESPACO_UTILIZADO
		  ,CONVERT(DECIMAL(12, 2), ROUND((A.SIZE - FILEPROPERTY(A.NAME, ''SPACEUSED'')) / 128.000, 2)) AS ESPACO_LIVRE
		  ,A.NAME AS ARQUIVO
		  ,A.FILENAME AS CAMINHO_ARQUIVO
		FROM dbo.sysfiles A
		ORDER BY BASE, GROUPID DESC, ARQUIVO
			,DRIVE
   '
EXEC sp_executesql @Script



ALTER TABLE #ESPACO_DATABASES ADD ID INT IDENTITY

SELECT *,ROW_NUMBER() OVER (PARTITION BY BASE, GROUP_ID ORDER BY BASE, GROUP_ID DESC, ARQUIVO) RNK INTO #TEMP FROM #ESPACO_DATABASES t 

DECLARE @arquivo varchar(max)
		,@id int
		,@controle_reducao int
		,@espaco_livre int
		,@espaco_min INT
		,@espaco_alocado int

WHILE (SELECT COUNT(1) FROM #TEMP) > 0
	BEGIN
		SELECT TOP 1 @database = BASE, @id = ID, @arquivo = ARQUIVO, @espaco_alocado = FLOOR(TAMANHO_ARQUIVO), @espaco_min=FLOOR(ESPACO_UTILIZADO), @controle_reducao=FLOOR(TAMANHO_ARQUIVO),@espaco_livre=FLOOR(ESPACO_LIVRE) FROM #TEMP ORDER BY BASE, GROUP_ID DESC, ARQUIVO
		PRINT 'USE ' + @database +'
GO'
		PRINT ''
		PRINT '--ESPAÇO ALOCADO: ' + CAST(@espaco_alocado AS VARCHAR(10)) + 'MB'
		PRINT '--ESPAÇO UTILIZADO: ' + CAST(@espaco_min AS VARCHAR(10)) + 'MB'
		PRINT ''


		IF @espaco_alocado - @espaco_min > @intervalo_reducao
		BEGIN
			WHILE @controle_reducao > @espaco_min + @intervalo_reducao
			BEGIN
				SET @controle_reducao = @controle_reducao - @intervalo_reducao
				PRINT 'DBCC SHRINKFILE (N'''+@arquivo+''', '+CAST(@controle_reducao AS VARCHAR(10))+')
GO'				
			END
		END
		PRINT ''
		PRINT '--ESPAÇO LIVRE APOS SHRINK: ' + CAST(@controle_reducao - @espaco_min AS VARCHAR(10)) + 'MB'
		PRINT ''
		PRINT ''
		PRINT ''
		
		DELETE FROM #TEMP WHERE ID = @id
END




/*

select SCHEMA_NAME (o.SCHEMA_ID) SchemaName
  ,o.name ObjectName,i.name IndexName
  ,i.type_desc
  ,LEFT(list, ISNULL(splitter-1,len(list))) Columns
  , SUBSTRING(list, indCol.splitter+1, 1000) --len(name) - splitter-1) columns

from sys.indexes i
join sys.objects o on i.object_id= o.object_id
outer apply (select NULLIF(charindex('|',indexCols.list),0) splitter , list
             from (select cast((
                          select case when sc.is_included_column = 1 and sc.ColPos= 1 then'|'else '' end +
                                 case when sc.ColPos > 1 then ', ' else ''end + name
                            from (select sc.is_included_column, index_column_id, name
                                       , ROW_NUMBER()over (partition by sc.is_included_column
                                                            order by sc.index_column_id)ColPos
                                   from sys.index_columns  sc
                                   join sys.columns        c on sc.object_id= c.object_id
                                                            and sc.column_id = c.column_id
                                  where sc.index_id= i.index_id
                                    and sc.object_id= i.object_id) sc
                   order by sc.is_included_column
                           ,ColPos
                     for xml path (''),type) as varchar(max)) list)indexCols) indCol
where i.name like '%W[0-9][1-9]'

set statistics profile on
create nonclustered index SK04_Posts on Posts(FavoriteCount,Id, AcceptedAnswerId, AnswerCount, ClosedDate, CommentCount, CommunityOwnedDate, CreationDate,  LastActivityDate, LastEditDate, LastEditorDisplayName, LastEditorUserId, OwnerUserId, ParentId, PostTypeId, Score, Tags, Title, ViewCount) 
set statistics profile off
set statistics profile on
create nonclustered index SK05_Posts on Posts(CommentCount, Id, AcceptedAnswerId, AnswerCount, ClosedDate,  CommunityOwnedDate, CreationDate, FavoriteCount, LastActivityDate, LastEditDate, LastEditorDisplayName, LastEditorUserId, OwnerUserId, ParentId, PostTypeId, Score, Tags, Title, ViewCount) 
set statistics profile off
set statistics profile on
create nonclustered index SK06_Posts on Posts(ClosedDate,Id, AcceptedAnswerId,  CommentCount, CommunityOwnedDate, CreationDate, FavoriteCount, LastActivityDate, LastEditDate, LastEditorDisplayName, LastEditorUserId, OwnerUserId, ParentId, PostTypeId, Score, Tags, Title, ViewCount) 
set statistics profile off
set statistics profile on
create nonclustered index SK07_Posts on Posts( AcceptedAnswerId, AnswerCount, ClosedDate, CommentCount, CommunityOwnedDate, CreationDate, FavoriteCount, LastActivityDate, LastEditDate, LastEditorDisplayName, LastEditorUserId, OwnerUserId, ParentId, PostTypeId, Score, Tags, Title, ViewCount) 
set statistics profile off
*/