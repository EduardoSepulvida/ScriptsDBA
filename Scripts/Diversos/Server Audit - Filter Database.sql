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
	ADD (DATABASE_CHANGE_GROUP),                   -- database is created, altered, or dropped
	ADD (DATABASE_OBJECT_CHANGE_GROUP),            -- CREATE, ALTER, or DROP statement is executed on database objects, such as schemas
	--ADD (DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP),  -- 
	--ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP), -- a GRANT, REVOKE, or DENY has been issued for database objects, such as assemblies and schemas
	--ADD (DATABASE_OWNERSHIP_CHANGE_GROUP),         -- use of ALTER AUTHORIZATION statement to change the owner of a database, and the permissions that are required to do that are checked
	--ADD (DATABASE_PERMISSION_CHANGE_GROUP),        -- GRANT, REVOKE, or DENY is issued for a statement permission by any principal in SQL Server 
	--ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),         -- raised when principals, such as users, are created, altered, or dropped from a database.
	--ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),       -- a login is added to or removed from a database role. This event class is raised for the sp_addrolemember, sp_changegroup, and sp_droprolemember stored procedures
	--ADD (LOGIN_CHANGE_PASSWORD_GROUP),             -- a login password is changed by way of ALTER LOGIN statement or sp_password stored procedure
	ADD (SERVER_OBJECT_CHANGE_GROUP) ,             -- CREATE, ALTER, or DROP operations on server objects
	--ADD (SERVER_OBJECT_OWNERSHIP_CHANGE_GROUP),    -- owner is changed for objects in the server scope. 
	--ADD (SERVER_OBJECT_PERMISSION_CHANGE_GROUP),   -- GRANT, REVOKE, or DENY is issued for a server object permission by any principal in SQL Server
	--ADD (SERVER_PERMISSION_CHANGE_GROUP),          -- GRANT, REVOKE, or DENY is issued for permissions in the server scope, such as creating a login.
	--ADD (SERVER_PRINCIPAL_CHANGE_GROUP),           -- server principals are created, altered, or dropped. 
	--											   -- a principal issues the sp_defaultdb or sp_defaultlanguage stored procedures or ALTER LOGIN statements
	--											   -- sp_addlogin and sp_droplogin stored procedures.
	--											   -- sp_grantlogin or sp_revokelogin stored procedures
	--ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),          -- a login is added or removed from a fixed server role. This event is raised for the sp_addsrvrolemember and sp_dropsrvrolemember stored procedures. 
	ADD (SCHEMA_OBJECT_CHANGE_GROUP)
WITH (STATE=ON)

alter server audit [Audit-Demo-DDL] with (state = on)
alter server audit specification [Spec-Demo-DDL] with (state = on);


select * from sys.dm_server_audit_status

SELECT * FROM sys.fn_get_audit_file ('D:\LogAudit\Audit-Demo-DDL_7AE27FE8-45F2-4F93-BDE3-BE69B239D09C_0_132665310606380000.sqlaudit',default,default);  


--remove
use master; 
alter server audit specification [Spec-Demo-DDL] with (state = off);
drop server audit specification [Spec-Demo-DDL]
alter server audit [Audit-Demo-DDL] with (state = off)
drop server audit [Audit-Demo-DDL]


/*
use Teste
go

create table tb_02 (cl1 int)

alter table tb_02 add cl3 int

DROP TABLE tb_02

create proc stp01
as 
begin
	select 1	
end

exec stp01

alter proc stp01
as 
begin
	select 2	
end 

drop proc stp01
*/