select dbschemas.[name] as 'schema' , dbtables.[name] as 'tabela',  
          dbindexes.[name] 'indice', convert(decimal(18,2),round(indexstats.avg_fragmentation_in_percent,1)) as 'fragmentacao',
          
          'alter index ' + '['+ dbindexes.[name] +']' + ' on '+ dbschemas.[name] + '.' + '['+dbtables.[name]+'] rebuild'  

 

          from sys.dm_db_index_physical_stats (db_id(), null, null, null, null) as indexstats   
          join sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]  
          join sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]  
          join sys.indexes dbindexes on dbindexes.[object_id] = indexstats.[object_id] and indexstats.index_id = dbindexes.index_id  
          where indexstats.database_id = db_id() and dbindexes.name is not null
          and  convert(decimal(18,2),round(indexstats.avg_fragmentation_in_percent,1)) > 30 
          order by indexstats.avg_fragmentation_in_percent desc;