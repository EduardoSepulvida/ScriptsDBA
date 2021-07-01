--PEGAR NOME DOS ARQUIVOS E CAMINHO
SELECT name,
physical_name AS CurrentLocation,
state_desc
FROM sys.master_files
WHERE database_id = DB_ID(N'<base>');


--SETAR NOVO CAMINHO
ALTER DATABASE <base>
MODIFY FILE (NAME = MSDBData, FILENAME = 'E:\SQlData\MSDBData.mdf');
GO
ALTER DATABASE <base>
MODIFY FILE (NAME = MSDBLog, FILENAME = 'F:\SQLLogs\MSDBLog.ldf');
GO


ALTER DATABASE <base> SET OFFLINE WITH ROLLBACK IMMEDIATE

-- COPIAR ARQUIVOS PARA NOVO LOCAL (NÃO MOVA, POIS SE CORROMPER TEM O ORIGINAL)

ALTER DATABASE <base> SET ONLINE WITH ROLLBACK IMMEDIATE

--VERIFICAR STATUS
SELECT name,
physical_name AS CurrentLocation,
state_desc
FROM sys.master_files
WHERE database_id = DB_ID(N'<base>');


-- APÓS TUDO OK, APAGAR OS ARQUIVO ANTIGO
-- SHIFT + DEL (SENAO VAI PRA LIXEIRA E FICA OCUPANDO ESPACO)
