CREATE OR ALTER PROCEDURE stpAlertChangeTracking
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @Company_Link  VARCHAR(4000)='',@Line_Space VARCHAR(4000)='',@Header_Default VARCHAR(4000)='',@Header VARCHAR(4000)='',@Fl_Language BIT,@Final_HTML VARCHAR(MAX)='',@HTML VARCHAR(MAX)='',@Ds_Subject VARCHAR(500)


	-- VERIFICA QUAIS BANCOS TEM CT
	IF OBJECT_ID('tempdb..#ct_databases_disable') IS NOT NULL
	DROP TABLE #ct_databases_disable

	IF OBJECT_ID('tempdb..#ct_databases_on') IS NOT NULL
	DROP TABLE #ct_databases_on


	SELECT 
			db.name 
		INTO #ct_databases_on
		FROM sys.change_tracking_databases ct 
		JOIN sys.databases db ON db.database_id = ct.database_id 

	SELECT
			database_name = name 
			,ct_status = CASE WHEN x.qtd > 0 THEN 'ENABLE' ELSE 'DISABLE' END
		INTO #ct_databases_disable
		FROM Traces..ct_databases_controll ct
		CROSS APPLY (SELECT COUNT(1) qtd FROM #ct_databases_on db WHERE db.name = ct.name)x


	-- VERIFICA QUAIS TABELAS TEM CT
	IF OBJECT_ID('tempdb..#ct_tables_controll') IS NOT NULL
	DROP TABLE #ct_tables_controll

	CREATE TABLE #ct_tables_controll(
		database_name sysname
		,schema_name sysname	
		,table_name sysname
		,object_hash varbinary(8000) 
	)

	EXEC sp_MSforeachdb 'use [?] 
	INSERT INTO #ct_tables_controll
	SELECT 
		db_name() database_name
		,sct2.name as schema_name
		,sot2.name as table_name
		,HASHBYTES(''SHA2_256'', db_name()+sct2.name+sot2.name) object_hash
	FROM sys.internal_tables it
	JOIN sys.objects sot1 on it.object_id=sot1.object_id
	JOIN sys.schemas AS sct1 ON sot1.schema_id=sct1.schema_id
	JOIN sys.dm_db_partition_stats ps1 ON it.object_id = ps1. object_id AND ps1.index_id in (0,1)
	LEFT JOIN sys.objects sot2 on it.parent_object_id=sot2.object_id
	JOIN sys.change_tracking_tables AS ctt ON ctt.object_id = sot2.object_id
	LEFT JOIN sys.schemas AS sct2 ON sot2.schema_id=sct2.schema_id
	WHERE it.internal_type IN (209, 210)
	'

	IF OBJECT_ID('tempdb..#ct_tables_disable') IS NOT NULL
	DROP TABLE #ct_tables_disable

	SELECT
		ct.database_name
		,ct.schema_name
		,ct.table_name
		,ct_status = CASE WHEN x.qtd > 0 THEN 'ENABLE' ELSE 'DISABLE' END
	INTO #ct_tables_disable
	FROM Traces..ct_tables_controll ct
	CROSS APPLY (SELECT COUNT(1) qtd FROM #ct_tables_controll db WHERE db.object_hash = ct.object_hash)x



	IF(SELECT COUNT(1) FROM #ct_tables_disable WHERE ct_status= 'DISABLE') > 0 OR (SELECT COUNT(1) FROM #ct_databases_disable WHERE ct_status = 'DISABLE')> 0
	BEGIN
		
			
				IF ( OBJECT_ID('tempdb..##Email_HTML') IS NOT NULL )
						DROP TABLE ##Email_HTML	
			
				-- Dados da Tabela do EMAIL
				SELECT 
						database_name [database_name]
						,schema_name [schema_name]
						,table_name [table_name]
						,ct_status [ct_status]
				INTO ##Email_HTML	
				FROM #ct_tables_disable	
			

				IF ( OBJECT_ID('tempdb..##Email_HTML_2') IS NOT NULL )
						DROP TABLE ##Email_HTML_2	
				 	
				SELECT TOP 50 *
				INTO ##Email_HTML_2
				FROM #ct_databases_disable
		
				
				-- Get HTML Informations
				SELECT @Company_Link = Company_Link,
					@Line_Space = Line_Space,
					@Header_Default = Header
				FROM Traces..HTML_Parameter

			
				SET @Header = REPLACE(@Header_Default,'HEADERTEXT','Change Tracking - Table status:')
				SET @Ds_Subject =  'ALERTA - Há objetos com o Change Tracking desabilitados no server: '+@@SERVERNAME 
			
				EXEC dbo.stpExport_Table_HTML_Output
					@Ds_Tabela = '##Email_HTML', -- varchar(max)
					@Ds_Alinhamento  = 'center',
					@Ds_OrderBy = '4,1,2,3',
					@Ds_Saida = @HTML OUT				-- varchar(max)

				-- First Result
				SET @Final_HTML = @Header + @Line_Space + @HTML + @Line_Space 		
			
			
			
				EXEC dbo.stpExport_Table_HTML_Output
					@Ds_Tabela = '##Email_HTML_2', -- varchar(max)				
					@Ds_Alinhamento  = 'center',
					@Ds_OrderBy = '2,1',
					@Ds_Saida = @HTML OUT				-- varchar(max)			
			
				SET @Header = REPLACE(@Header_Default,'HEADERTEXT','Change Tracking - Databases status:')
				SET @Final_HTML = @Final_HTML + @Header + @Line_Space + @HTML + @Line_Space 		
			

			
			
				SET @Final_HTML = @Final_HTML + @Company_Link	
			

				--EXEC stpSend_Dbmail @Ds_Profile_Email,@Ds_Email,@Ds_Subject,@Final_HTML,'HTML','High'							
				PRINT @Final_HTML					
		
		
		END

END