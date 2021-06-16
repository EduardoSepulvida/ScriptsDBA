/*
ALTER TABLE [TABLE_NAME] ENABLE CHANGE_TRACKING  
GO

*/


SET NOCOUNT ON

/*
--PARA DEIXAR DINAMICO, DEVE ALTERAR O NOME DAS COLUNAS NO PRINT DA VIEW 
DECLARE  @COLUMN_DT sysname = '_YDTALTE'
		,@COLUMN_HR sysname = '_YHRALTE'	
*/
DECLARE  @COLUMN_DT sysname = 'BI_YDTALTE'
		,@COLUMN_HR sysname = 'BI_YHRALTE'		
		,@table_del_prefix sysname = 'DEL_'
		,@table_delta_prefix sysname = 'DELTA_'
		

IF OBJECT_ID('tempdb..#temp_tables') IS NOT NULL
	DROP TABLE #temp_tables

CREATE TABLE #temp_tables (
	id int identity
	,table_schema sysname
	,table_name sysname
	,table_prefix sysname
	,table_column_dt sysname
	,table_column_hr sysname
)

INSERT INTO #temp_tables (table_schema,table_name,table_prefix,table_column_dt,table_column_hr)
SELECT 
	schema_name(tab.schema_id)
    ,tab.[name] COLLATE SQL_Latin1_General_CP1_CI_AS
	,CASE WHEN LEN(prefix_final.prefix) > 3 THEN 'BI' ELSE prefix_final.prefix END prefix
	,CASE WHEN prefix_limit = 0 THEN @COLUMN_DT ELSE SUBSTRING(prefix.name,1,prefix_limit-1)+@COLUMN_DT END table_column_dt
	,CASE WHEN prefix_limit = 0 THEN @COLUMN_HR ELSE SUBSTRING(prefix.name,1,prefix_limit-1)+@COLUMN_HR END table_column_hr
FROM 
	sys.tables tab 
OUTER APPLY(
	SELECT 
		TOP 1 cl.name, CHARINDEX('_',cl.name,1) prefix_limit
	FROM 
		sys.columns cl			WHERE 1=1
		AND tab.object_id = cl.object_id			
)prefix
OUTER APPLY(
	SELECT CASE WHEN prefix_limit = 0 THEN tab.[name] ELSE SUBSTRING(prefix.name,1,prefix_limit-1) END prefix
)prefix_final

WHERE 
	tab.name like 'SB9%'
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
	OR tab.name like 'SDC%'
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


--TAB: DESCONSIDERAR
select * from #temp_tables where len(table_name) > 6 AND table_name NOT IN ('VIX_PRO_003','SD398')

DELETE #temp_tables where len(table_name) > 6 AND table_name IN ('VIX_PRO_003','SD398')

-- TAB: CONSIDERAR
select * from #temp_tables

/* =================== NÃO ALTERAR =================*/
	

/* =================== TABELA PARA GERAÇÃO DAS VIEWS  =================*/
IF OBJECT_ID('tempdb..#temp_views') IS NOT NULL
	DROP TABLE #temp_views

CREATE TABLE #temp_views (
	id int identity
	,table_schema sysname
	,table_name sysname
	,table_prefix sysname
	,table_column_dt sysname
	,table_column_hr sysname

)

INSERT INTO #temp_views (table_schema,table_name,table_prefix,table_column_dt,table_column_hr)
SELECT table_schema,table_name,table_prefix,table_column_dt,table_column_hr FROM #temp_tables



/* ================= ======================= =================*/

DECLARE @bases varchar(max) =''
		,@table_schema sysname =''
		,@table_name sysname =''
		,@table_indice varchar(2)=''
		,@qtd int
		,@prefix sysname =''
		,@table_column_dt sysname =''
		,@table_column_hr sysname =''
		,@posfix sysname =''



/*============== QUANTIDADE OBJETOS ==================*/
PRINT('/*')
SELECT @qtd = COUNT(1) FROM #temp_tables
PRINT('Qtd de Tabelas: ' + CAST(@qtd AS VARCHAR(10)))
PRINT('*/')
PRINT('')

/*================= GERAR TRIGGERS ===================*/
PRINT '

/*
	
	ESTE SCRIPT NÃO DROPA NENHUM OBJETO, APENAS CRIA OS QUE NÃO EXISTEM
	
	OBJETOS CRIADOS:
	- HABILITA CHANGE TRACKING NAS DATABASES
	- HABILITA CHANGE TRACKING NAS TABELAS
	- CRIAÇÃO DAS VIEWS DEL
	- CRIAÇÃO DAS VIEWS DELTA
	

*/

'


/*================= HABILITAR CHANGE TRACKING ===================*/

PRINT 'USE '+QUOTENAME(DB_NAME())
PRINT 'GO'


WHILE (SELECT COUNT(1) FROM #temp_tables) > 0
BEGIN
	SELECT TOP 1 @table_schema = tb.table_schema ,@table_name = tb.table_name FROM #temp_tables tb ORDER BY table_schema, table_name
	

	PRINT'
ALTER TABLE ' +@table_schema+'.' +@table_name+ ' ENABLE CHANGE_TRACKING
GO
'

	DELETE #temp_tables  WHERE table_schema= @table_schema AND table_name = @table_name

END


/*================= GERAR VIEW DEL ===================*/
PRINT ''
PRINT ''
PRINT 'USE '+QUOTENAME(DB_NAME())
PRINT 'GO'

WHILE (SELECT COUNT(1) FROM #temp_views) > 0
BEGIN
	SELECT TOP 1 @table_schema = tb.table_schema ,@table_name = tb.table_name, @prefix = tb.table_prefix, @table_column_dt = tb.table_column_dt, @table_column_hr = tb.table_column_hr FROM #temp_views tb ORDER BY table_schema, table_name
	
	PRINT'
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N''['+ @table_schema +'].['+ @table_del_prefix+@table_name +']''))
BEGIN 
	EXEC dbo.sp_executesql @statement = N''
	CREATE VIEW ['+ @table_schema +'].['+ @table_del_prefix+@table_name +']	
	AS
		SELECT    
			CT.R_E_C_N_O_
			,convert(varchar, CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, tc.commit_time), DATENAME(TzOffset, SYSDATETIMEOFFSET()))), 112)  '+@COLUMN_DT+'
			,substring(convert(varchar, CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, tc.commit_time), DATENAME(TzOffset, SYSDATETIMEOFFSET()))), 8),1,5) '+@COLUMN_HR+'
		FROM
			CHANGETABLE(CHANGES ['+DB_NAME()+']..['+@table_name+'], 0) AS CT    		  
		JOIN   
			['+DB_NAME()+'].[sys].[dm_tran_commit_table] tc   
			ON   
			CT.SYS_CHANGE_VERSION = tc.commit_ts
		WHERE CT.SYS_CHANGE_OPERATION =''''D''''
		
	''
END	

IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N''['+ @table_schema +'].['+ @table_delta_prefix+@table_name +']''))
BEGIN 
	EXEC dbo.sp_executesql @statement = N''
	CREATE VIEW ['+ @table_schema +'].['+ @table_delta_prefix+@table_name +']	
	AS
		SELECT    
			P.*
			,convert(varchar, CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, tc.commit_time), DATENAME(TzOffset, SYSDATETIMEOFFSET()))), 112)  '+@COLUMN_DT+'
			,substring(convert(varchar, CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset, tc.commit_time), DATENAME(TzOffset, SYSDATETIMEOFFSET()))), 8),1,5) '+@COLUMN_HR+'
		FROM    
			['+DB_NAME()+']..['+@table_name+'] AS P    
		RIGHT OUTER JOIN    
			CHANGETABLE(CHANGES ['+DB_NAME()+']..['+@table_name+'], 0) AS CT    
			ON    
			P.R_E_C_N_O_ = CT.R_E_C_N_O_    
		JOIN   
			sys.dm_tran_commit_table tc   
			ON   
			CT.SYS_CHANGE_VERSION = tc.commit_ts
		WHERE CT.SYS_CHANGE_OPERATION <>''''D''''
		

''
END
'

	DELETE #temp_views  WHERE table_schema= @table_schema AND table_name = @table_name

END
