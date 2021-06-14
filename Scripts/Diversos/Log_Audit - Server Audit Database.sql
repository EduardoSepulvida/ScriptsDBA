--
/*
USE [master]
GO

CREATE SERVER AUDIT [Audit-Demo-DDL]
TO FILE 
(	FILEPATH = N'D:\LogAudit'
	,MAXSIZE = 1 GB
	,MAX_ROLLOVER_FILES = 2147483647
	,RESERVE_DISK_SPACE = OFF
) WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE)
WHERE database_name = 'Teste'
GO


ALTER SERVER AUDIT SPECIFICATION [Spec-Demo-DDL]
FOR SERVER AUDIT [Audit-Demo-DDL]	
	ADD (SERVER_OBJECT_CHANGE_GROUP) ,             -- CREATE, ALTER, or DROP operations on server objects	
	ADD (SCHEMA_OBJECT_CHANGE_GROUP)
WITH (STATE=ON)
*/
/*
--remove
use master; 
alter server audit specification [Spec-Demo-DDL] with (state = off);
drop server audit specification [Spec-Demo-DDL]
alter server audit [Audit-Demo-DDL] with (state = off)
drop server audit [Audit-Demo-DDL]

*/
--drop table Log_AuditDatabase
--drop DATABASE TRACES


	SET XACT_ABORT ON;

	IF (SELECT COUNT(1) FROM sys.databases where name = 'Traces') = 0
	BEGIN
		CREATE DATABASE Traces
		ALTER DATABASE Traces SET RECOVERY SIMPLE
	END
	GO

	IF OBJECT_ID('Traces..Log_AuditDatabase') IS NULL
		CREATE TABLE Traces..Log_AuditDatabase(
			 id bigint identity(1,1) PRIMARY KEY
			 ,event_time datetime2
			 ,action_id varchar(4)
			 ,class_type varchar(2)
			 ,host_name nvarchar(4000)
			 ,session_server_principal_name sysname
			 ,server_principal_name sysname
			 ,database_principal_name sysname
			 ,server_instance_name sysname
			 ,database_name sysname
			 ,schema_name sysname
			 ,object_name sysname
			 ,statement nvarchar(4000)
			 ,succeeded bit
			 ,client_ip nvarchar(128)
			 ,application_name nvarchar(128)
			 ,duration_milliseconds bigint
		)WITH(DATA_COMPRESSION=PAGE)
	GO

	DECLARE	@dir nvarchar(256)
			,@max datetime2

	select @dir = audit_file_path from sys.dm_server_audit_status where name = 'Audit-Demo-DDL'
	select @max = max(event_time) from Traces..Log_AuditDatabase 


	insert into Traces..Log_AuditDatabase(
		event_time 
		,action_id 
		,class_type
		,host_name 
		,session_server_principal_name  
		,server_principal_name  
		,database_principal_name  
		,server_instance_name  
		,database_name  
		,schema_name  
		,object_name  
		,statement 
		,succeeded 
		,client_ip  
		,application_name  
		,duration_milliseconds  
	)
	SELECT		
		event_time 
		,action_id 
		,class_type
		,host_name 
		,session_server_principal_name  
		,server_principal_name  
		,database_principal_name  
		,server_instance_name  
		,database_name  
		,schema_name  
		,object_name  
		,statement 
		,succeeded 
		,client_ip  
		,application_name  
		,duration_milliseconds  
	 FROM sys.fn_get_audit_file (@dir,default,default) WHERE event_time > @max or @max is null


	 select * from Traces..Log_AuditDatabase order by 1 desc

