﻿
/*

	O Script deve ser executado na base do protheus, mas você pode escolher gravar os dados
		em outra base sua de DBA (nesse exemplo usei uma base chamada Traces para isso).

	-- Teste curso

	UPDATE TOP (1000) dbo.SA1010
	SET D_E_L_E_T_ = '*'
	WHERE D_E_L_E_T_ = ''

	*/

	
	
	IF OBJECT_ID('Traces..Tabelas_Protheus_Expurgo_Deleted') IS NOT NULL
		DROP table Traces..Tabelas_Protheus_Expurgo_Deleted

	--Criar a tabela que terá o resultado final 
	create table Traces..Tabelas_Protheus_Expurgo_Deleted(
		Nm_Tabela varchar(50),
		Tamanho_Tabela bigint,
		Qtd_Registros_Tabela int,
		Qtd_Registros_Com_Deleted int	
		)

		--select count(*) from Traces..Tabelas_Protheus_Expurgo_Deleted (nolock)



	-- Rodar essa query e executar o Script em outra conexão

	DECLARE @Query NVARCHAR(MAX)
	SET @Query = ''

	SELECT @Query = @Query + 
		' insert into Traces..Tabelas_Protheus_Expurgo_Deleted (Nm_Tabela,Qtd_Registros_Com_Deleted)
		select '''+T.name+''',count(*) from '+T.name+ ' WITH(NOLOCK) where D_E_L_E_T_ = ''*''
	
		 '
	FROM
		sys.sysobjects    AS T (NOLOCK)
	INNER JOIN sys.all_columns AS C (NOLOCK) ON T.id = C.object_id AND T.XTYPE = 'U'
--	LEFT JOIN Traces..Tabelas_Protheus_Expurgo_Deleted X on X.Nm_Tabela = T.Name
	WHERE
		C.NAME = 'D_E_L_E_T_'
		--	and X.Nm_Tabela is null
			and user_Type_id = 167 --varchar padrao protheus (teve um cliente com esse campo com o tipo float)
	ORDER BY
		T.name ASC

	--	select @Query
	EXEC sp_executesql @Query


	-- select * from Traces..Tabelas_Protheus_Expurgo_Deleted
	
------ Query para validar o tamanho das tabelas -------------------------------

	IF object_id('tempdb..#tabelas') is not null drop table #tabelas
	
	IF object_id('tempdb..#Resultado_Final') is not null drop table #Resultado_Final
	
	
	;with table_space_usage (schema_name,table_Name,Index_name,used,reserved,ind_rows,tbl_rows,type_Desc)
	AS(
	select s.name, o.name,coalesce(i.name,'heap'),p.used_page_Count*8,
	p.reserved_page_count*8, p.row_count ,
	case when i.index_id in (0,1) then p.row_count else 0 end, i.type_Desc
	from sys.dm_db_partition_stats p
	join sys.objects o on o.object_id = p.object_id
	join sys.schemas s on s.schema_id = o.schema_id
	left join sys.indexes i on i.object_id = p.object_id and i.index_id = p.index_id
	where o.type_Desc = 'user_Table' and o.is_Ms_shipped = 0
	)
	
	-- sp_spaceused
	select t.schema_name, t.table_Name,t.Index_name,sum(t.used) as used_in_kb,
	sum(t.reserved) as reserved_in_kb,
	case grouping (t.Index_name) when 0 then sum(t.ind_rows) else sum(t.tbl_rows) end as rows,type_Desc
	into #tabelas
	from table_space_usage t
	group by t.schema_name, t.table_Name,t.Index_name,type_Desc
	with rollup
	order by grouping(t.schema_name),t.schema_name,grouping(t.table_Name),t.table_Name,
	grouping(t.Index_name),t.Index_name
	
	if object_id('Tempdb..#Resultado_Final') is not null drop table #Resultado_Final
	
	select schema_name, table_Name Name,sum(reserved_in_kb) [Reservado (KB)], sum(case when type_Desc in ('CLUSTERED','HEAP') then reserved_in_kb else 0 end) [Dados (KB)], 
		sum(case when type_Desc in ('NONCLUSTERED') then reserved_in_kb else 0 end) [Indices (KB)],
		max(rows) Qtd_Linhas		
	into #Resultado_Final
	from #tabelas
	where Index_name is not null
			and type_Desc is not null
	group by schema_name, table_Name
	--having sum(reserved_in_kb) > 10000
	order by 3 desc
	

	--Inclui na tabela final a quantidade de linhas da tabela
	update B
	set B.Qtd_Registros_Tabela = A.Qtd_Linhas,
		B.Tamanho_Tabela = A.[Reservado (KB)]
	from #Resultado_Final A
	join Traces..Tabelas_Protheus_Expurgo_Deleted B on A.Name collate Latin1_General_100_BIN = B.Nm_Tabela collate Latin1_General_100_BIN
	
	

	--Query final para ver o resultado do quanto será deletado
	select Nm_Tabela,
			Tamanho_Tabela [Tamanho Tabela (KB)] ,
			Qtd_Registros_Tabela,
			Qtd_Registros_Com_Deleted,
			 cast(Qtd_Registros_Com_Deleted*100.00/Qtd_Registros_Tabela as numeric(9,2)) [% registros com DELETED *],
			'delete from '+Nm_Tabela+' where D_E_L_E_T_ = ''*''' [Comando Exclusao]

	from Traces..Tabelas_Protheus_Expurgo_Deleted B
	where Qtd_Registros_Com_Deleted >0
	and Qtd_Registros_Tabela > 0
	order by 4 desc

	-- Pode utilizar a Coluna Comando Exclusão para excluir os dados. Contudo, caso a deleção seja muito grande vale a pena fazer um loop para excluir.
 
