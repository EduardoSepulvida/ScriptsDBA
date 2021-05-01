--PRIMARIO (ou SECUNDARIO)
	-- Retirar base do mirror:
	ALTER DATABASE <<DB NAME>> SET PARTNER OFF


--PRIMARIO
	-- EXECUTAR MOVIMENTAÇÃO
	-- REALIZAR BACKUP FULL
	-- PARA BKP DE LOG
	
--SECUNDARIO
	-- RESTORE FULL COM NORECOREY
	
--PRIMARIO	
	-- REALIZAR BKP LOG
	
--SECUNDARIO 
	-- RESTORE LOG COM NORECOREY
	-- COLOCAR BASE NO MIRROR, EX:
	ALTER DATABASE <<DB NAME>> SET PARTNER = N'TCP://'
	
--PRIMARIO 
	-- COLOCAR BASE NO MIRROR
	ALTER DATABASE <<DB NAME>> SET PARTNER = N'TCP://'
	
	
--CHECK SAFETY LEVEL:

	SELECT  databases.name AS DatabaseName,
		   database_mirroring.mirroring_state,
		   database_mirroring.mirroring_state_desc,
		   database_mirroring.mirroring_role_desc,
		   database_mirroring.mirroring_safety_level,
		   database_mirroring.mirroring_safety_level_desc,
		   database_mirroring.mirroring_safety_sequence FROM sys.database_mirroring    
	INNER JOIN sys.databases
	ON databases.database_id=database_mirroring.database_id

	--ALTER SAFETY LEVEL PARA FULL (CASO NECESSÁRIO)
	ALTER DATABASE [Protheus11Prd] SET SAFETY FULL

	
	--CHECK TIMEOUT MIRROR CONNECTION
	SELECT Mirroring_Connection_Timeout FROM sys.database_mirroring WHERE database_id = db_id('YourDB')
	
	-- ALTER TIMEOUT CONNECTION
	ALTER DATABASE [Protheus11Prd] SET PARTNER TIMEOUT 60