
CREATE OR ALTER PROCEDURE dbo.usp_bcpTableUnload (
      @path                NVARCHAR(900)
    , @serverName          SYSNAME = @@SERVERNAME
    , @databaseName        SYSNAME
    , @schemaName          SYSNAME
    , @tableName           SYSNAME
    , @fieldTerminator     NVARCHAR(10)  = '|'
    , @fileExtension       NVARCHAR(10)  = 'txt'
    , @codePage            NVARCHAR(10)  = 'C1251'
    , @excludeColumns      NVARCHAR(MAX) = ''
    , @orderByColumns      NVARCHAR(MAX) = ''
    , @outputColumnHeaders BIT = 1
    , @debug               BIT = 0
)
AS
/*
bcp docs: https://msdn.microsoft.com/ru-ru/library/ms162802.aspx
-- To allow advanced options to be changed.
EXEC sp_configure 'show advanced options', 1;
GO
-- To update the currently configured value for advanced options.
RECONFIGURE;
GO
-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO
EXECUTE [dbo].[usp_bcpTableUnload]
      @path                = 'd:\'
    , @databaseName        = 'DatabaseName'
    , @schemaName          = 'dbo'
    , @tableName           = 'TableName'
    , @fieldTerminator     = '|'
    , @fileExtension       = 'txt'
    , @excludeColumns      = '[CreatedDate],[ModifiedDate],[UserID]'
    , @orderByColumns      = 'TableNameID'
    , @outputColumnHeaders = 1
    , @debug               = 0;
*/
BEGIN

    BEGIN TRY
    IF @debug = 0 SET NOCOUNT ON;

    DECLARE @tsqlCommand     NVARCHAR(MAX) = '';
    DECLARE @cmdCommand      VARCHAR(8000)  = '';
    DECLARE @ParmDefinition  NVARCHAR(500) = '@object_idIN INTEGER, @ColumnsOUT VARCHAR(MAX) OUTPUT';
    DECLARE @tableFullName   NVARCHAR(500) = QUOTENAME(@databaseName) + '.' + QUOTENAME(@schemaName) + '.' + QUOTENAME(@tableName);
    DECLARE @object_id       INTEGER       = OBJECT_ID(@tableFullName);
    DECLARE @Columns         NVARCHAR(MAX) = '';
    DECLARE @filePath        NVARCHAR(900) = @path + @tableFullName + '.' + @fileExtension;
    DECLARE @crlf            NVARCHAR(10)  = CHAR(13);
    DECLARE @TROW50000       NVARCHAR(MAX) = ''

    IF @debug = 1 PRINT ISNULL('/******* Start Debug' + @crlf + '@tableFullName = {' + CAST(@tableFullName AS NVARCHAR) + '}', '@tableFullName = {Null}');
    IF @debug = 1 PRINT ISNULL('@object_id = {' + CAST(@object_id AS NVARCHAR) + '}', '@object_id = {Null}');

    SET @TROW50000 = 'Table ' + @tableFullName + ' is not exists in database ' + QUOTENAME(@databaseName) + '!!!';
    IF @OBJECT_ID IS NULL THROW 50000, @TROW50000, 1;

    SET @tsqlCommand = N'USE ' + @databaseName + ';'                                                            + @crlf +
                       N'SELECT @ColumnsOUT  = @ColumnsOUT + QUOTENAME(Name,CHAR(34)) + '','''					+ @crlf +
                       N'FROM sys.columns sac '                                                                 + @crlf +
                       N'WHERE sac.object_id = @object_idIN'                                                    + @crlf +
                       N'      AND QUOTENAME(Name) NOT IN (''' + REPLACE(@excludeColumns, ',', ''',''') + ''')' + @crlf +
                       N'ORDER BY column_id;';
				   
    IF @debug = 1 PRINT ISNULL(N'@tsqlCommand = {' + @crlf + @tsqlCommand + @crlf + N'}', N'@tsqlCommand = {Null}');

    EXECUTE sp_executesql @tsqlCommand, @ParmDefinition, @object_idIN = @object_id, @ColumnsOUT = @Columns OUTPUT SELECT @Columns;

    IF @debug = 1 PRINT ISNULL('@Columns = {' + @crlf + @Columns + @crlf + '}', '@Columns = {Null}');

    SET @Columns = CASE WHEN LEN(@Columns) > 0 THEN LEFT(@Columns, LEN(@Columns) - 1) END;

    IF @debug = 1 PRINT CAST(ISNULL('@Columns = {' + @Columns + '}', '@Columns = {Null}') AS TEXT);

    SET @tsqlCommand = 'EXECUTE xp_cmdshell ' +  '''bcp "SELECT ' + @Columns + '  FROM ' + @tableFullName + ' ORDER BY ' + @orderByColumns + '" queryout "' +  @filePath + '" -T -S ' + @serverName +' -c -' + @codePage + ' -t"' + @fieldTerminator + '"''' + @crlf;

    IF @debug = 1 PRINT CAST(ISNULL('@tsqlCommand = {' + @crlf + @tsqlCommand + @crlf + '}', '@tsqlCommand = {Null}' + @crlf) AS TEXT);
    ELSE EXECUTE sp_executesql @tsqlCommand;

    IF @outputColumnHeaders = 1
        BEGIN
             SET @tsqlCommand = 'EXECUTE xp_cmdshell ' +  '''bcp "SELECT ''''' + REPLACE(@Columns, ',', @fieldTerminator) + '''''" queryout "' +  @path + @tableFullName + '_headers.txt' + '" -T -S ' + @serverName + ' -c -' + @codePage + ' -t"' + @fieldTerminator + '"''' + @crlf;
        
             IF @debug = 1 PRINT CAST(ISNULL('@tsqlCommand = {' + @crlf + @tsqlCommand + @crlf + '}', '@tsqlCommand = {Null}' + @crlf) AS TEXT);
             ELSE EXECUTE sp_executesql @tsqlCommand;
        
             SET @cmdCommand = 'copy /b ' + @path + @tableFullName + '_headers.' + @fileExtension + ' + ' + @filePath + ' ' + @path + @tableFullName + '_headers.' + @fileExtension;
        
             IF @debug = 1 PRINT CAST(ISNULL('@cmdCommand = {' + @crlf + @cmdCommand + @crlf + '}', '@cmdCommand = {Null}' + @crlf) AS TEXT)
             ELSE EXECUTE xp_cmdshell @cmdCommand;
        
             SET @cmdCommand = 'del ' + @filePath;
        
             IF @debug = 1 PRINT CAST(ISNULL('@cmdCommand = {' + @crlf + @cmdCommand + @crlf + '}', '@cmdCommand = {Null}' + @crlf) AS TEXT)
             ELSE EXECUTE xp_cmdshell @cmdCommand;
        END

    IF @debug = 1 PRINT '--End Deubg*********/';
    ELSE SET NOCOUNT OFF;
    END TRY

    BEGIN CATCH
       -- EXECUTE dbo.usp_LogError;
       -- EXECUTE dbo.usp_PrintError;
    END CATCH
END;