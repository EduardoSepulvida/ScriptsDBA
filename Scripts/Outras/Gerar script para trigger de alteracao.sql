/*
CREATE TRIGGER [dbo].[SE1_DTALTERACAO_010]
ON [dbo].SE1010
FOR UPDATE,INSERT
AS
BEGIN
	 update A
	 SET E1_YDTALTE = convert(varchar, getdate(), 112) ,E1_YHRALTE = substring(convert(varchar, getdate(), 8),1,5)
	 from SE1010 A
			join inserted B ON A.R_E_C_N_O_ = B.R_E_C_N_O_
END
*/


SET NOCOUNT ON

IF OBJECT_ID('tempdb..#temp_tables') IS NOT NULL
	DROP TABLE #temp_tables

CREATE TABLE #temp_tables (
	id int identity
	,table_schema sysname
	,table_name sysname
)

INSERT INTO #temp_tables (table_schema,table_name)
VALUES
	 ('dbo','ORC_TELEP')
	,('dbo','SAI_ITENS')
	,('dbo','MOVF')
	,('dbo','CUSTO')
	,('dbo','CUSTOS_M')
	,('dbo','ENTR_ITENS')
	,('dbo','ORC_PEDIDO')
	,('dbo','SAI_MESTRE')
	,('dbo','MOVP')
	,('dbo','MOV_CTABIL')
	,('dbo','ITEM_ESTAT')
	,('dbo','SALDO')
	,('dbo','ITENS')
	,('dbo','ITEM_ESTAT_20200523')
	,('dbo','HIST_PEDIDO_ITENS')
	,('dbo','EQUIV')
	,('dbo','CAIXA')
	,('dbo','ENTR_MESTR')
	,('dbo','TITULOS')

DECLARE  @COLUMN_DT sysname = 'BI_DTALTER'
		,@COLUMN_HR sysname = 'BI_HRALTER'
		,@COLUMN_DTDELETE sysname = 'BI_DTDELETE' --DELETE
		,@COLUMN_HRDELETE sysname = 'BI_HRDELETE' --DELETE




-----------------------

IF OBJECT_ID('tempdb..#temp_table_not_exists') IS NOT NULL
	DROP TABLE #temp_table_not_exists

SELECT 
	QUOTENAME(table_schema)TABLE_SCHEMA 
	,QUOTENAME(table_name)TABLE_NAME
INTO 
	#temp_table_not_exists
FROM 
	#temp_tables

EXCEPT 

select 
	QUOTENAME(schema_name(tab.schema_id)), 
    QUOTENAME(tab.[name]) COLLATE SQL_Latin1_General_CP1_CI_AS
from sys.tables tab    



IF OBJECT_ID('tempdb..#temp_table_constraints') IS NOT NULL
	DROP TABLE #temp_table_constraints

SELECT 
	QUOTENAME(tb.TABLE_SCHEMA)TABLE_SCHEMA
	,QUOTENAME(tb.TABLE_NAME)TABLE_NAME
	,cl.COLUMN_NAME TABLE_COLUMN
	,ROW_NUMBER() OVER(PARTITION BY tb.TABLE_SCHEMA, tb.TABLE_NAME ORDER BY cl.COLUMN_NAME) Rnk
INTO 
	#temp_table_constraints
FROM
    INFORMATION_SCHEMA.TABLE_CONSTRAINTS tb
	JOIN 
	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cl
		ON 
			cl.Constraint_Name = tb.Constraint_Name
			AND cl.Table_Name = tb.Table_Name
			AND tb.Constraint_Type IN ('PRIMARY KEY', 'UNIQUE')
	JOIN 
	#temp_tables tt
		ON 
			tt.table_name = tb.TABLE_NAME COLLATE SQL_Latin1_General_CP1_CI_AS
			AND tt.table_schema = tb.TABLE_SCHEMA COLLATE SQL_Latin1_General_CP1_CI_AS


			
/*VALIDA SE EXISTE TABELAS SEM CONSTRAINTS (PRIMARY KEY  OU  UNIQUE)*/
IF OBJECT_ID('tempdb..#temp_check_constraints') IS NOT NULL
	 DROP TABLE #temp_check_constraints

SELECT 
	(tt.TABLE_SCHEMA)TABLE_SCHEMA 
	,(tt.TABLE_NAME)TABLE_NAME
INTO 
	#temp_check_constraints
FROM 
	(
	SELECT 
		QUOTENAME(table_schema)TABLE_SCHEMA 
		,QUOTENAME(table_name)TABLE_NAME	
	FROM 
		#temp_tables

	INTERSECT 

	select 
		QUOTENAME(schema_name(tab.schema_id)), 
		QUOTENAME(tab.[name]) COLLATE SQL_Latin1_General_CP1_CI_AS
	from sys.tables tab  
	)tt

	
EXCEPT

SELECT 
	TABLE_SCHEMA COLLATE SQL_Latin1_General_CP1_CI_AS
	,TABLE_NAME COLLATE SQL_Latin1_General_CP1_CI_AS
FROM	
	#temp_table_constraints


select * from #temp_table_constraints WHERE Rnk > 1

DELETE from #temp_table_constraints  
where TABLE_NAME IN (SELECT TABLE_NAME FROM #temp_table_constraints tb2 
				WHERE tb2.Rnk > 1 )

DECLARE @bases varchar(8000) = ''


/*INFORMA TABELAS QUE NÃO FORAM ENCONTRADAS NO BANCO ATUAL*/
IF (SELECT COUNT(1) FROM #temp_check_constraints) > 0 
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



SET @bases = ''
/*INFORMA TABELAS SEM CONSTRAINTS*/
IF (SELECT COUNT(1) FROM #temp_check_constraints) > 0 
BEGIN 
	

	SELECT @bases = '-- ' + STUFF((
        SELECT ', ' + tb.table_schema+'.'+tb.table_name
        FROM #temp_check_constraints tb
        ORDER BY  tb.table_schema, tb.table_name
        FOR XML PATH('')), 1, 2, ''
    ) 

	PRINT '
	
-- TABELAS QUE NÃO POSSUEM CONSTRAINTS (PRIMARY KEY ou UNIQUE)'	
	PRINT @bases
END




/*TABELAS PARA CRIAÇÃO DAS COLUNAS*/

IF OBJECT_ID('tempdb..#temp_table_column') IS NOT NULL
	DROP TABLE #temp_table_column

SELECT DISTINCT
	TABLE_SCHEMA
	,TABLE_NAME
INTO 
	#temp_table_column
FROM 
	#temp_table_constraints



/*GERAR COLUNAS UPDATE*/
DECLARE @table_schema sysname
		,@table_name sysname
		,@table_column sysname
PRINT '

'
PRINT 'USE '+QUOTENAME(DB_NAME())
PRINT 'GO'
WHILE (SELECT COUNT(1) FROM #temp_table_column) > 0
BEGIN
	SELECT @table_schema = tb.TABLE_SCHEMA ,@table_name = tb.TABLE_NAME FROM #temp_table_column tb ORDER BY table_schema, table_name
	
	PRINT'
--TABELA: '+ @table_schema +'.'+ (@table_name) + '
ALTER TABLE '+ @table_schema +'.'+ (@table_name) + ' ADD ' + @COLUMN_DT + ' varchar(8)
ALTER TABLE '+ @table_schema +'.'+ (@table_name) + ' ADD ' + @COLUMN_HR + ' varchar(5)
'
	DELETE #temp_table_column  WHERE table_schema= @table_schema AND table_name = @table_name

END



/*GERAR TRIGGER INSERT/UPDATE*/
PRINT '

'
PRINT 'USE '+QUOTENAME(DB_NAME())
PRINT 'GO'

WHILE (SELECT COUNT(1) FROM #temp_table_constraints) > 0
BEGIN
	SELECT @table_schema = tb.TABLE_SCHEMA ,@table_name = tb.TABLE_NAME, @table_column = TABLE_COLUMN FROM #temp_table_constraints tb ORDER BY table_schema, table_name, TABLE_COLUMN
	
	PRINT'
CREATE TRIGGER '+ @table_schema +'.['+ PARSENAME(@table_name,1) +'_DTALTERACAO]
ON '+@table_schema + '.' + @table_name +'
FOR UPDATE, INSERT
AS
	BEGIN
		UPDATE	A
		SET		dtalte = CONVERT(VARCHAR, GETDATE(), 112),
				hralte = SUBSTRING(CONVERT(VARCHAR, GETDATE(), 8), 1, 5)
		FROM	'+@table_schema + '.' + @table_name+' A
				JOIN inserted B
				ON A.'+@table_column+' = B.'+@table_column+'
	END 
	' 

	DELETE #temp_table_constraints  WHERE table_schema= @table_schema AND table_name = @table_name

END