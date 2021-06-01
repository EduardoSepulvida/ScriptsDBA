create or alter PROCEDURE [dbo].[stpRestore_pwt_DIFF] @DatabaseDestino NVARCHAR(MAX) NULL
AS
BEGIN





    SET NOCOUNT ON;
    DECLARE @File_Exists INT;
    DECLARE @Filename_DIFF VARCHAR(8000);
	  DECLARE @Filename_FULL		 VARCHAR(8000);
    DECLARE @Ds_Caminho_Backup_Full NVARCHAR(MAX);
    DECLARE @sql VARCHAR(8000);
    DECLARE @FullRestoreSql VARCHAR(8000);
    DECLARE @LogicalName VARCHAR(8000);
    DECLARE @LogicalName_Log VARCHAR(8000);
    DECLARE @PhysicalName_Log VARCHAR(8000);
    DECLARE @PhysicalName VARCHAR(8000);
	 DECLARE @FullRestoreSql_R	 VARCHAR(8000);
	  DECLARE @tst	    nvarchar (max);
		  DECLARE @tst1	    nvarchar (max);
    --set	 @DatabaseDestino = 'Traces'

    IF (OBJECT_ID ('tempdb..#logical') IS NOT NULL)
        DROP TABLE #logical;

    SELECT
        d.name          DatabaseName
      , f.name          LogicalName
      , f.physical_name AS PhysicalName
      , f.type_desc     TypeofFile
    INTO #logical
    FROM sys.master_files        f
        INNER JOIN sys.databases d
            ON d.database_id = f.database_id
    WHERE d.name = @DatabaseDestino;

    SET @PhysicalName =
    (
        SELECT PhysicalName FROM #logical WHERE TypeofFile = 'ROWS'
    );
    SET @PhysicalName_Log =
    (
        SELECT PhysicalName FROM #logical WHERE TypeofFile = 'LOG'
    );
    SET @LogicalName =
    (
        SELECT LogicalName FROM #logical WHERE TypeofFile = 'ROWS'
    );
    SET @LogicalName_Log =
    (
        SELECT LogicalName FROM #logical WHERE TypeofFile = 'LOG'
    );






    IF (OBJECT_ID ('tempdb..#tmp') IS NOT NULL)
        DROP TABLE #tmp;

    SELECT
        DatabaseName    = R.name
      , LastFull        = b.backup_finish_date
      , b.FullSizeGB
      , LastDiff        = d.backup_finish_date
      , d.DiffSizeGB
      , FullRestoreSql  = 'RESTORE DATABASE ' + QUOTENAME (R.name) + ' from disk = ''' + b.FullRestorePath
                          + ''' WITH NORECOVERY,stats = 10'
      , FullRestoreDiff = 'RESTORE DATABASE ' + QUOTENAME (R.name) + ' from disk = ''' + d.DiffRestorePath
                          + ''' WITH RECOVERY,stats = 10'
      , d.DiffRestorePath
      , b.FullRestorePath
    INTO #tmp
    FROM
    (SELECT @DatabaseDestino) R(name)
        CROSS APPLY
    (
        SELECT TOP 1
               bs.backup_finish_date
             , backup_set_id
             , FullRestorePath = f.physical_device_name
             , FullSizeGB      = bs.compressed_backup_size / 1024 / 1024 / 1024
        FROM msdb.dbo.backupset             bs
            JOIN msdb.dbo.backupmediafamily f
                ON f.media_set_id = bs.media_set_id
        WHERE type = 'D'
              AND database_name = R.name
              AND is_copy_only = 0
        ORDER BY backup_set_id DESC
    )                         b
        OUTER APPLY
    (
        SELECT TOP 1
               bs.backup_finish_date
             , backup_set_id
             , DiffRestorePath = f.physical_device_name
             , DiffSizeGB      = bs.compressed_backup_size / 1024 / 1024 / 1024
        FROM msdb.dbo.backupset             bs
            JOIN msdb.dbo.backupmediafamily f
                ON f.media_set_id = bs.media_set_id
        WHERE type = 'I'
              AND database_name = R.name
              AND backup_finish_date > b.backup_finish_date
              AND is_copy_only = 0
        ORDER BY backup_set_id DESC
    ) d;

    SELECT *
    FROM #tmp;
    SET @Filename_DIFF =
    (
        SELECT TOP 1
               REPLACE (DiffRestorePath, 'E:', 'F:')
        FROM #tmp
        WHERE DatabaseName = @DatabaseDestino
        ORDER BY LastDiff DESC
    );
	  SET @Filename_FULL =
    (
        SELECT TOP 1
               REPLACE (FullRestorePath, 'E:', 'F:')
        FROM #tmp
        WHERE DatabaseName = @DatabaseDestino
        ORDER BY LastFull DESC
    );


    --SET @FullRestoreSql =
    --(
    --    SELECT TOP 1
    --           REPLACE (FullRestoreSql, 'E:', 'F:')
    --    FROM #tmp
    --    WHERE DatabaseName = @DatabaseDestino
    --    ORDER BY LastDiff DESC
    --);


    SET @FullRestoreSql = (' RESTORE DATABASE [' + @DatabaseDestino + '] FROM DISK = ''' + @Filename_FULL
           + '''
    WITH
        NORECOVERY
      , REPLACE
      , STATS = 1
      , MOVE ''' + @LogicalName + ''' TO ''' + @PhysicalName + '''
      , MOVE ''' + @LogicalName_Log + '''
        TO ''' + @PhysicalName_Log + ''';	
		GO'
          );
  SET @FullRestoreSql_R = (' RESTORE DATABASE [' + @DatabaseDestino + '] FROM DISK = ''' + @Filename_FULL
           + ''' 
    WITH
        RECOVERY
      , REPLACE
      , STATS = 1
      , MOVE ''' + @LogicalName + ''' TO ''' + @PhysicalName + '''
      , MOVE ''' + @LogicalName_Log + '''
        TO ''' + @PhysicalName_Log + ''';	
		GO'
          );

	--SET @tst = 'waitfor delay ''00:00:05'' '
	--set @tst1 = 'select 2+2'

     SET @sql = 'RESTORE DATABASE  [' + @DatabaseDestino + ']
 FROM DISK = '''   + @Filename_DIFF + '''
 WITH RECOVERY, REPLACE , STATS = 1 ';
    EXEC master.dbo.xp_fileexist @Filename_DIFF, @File_Exists OUT;
    IF @File_Exists = 1
    BEGIN
      exec sp_executesql @tst
		exec sp_executesql @tst1
		print(@FullRestoreSql)

    END;
    ELSE
	begin
	Print('No momento, não existe arquivo DIFF após último FULL, desta forma será restaurado apenas o FULL mais recente na base de dados '+@Databasedestino+'.' )
	print(@FullRestoreSql_R)
	end
	
    

	print @sql
--exec sp_executesql @sql	

END;