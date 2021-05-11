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
		

IF OBJECT_ID('tempdb..#temp_tables') IS NOT NULL
	DROP TABLE #temp_tables

CREATE TABLE #temp_tables (
	id int identity
	,table_schema sysname
	,table_name sysname
)

INSERT INTO #temp_tables (table_schema,table_name)
SELECT 
	schema_name(tab.schema_id), 
    tab.[name] COLLATE SQL_Latin1_General_CP1_CI_AS
FROM 
	sys.tables tab 
WHERE 
	tab.name like 'VIX_PRO_003%'  
	OR tab.name like 'SB9%'
	OR tab.name like 'CT2%'
	OR tab.name like 'SBZ%'
	OR tab.name like 'SD2%'
	OR tab.name like 'SPG%'
	OR tab.name like 'SL2%'
	OR tab.name like 'SE1%'
	OR tab.name like 'SZ2%'
	OR tab.name like 'SD1%'
	OR tab.name like 'SC6%'
	OR tab.name like 'SDB%'
	OR tab.name like 'SDB%'
	OR tab.name like 'ZZ5%'
	OR tab.name like 'SF2%'
	OR tab.name like 'SB2%'
	OR tab.name like 'ZZZ%'
	OR tab.name like 'SC7%'
	OR tab.name like 'SL1%'
	OR tab.name like 'SZH%'
	OR tab.name like 'SD3%'
	OR tab.name like 'SRD%'
	OR tab.name like 'SC9%'
	OR tab.name like 'SF1%'
	OR tab.name like 'SE2%'
	OR tab.name like 'SC5%'
	OR tab.name like 'SP9%'
	OR tab.name like 'SCR%'
	OR tab.name like 'SDA%'
	OR tab.name like 'SZX%'
	OR tab.name like 'SC1%'
	OR tab.name like 'SB7%'
	OR tab.name like 'SPH%'
	OR tab.name like 'SDT%'
	OR tab.name like 'SA1%'
	OR tab.name like 'SX5%'
	OR tab.name like 'DC3%'
	OR tab.name like 'SZS%'
	OR tab.name like 'SPI%'


/* =================== NÃO ALTERAR =================*/
	
	

IF OBJECT_ID('tempdb..#temp_tables_indice') IS NOT NULL
	DROP TABLE #temp_tables_indice

CREATE TABLE #temp_tables_indice (
	id int identity
	,table_schema sysname
	,table_name sysname
)

INSERT INTO #temp_tables_indice (table_schema,table_name)
SELECT table_schema,table_name FROM #temp_tables





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


/*================= GERAR TRIGGERS ===================*/
PRINT '

'
PRINT 'USE '+QUOTENAME(DB_NAME())
PRINT 'GO'

WHILE (SELECT COUNT(1) FROM #temp_table_constraints) > 0
BEGIN
	SELECT @table_schema = tb.TABLE_SCHEMA ,@table_name = tb.TABLE_NAME FROM #temp_table_constraints tb ORDER BY table_schema, table_name
	
	PRINT'
CREATE TRIGGER '+ @table_schema +'.['+ SUBSTRING(PARSENAME(@table_name,1),1,3) +'_DTALTERACAO_'+ SUBSTRING(PARSENAME(@table_name,1),3,3) +'+]
ON '+@table_schema + '.' + @table_name +'
FOR UPDATE, INSERT
AS
	BEGIN
		UPDATE	A
		SET		'+SUBSTRING(PARSENAME(@table_name,1),2,2)+@_YDTALTE+' = CONVERT(VARCHAR, GETDATE(), 112),
				'+SUBSTRING(PARSENAME(@table_name,1),2,2)+@+_YHRALTE+' = SUBSTRING(CONVERT(VARCHAR, GETDATE(), 8), 1, 5)
		FROM	'+@table_schema + '.' + @table_name+' A
				JOIN inserted B
				ON A.R_E_C_N_O_ = B.R_E_C_N_O_
	END 
	' 

	DELETE #temp_table_constraints  WHERE table_schema= @table_schema AND table_name = @table_name

END


/*================= GERAR ÍNDICES PELAS DATAS ===================*/

WHILE (SELECT COUNT(1) FROM #temp_tables_indice) > 0
BEGIN
	SELECT @table_schema = tb.TABLE_SCHEMA ,@table_name = tb.TABLE_NAME FROM #temp_tables_indice tb ORDER BY table_schema, table_name
	
	PRINT'
CREATE TRIGGER '+ @table_schema +'.['+ SUBSTRING(PARSENAME(@table_name,1),1,3) +'_DTALTERACAO_'+ SUBSTRING(PARSENAME(@table_name,1),3,3) +'+]
ON '+@table_schema + '.' + @table_name +'
FOR UPDATE, INSERT
AS
	BEGIN
		UPDATE	A
		SET		'+SUBSTRING(PARSENAME(@table_name,1),2,2)+@COLUMN_DT' = CONVERT(VARCHAR, GETDATE(), 112),
				'SUBSTRING(PARSENAME(@table_name,1),2,2)+@+COLUMN_HR' = SUBSTRING(CONVERT(VARCHAR, GETDATE(), 8), 1, 5)


	CREATE NONCLUSTERED INDEX '+PARSENAME(@table_name,1)+'W01 ON '+@table_schema + '.' + @table_name +'('+SUBSTRING(PARSENAME(@table_name,1),2,2)+@COLUMN_DT+','+SUBSTRING(PARSENAME(@table_name,1),2,2)+@+COLUMN_HR+') WITH(DATA_COMPRESSION=PAGE)
	' 

	DELETE #temp_tables_indice  WHERE table_schema= @table_schema AND table_name = @table_name

END
