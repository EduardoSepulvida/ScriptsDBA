/*
CREATE TRIGGER [dbo].[SE1_DTALTERACAO_010]
ON [dbo].SE1010
FOR UPDATE,INSERT
AS
BEGIN
	 update A
	 SET E1_YDTALTE = convert(varchar, getdate(), 112) 
	 ,E1_YHRALTE = substring(convert(varchar, getdate(), 8),1,5)
	 from SE1010 A
			join inserted B ON A.R_E_C_N_O_ = B.R_E_C_N_O_
END
*/


SET NOCOUNT ON


DECLARE  @COLUMN_DT sysname = '_YDTALTE'
		,@COLUMN_HR sysname = '_YHRALTE'		
		,@table_delete_prefix sysname = 'DEL_'
		

IF OBJECT_ID('tempdb..#temp_tables') IS NOT NULL
	DROP TABLE #temp_tables

CREATE TABLE #temp_tables (
	id int identity
	,table_schema sysname
	,table_name sysname
	,table_indice sysname
	,table_prefix sysname
	,table_column_dt sysname
	,table_column_hr sysname
)

INSERT INTO #temp_tables (table_schema,table_name,table_indice,table_prefix,table_column_dt,table_column_hr)
SELECT 
	schema_name(tab.schema_id)
    ,tab.[name] COLLATE SQL_Latin1_General_CP1_CI_AS
	,CASE WHEN (idx.indice) < 10 THEN '0' + CAST(idx.indice AS VARCHAR(2)) ELSE CAST(idx.indice AS VARCHAR(2)) END table_indice
	,CASE WHEN prefix_limit = 0 THEN tab.[name] ELSE SUBSTRING(prefix.name,1,prefix_limit-1) END prefix
	,CASE WHEN prefix_limit = 0 THEN @COLUMN_DT ELSE SUBSTRING(prefix.name,1,prefix_limit-1)+@COLUMN_DT END table_column_dt
	,CASE WHEN prefix_limit = 0 THEN @COLUMN_HR ELSE SUBSTRING(prefix.name,1,prefix_limit-1)+@COLUMN_HR END table_column_hr
FROM 
	sys.tables tab 
OUTER APPLY(
	SELECT
		MAX(CAST(RIGHT(i.name,CHARINDEX('W',REVERSE(i.name))-1) AS INT)) MaxIndice
	FROM  
		sys.indexes i 
		join sys.sysobjects o on i.object_id = o.id
		join sys.tables t on o.id = t.object_id
	WHERE
		o.name = tab.[name]
		AND t.schema_id = tab.schema_id
		AND i.name LIKE '%W[0-9]%'
)x
OUTER APPLY(
	SELECT CASE WHEN x.MaxIndice IS NULL THEN 1 ELSE x.MaxIndice + 1 END indice
)idx
OUTER APPLY(
	SELECT 
		TOP 1 cl.name, CHARINDEX('_',cl.name,1) prefix_limit
	FROM 
		sys.columns cl			WHERE 1=1
		AND tab.object_id = cl.object_id
		--AND cl.name LIKE '%' + @COLUMN_DT				
)prefix
WHERE 
	tab.name like 'VIX_PRO_003%'  
	OR tab.name like 'SB9%'


/* =================== NÃO ALTERAR =================*/
	
	

/* =================== TABELA PARA GERAÇÃO DOS INDICES =================*/
IF OBJECT_ID('tempdb..#temp_tables_indice') IS NOT NULL
	DROP TABLE #temp_tables_indice

CREATE TABLE #temp_tables_indice (
	id int identity
	,table_schema sysname
	,table_name sysname
	,table_indice char(2)
	,table_column_dt sysname
	,table_column_hr sysname
)

INSERT INTO #temp_tables_indice (table_schema,table_name,table_indice,table_column_dt,table_column_hr)
SELECT table_schema,table_name,table_indice,table_column_dt,table_column_hr FROM #temp_tables


/* =================== TABELA PARA GERAÇÃO DAS TABELAS DELETE =================*/
IF OBJECT_ID('tempdb..#temp_tables_delete') IS NOT NULL
	DROP TABLE #temp_tables_delete

CREATE TABLE #temp_tables_delete (
	id int identity
	,table_schema sysname
	,table_name sysname
)

INSERT INTO #temp_tables_delete (table_schema,table_name)
SELECT table_schema,@table_delete_prefix+table_name FROM #temp_tables


/* =================== TABELA PARA GERAÇÃO DOS INDICES NAS TABELA DELETE =================*/
IF OBJECT_ID('tempdb..#temp_tables_indice_delete') IS NOT NULL
	DROP TABLE #temp_tables_indice_delete

CREATE TABLE #temp_tables_indice_delete (
	id int identity
	,table_schema sysname
	,table_name sysname
)

INSERT INTO #temp_tables_indice_delete (table_schema,table_name)
SELECT table_schema,@table_delete_prefix+table_name FROM #temp_tables



/* =================== TABELA PARA VERIFICAR TABELAS QUE NÃO EXISTEM =================*/
IF OBJECT_ID('tempdb..#temp_table_not_exists') IS NOT NULL
	DROP TABLE #temp_table_not_exists

SELECT 
	QUOTENAME(table_schema)table_schema 
	,QUOTENAME(table_name)table_name
INTO 
	#temp_table_not_exists
FROM 
	#temp_tables

EXCEPT 

select 
	QUOTENAME(schema_name(tab.schema_id)), 
    QUOTENAME(tab.[name]) COLLATE SQL_Latin1_General_CP1_CI_AS
from sys.tables tab    



DECLARE @bases varchar(max) =''
		,@table_schema sysname =''
		,@table_name sysname =''
		,@table_indice varchar(2)=''
		,@qtd int
		,@prefix sysname =''
		,@table_column_dt sysname =''
		,@table_column_hr sysname =''
		,@posfix sysname =''


/*INFORMA TABELAS QUE NÃO FORAM ENCONTRADAS NO BANCO ATUAL*/
IF (SELECT COUNT(1) FROM #temp_table_not_exists) > 0 
BEGIN 
	

	SELECT @bases = '-- ' + STUFF((
        SELECT ', ' + tb.table_schema+'.'+tb.table_name
        FROM #temp_table_not_exists tb
        ORDER BY  tb.table_schema, tb.table_name
        FOR XML PATH('')), 1, 2, ''
    ) 

	PRINT '-- TABELAS QUE NÃO FORAM ENCONTRADAS NO BANCO ' + QUOTENAME(DB_NAME())	
	PRINT @bases
END


/*============== QUANTIDADE OBJETOS ==================*/
PRINT('/*')
SELECT @qtd = COUNT(1) FROM #temp_tables
PRINT('Qtd de Triggers: ' + CAST(@qtd AS VARCHAR(10)))
SELECT @qtd = COUNT(1) FROM #temp_tables_indice
PRINT('Qtd de Indices: ' + CAST(@qtd AS VARCHAR(10)))
PRINT('*/')
PRINT('')

/*================= GERAR TRIGGERS ===================*/
PRINT '


/*
	
	ESTE SCRIPT NÃO DROPA NENHUM OBJETO, APENAS CRIA OS QUE NÃO EXISTEM
	
	OBJETOS CRIADOS:
	- CRIAÇÃO DAS TABELAS PARA LOGA OS DELETE
	- CRIAÇÃO DAS TRIGGERS NAS TABELAS ORIGINAIS
	- CRIAÇÃO DOS ÍNDICES NAS COLUNAS DATA E HORA (TABELAS ORIGINAIS)
	- CRIAÇÃO DOS ÍNDICES NAS COLUNAS DATA E HORA (TABELAS DELETES)
	
*/


'


/*================= GERAR TABELAS DELETE ===================*/

WHILE (SELECT COUNT(1) FROM #temp_tables_delete) > 0
BEGIN
	SELECT TOP 1 @table_schema = tb.table_schema ,@table_name = tb.table_name FROM #temp_tables_delete tb ORDER BY table_schema, table_name
	
	PRINT'
	--TABELA: '+@table_schema + '.' + @table_name +'
	IF OBJECT_ID('''+@table_schema + '.' + @table_name +''') IS NULL
	BEGIN
		CREATE TABLE '+@table_schema + '.' + @table_name +'(
			R_E_C_N_O_		INT
			,DT_DELETE		VARCHAR(8)
			,HR_DELETE		VARCHAR(5)
		)		
	END
	GO'

	DELETE #temp_tables_delete  WHERE table_schema= @table_schema AND table_name = @table_name

END

/*================= GERAR TRIGGERS ===================*/

PRINT 'USE '+QUOTENAME(DB_NAME())
PRINT 'GO'

WHILE (SELECT COUNT(1) FROM #temp_tables) > 0
BEGIN
	SELECT TOP 1 @table_schema = tb.table_schema ,@table_name = tb.table_name, @prefix = tb.table_prefix, @table_column_dt = tb.table_column_dt, @table_column_hr = tb.table_column_hr FROM #temp_tables tb ORDER BY table_schema, table_name
	
	SET @posfix = SUBSTRING(@table_name,CHARINDEX(@prefix,@table_name)+LEN(@prefix),3)

	IF LEN(@posfix) = 0 
	BEGIN 
		SET @posfix=RIGHT(@table_name,3) 
	END 
	

	PRINT'
IF NOT EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''['+ @table_schema +'].['+ @prefix +'_DTALTERACAO_'+ @posfix +']''))
BEGIN 
	EXEC dbo.sp_executesql @statement = N''
	CREATE TRIGGER ['+ @table_schema +'].['+ @prefix +'_DTALTERACAO_'+ @posfix +']
	ON '+@table_schema + '.' + @table_name +'
	FOR UPDATE, INSERT
	AS
		/*DELETE*/
		IF EXISTS(SELECT * FROM deleted) AND NOT EXISTS(SELECT * FROM inserted)
		BEGIN
			IF OBJECT_ID('''''+DB_NAME()+'..'+@table_delete_prefix+@table_name+''''') IS NOT NULL
			BEGIN
				INSERT INTO '+@table_delete_prefix+@table_name+'(R_E_C_N_O_,'+@table_column_dt+','+@table_column_hr+')
				SELECT 
					R_E_C_N_O_
					,'+@table_column_dt+'
					,'+@table_column_hr+'
				FROM 
					deleted	
			END
		END
		ELSE
		BEGIN 
		/*INSERT/UPDATE*/
			UPDATE	A
			SET		'+@table_column_dt+' = CONVERT(VARCHAR, GETDATE(), 112),
					'+@table_column_hr+' = SUBSTRING(CONVERT(VARCHAR, GETDATE(), 8), 1, 5)
			FROM	'+@table_schema + '.' + @table_name+' A
					JOIN inserted B
					ON A.R_E_C_N_O_ = B.R_E_C_N_O_
		END
	''
END
GO
'

	DELETE #temp_tables  WHERE table_schema= @table_schema AND table_name = @table_name

END


/*================= GERAR ÍNDICES POR DATA E HORA ===================*/

WHILE (SELECT COUNT(1) FROM #temp_tables_indice) > 0
BEGIN
	SELECT TOP 1 @table_schema = tb.table_schema ,@table_name = tb.table_name, @table_indice = tb.table_indice,@table_column_dt = tb.table_column_dt, @table_column_hr = tb.table_column_hr FROM #temp_tables_indice tb ORDER BY table_schema, table_name
	
	PRINT'
	--TABELA: '+@table_schema + '.' + @table_name +'
	IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name = '''+PARSENAME(@table_name,1)+'W'+@table_indice+''' AND object_id = OBJECT_ID(''' + @table_name + '''))
	BEGIN
		CREATE NONCLUSTERED INDEX '+PARSENAME(@table_name,1)+'W'+@table_indice+' ON '+@table_schema + '.' + @table_name +'('+@table_column_dt+','+@table_column_hr+') WITH(DATA_COMPRESSION=PAGE)
	END
	GO'

	DELETE #temp_tables_indice  WHERE table_schema= @table_schema AND table_name = @table_name

END



/*================= GERAR ÍNDICES DAS TABELAS DELETE POR DATA E HORA ===================*/

WHILE (SELECT COUNT(1) FROM #temp_tables_indice_delete) > 0
BEGIN
	SELECT TOP 1 @table_schema = tb.table_schema ,@table_name = tb.table_name FROM #temp_tables_indice_delete tb ORDER BY table_schema, table_name
	
	PRINT'
	--TABELA: '+@table_schema + '.' + @table_name +'
	IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name = '''+PARSENAME(@table_name,1)+'W01'' AND object_id = OBJECT_ID(''' + @table_name + '''))
	BEGIN
		CREATE NONCLUSTERED INDEX '+PARSENAME(@table_name,1)+'W01 ON ' + @table_name + '(BI_DTALTER,BI_HRDELETE,R_E_C_N_O_) WITH(DATA_COMPRESSION=PAGE)
	END
	GO' 

	DELETE #temp_tables_indice_delete  WHERE table_schema= @table_schema AND table_name = @table_name

END

