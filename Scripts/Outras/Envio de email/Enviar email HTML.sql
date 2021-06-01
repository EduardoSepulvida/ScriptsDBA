
  
	IF ( OBJECT_ID('[dbo].[HTML_Parameter]') IS NOT NULL )
		DROP TABLE [dbo].HTML_Parameter

	CREATE TABLE HTML_Parameter (
		Company_Link VARCHAR(4000),
		Line_Space VARCHAR(4000),
		Header VARCHAR(4000))

	INSERT INTO HTML_Parameter(Company_Link,Line_Space,Header)
	SELECT '<br />
			<br />'			
			+ 
				'<a href="http://www.powertuning.com.br" target=”_blank”> 
					<img	src="https://www.fabriciolima.net/wp-content/uploads/2020/02/logotipo-powertuning-v2.png"
							height="150" width="400"/>
				</a>',

				'<br />
					<br />',

				'<font color=black bold=true size=5>
						<BR /> HEADERTEXT <BR />
						</font>'	

GO
IF ( OBJECT_ID('dbo.stpSend_Dbmail') IS NOT NULL ) 
	DROP PROCEDURE [dbo].stpSend_Dbmail
GO

	CREATE PROCEDURE stpSend_Dbmail @Ds_Profile_Email VARCHAR(200), @Ds_Email VARCHAR(500),@Ds_Subject VARCHAR(500),@Ds_Mail_HTML VARCHAR(MAX),@Ds_BodyFormat VARCHAR(50),@Ds_Importance VARCHAR(50)
			AS					
				EXEC msdb.dbo.sp_send_dbmail
					@profile_name = @Ds_Profile_Email,
					@recipients =	@Ds_Email,
					@subject =		@Ds_Subject,
					@body =			@Ds_Mail_HTML,
					@body_format =	@Ds_BodyFormat,
					@importance =	@Ds_Importance			

GO
GO

IF ( OBJECT_ID('[dbo].[stpExport_Table_HTML_Output]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].stpExport_Table_HTML_Output
GO

CREATE PROCEDURE [dbo].[stpExport_Table_HTML_Output]
    @Ds_Tabela [varchar](max),
    @Fl_Aplica_Estilo_Padrao BIT = 1,
	@Ds_Alinhamento VARCHAR(10) = 'left',
	@Ds_OrderBy VARCHAR(MAX) = '',
    @Ds_Saida VARCHAR(MAX) OUTPUT
AS
BEGIN
    /*
		--retirado do código 23/07
		table { padding:0; border-spacing: 0; border-collapse: collapse; }
		
		Autor: Dirceu Resende
		Post: https://www.dirceuresende.com/blog/como-exportar-dados-de-uma-tabela-do-sql-server-para-html/
	*/
			SET NOCOUNT ON
        
			DECLARE
				@query NVARCHAR(MAX),
				@Database sysname,
				@Nome_Tabela sysname

    
    
			IF (LEFT(@Ds_Tabela, 1) = '#')
			BEGIN
				SET @Database = 'tempdb.'
				SET @Nome_Tabela = @Ds_Tabela
			END
			ELSE BEGIN
				SET @Database = LEFT(@Ds_Tabela, CHARINDEX('.', @Ds_Tabela))
				SET @Nome_Tabela = SUBSTRING(@Ds_Tabela, LEN(@Ds_Tabela) - CHARINDEX('.', REVERSE(@Ds_Tabela)) + 2, LEN(@Ds_Tabela))
			END

    
			SET @query = '
			SELECT ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE
			FROM ' + @Database + 'INFORMATION_SCHEMA.COLUMNS 
			WHERE TABLE_NAME = ''' + @Nome_Tabela + '''
			ORDER BY ORDINAL_POSITION'
    
    
			IF (OBJECT_ID('tempdb..#Colunas') IS NOT NULL) DROP TABLE #Colunas
			CREATE TABLE #Colunas (
				ORDINAL_POSITION int, 
				COLUMN_NAME sysname, 
				DATA_TYPE nvarchar(128), 
				CHARACTER_MAXIMUM_LENGTH int,
				NUMERIC_PRECISION tinyint, 
				NUMERIC_SCALE int
			)

			INSERT INTO #Colunas
			EXEC(@query)

    
    
			IF (@Fl_Aplica_Estilo_Padrao = 1)
			BEGIN
    
			SET @Ds_Saida = '<html>

		<head>
			<title>Titulo</title>
			<style type="text/css">				

				 table { border: outset 2.25pt; }
                thead { background: #0B0B61; }
                th { color: #fff; padding: 10px;}
                td { padding: 3.0pt 3.0pt 3.0pt 3.0pt; text-align:' + @Ds_Alinhamento + '; }
			</style>
		</head>';
    
			END
       
    
			SET @Ds_Saida = ISNULL(@Ds_Saida, '') + '
		<table border="1" cellpadding="0">
			<thead>
				<tr>'
											

			DECLARE @totalColunas INT 
			SET @totalColunas = (SELECT COUNT(*) FROM #Colunas)

			-- Cabeçalho da tabela
			DECLARE @contadorColuna INT 			
			SET @contadorColuna = 1
						
			declare
				@nomeColuna sysname,
				@tipoColuna sysname
    	
	
			WHILE(@contadorColuna <= @totalColunas)
			BEGIN

				SELECT @nomeColuna = COLUMN_NAME
				FROM #Colunas
				WHERE ORDINAL_POSITION = @contadorColuna


				SET @Ds_Saida = ISNULL(@Ds_Saida, '') + '
					<th>' + @nomeColuna + '</th>'


				SET @contadorColuna = @contadorColuna + 1

			END
			

			SET @Ds_Saida = ISNULL(@Ds_Saida, '') + '
				</tr>
			</thead>
			<tbody>'

    
			-- Conteúdo da tabela

			DECLARE @saida VARCHAR(MAX)

			SET @query = '
		SELECT @saida = (
			SELECT '


			SET @contadorColuna = 1

			WHILE(@contadorColuna <= @totalColunas)
			BEGIN

				SELECT 
					@nomeColuna = COLUMN_NAME,
					@tipoColuna = DATA_TYPE
				FROM 
					#Colunas
				WHERE 
					ORDINAL_POSITION = @contadorColuna



				IF (@tipoColuna IN ('int', 'bigint', 'float', 'numeric', 'decimal', 'bit', 'tinyint', 'smallint', 'integer'))
				BEGIN
        
					SET @query = @query + '
			ISNULL(CAST([' + @nomeColuna + '] AS VARCHAR(MAX)), '''') AS [td]'
    
				END
				ELSE BEGIN
        
					SET @query = @query + '
			ISNULL([' + @nomeColuna + '], '''') AS [td]'
    
				END
    
        
				IF (@contadorColuna < @totalColunas)
					SET @query = @query + ','

        
				SET @contadorColuna = @contadorColuna + 1

			END



			SET @query = @query + '
		FROM ' + @Ds_Tabela + (CASE WHEN ISNULL(@Ds_OrderBy, '') = '' THEN '' ELSE ' 
		ORDER BY ' END) + @Ds_OrderBy + '
		FOR XML RAW(''tr''), Elements
		)'
    
    
			EXEC tempdb.sys.sp_executesql
				@query,
				N'@saida NVARCHAR(MAX) OUTPUT',
				@saida OUTPUT


			-- Identação
			SET @saida = REPLACE(@saida, '<tr>', '
				<tr>')

			SET @saida = REPLACE(@saida, '<td>', '
					<td>')

			SET @saida = REPLACE(@saida, '</tr>', '
				</tr>')


			SET @Ds_Saida = ISNULL(@Ds_Saida, '') + @saida


    
			SET @Ds_Saida = ISNULL(@Ds_Saida, '') + '
			</tbody>
		</table>'
    
            
END

GO
IF ( OBJECT_ID('[dbo].[stpExport_Table_HTML_Output]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].stpExport_Table_HTML_Output
GO

CREATE PROCEDURE [dbo].[stpExport_Table_HTML_Output]
    @Ds_Tabela [varchar](max),
    @Fl_Aplica_Estilo_Padrao BIT = 1,
	@Ds_Alinhamento VARCHAR(10) = 'left',
	@Ds_OrderBy VARCHAR(MAX) = '',
    @Ds_Saida VARCHAR(MAX) OUTPUT
AS
BEGIN
    /*
		--retirado do código 23/07
		table { padding:0; border-spacing: 0; border-collapse: collapse; }
		
		Autor: Dirceu Resende
		Post: https://www.dirceuresende.com/blog/como-exportar-dados-de-uma-tabela-do-sql-server-para-html/
	*/
			SET NOCOUNT ON
        
			DECLARE
				@query NVARCHAR(MAX),
				@Database sysname,
				@Nome_Tabela sysname

    
    
			IF (LEFT(@Ds_Tabela, 1) = '#')
			BEGIN
				SET @Database = 'tempdb.'
				SET @Nome_Tabela = @Ds_Tabela
			END
			ELSE BEGIN
				SET @Database = LEFT(@Ds_Tabela, CHARINDEX('.', @Ds_Tabela))
				SET @Nome_Tabela = SUBSTRING(@Ds_Tabela, LEN(@Ds_Tabela) - CHARINDEX('.', REVERSE(@Ds_Tabela)) + 2, LEN(@Ds_Tabela))
			END

    
			SET @query = '
			SELECT ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE
			FROM ' + @Database + 'INFORMATION_SCHEMA.COLUMNS 
			WHERE TABLE_NAME = ''' + @Nome_Tabela + '''
			ORDER BY ORDINAL_POSITION'
    
    
			IF (OBJECT_ID('tempdb..#Colunas') IS NOT NULL) DROP TABLE #Colunas
			CREATE TABLE #Colunas (
				ORDINAL_POSITION int, 
				COLUMN_NAME sysname, 
				DATA_TYPE nvarchar(128), 
				CHARACTER_MAXIMUM_LENGTH int,
				NUMERIC_PRECISION tinyint, 
				NUMERIC_SCALE int
			)

			INSERT INTO #Colunas
			EXEC(@query)

    
    
			IF (@Fl_Aplica_Estilo_Padrao = 1)
			BEGIN
    
			SET @Ds_Saida = '<html>

		<head>
			<title>Titulo</title>
			<style type="text/css">				

				 table { border: outset 2.25pt; }
                thead { background: #0B0B61; }
                th { color: #fff; padding: 10px;}
                td { padding: 3.0pt 3.0pt 3.0pt 3.0pt; text-align:' + @Ds_Alinhamento + '; }
			</style>
		</head>';
    
			END
       
    
			SET @Ds_Saida = ISNULL(@Ds_Saida, '') + '
		<table border="1" cellpadding="0">
			<thead>
				<tr>'
											

			DECLARE @totalColunas INT 
			SET @totalColunas = (SELECT COUNT(*) FROM #Colunas)

			-- Cabeçalho da tabela
			DECLARE @contadorColuna INT 			
			SET @contadorColuna = 1
						
			declare
				@nomeColuna sysname,
				@tipoColuna sysname
    	
	
			WHILE(@contadorColuna <= @totalColunas)
			BEGIN

				SELECT @nomeColuna = COLUMN_NAME
				FROM #Colunas
				WHERE ORDINAL_POSITION = @contadorColuna


				SET @Ds_Saida = ISNULL(@Ds_Saida, '') + '
					<th>' + @nomeColuna + '</th>'


				SET @contadorColuna = @contadorColuna + 1

			END
			

			SET @Ds_Saida = ISNULL(@Ds_Saida, '') + '
				</tr>
			</thead>
			<tbody>'

    
			-- Conteúdo da tabela

			DECLARE @saida VARCHAR(MAX)

			SET @query = '
		SELECT @saida = (
			SELECT '


			SET @contadorColuna = 1

			WHILE(@contadorColuna <= @totalColunas)
			BEGIN

				SELECT 
					@nomeColuna = COLUMN_NAME,
					@tipoColuna = DATA_TYPE
				FROM 
					#Colunas
				WHERE 
					ORDINAL_POSITION = @contadorColuna



				IF (@tipoColuna IN ('int', 'bigint', 'float', 'numeric', 'decimal', 'bit', 'tinyint', 'smallint', 'integer'))
				BEGIN
        
					SET @query = @query + '
			ISNULL(CAST([' + @nomeColuna + '] AS VARCHAR(MAX)), '''') AS [td]'
    
				END
				ELSE BEGIN
        
					SET @query = @query + '
			ISNULL([' + @nomeColuna + '], '''') AS [td]'
    
				END
    
        
				IF (@contadorColuna < @totalColunas)
					SET @query = @query + ','

        
				SET @contadorColuna = @contadorColuna + 1

			END



			SET @query = @query + '
		FROM ' + @Ds_Tabela + (CASE WHEN ISNULL(@Ds_OrderBy, '') = '' THEN '' ELSE ' 
		ORDER BY ' END) + @Ds_OrderBy + '
		FOR XML RAW(''tr''), Elements
		)'
    
    
			EXEC tempdb.sys.sp_executesql
				@query,
				N'@saida NVARCHAR(MAX) OUTPUT',
				@saida OUTPUT


			-- Identação
			SET @saida = REPLACE(@saida, '<tr>', '
				<tr>')

			SET @saida = REPLACE(@saida, '<td>', '
					<td>')

			SET @saida = REPLACE(@saida, '</tr>', '
				</tr>')


			SET @Ds_Saida = ISNULL(@Ds_Saida, '') + @saida


    
			SET @Ds_Saida = ISNULL(@Ds_Saida, '') + '
			</tbody>
		</table>'
    
            
END

GO