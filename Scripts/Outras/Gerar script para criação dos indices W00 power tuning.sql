SET NOCOUNT ON

IF OBJECT_ID('tempdb..#temp_index_size') IS NOT NULL
	DROP TABLE #temp_index_size

  DECLARE @index_name sysname
		,@schema sysname
		,@table sysname
		,@columns varchar(max)
		,@include varchar(max)
		,@Script nvarchar(max)
   


select SCHEMA_NAME (o.SCHEMA_ID) SchemaName
  ,o.name ObjectName
  ,i.name IndexName
  ,i.type_desc
  ,LEFT(list, ISNULL(splitter-1,len(list))) [columns]
  , SUBSTRING(list, indCol.splitter+1, 1000) [include]
into #temp_index_size
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

   

EXEC sp_executesql @Script

   
WHILE (SELECT COUNT(1) FROM #temp_index_size) > 0
BEGIN
	SELECT TOP 1 @schema = [SchemaName], @table = [ObjectName], @index_name = [IndexName], @columns = [columns], @include = [include] FROM #temp_index_size tb ORDER BY [SchemaName],[ObjectName],[IndexName]
	
	PRINT'
	--TABELA: '+ @schema + '.' + @table +'
	IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name = '''+PARSENAME(@table,1)+'W01'' AND object_id = OBJECT_ID(''' + @table + '''))
	BEGIN
		CREATE NONCLUSTERED INDEX '+@index_name+' ON ' + @schema+'.'+@table + '('+@columns+')' 
		IF @include IS NOT NULL PRINT '		INCLUDE('+ @include +')' PRINT '		WITH(DATA_COMPRESSION=PAGE)
	END
	GO' 

	DELETE #temp_index_size  WHERE @schema = [SchemaName] AND @table = [ObjectName] AND @index_name = [IndexName]
END


