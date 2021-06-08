select @@SERVERNAME AS server_name,
db_name()database_name,
sct2.name as schema_name,
sot2.name as table_name,
SUM(ps2.row_count) as table_rows,
(SUM(ps2.reserved_page_count)*8024)/1024/1024 as table_size_mb,
MAX(CAST(ctt.is_track_columns_updated_on AS TINYINT)) AS ct_enabled,
MAX(ps1.row_count) as ct_rows,
(MAX(ps1.reserved_page_count)*8024)/1024/1024 as ct_size_mb,
MAX(ctt.cleanup_version) AS ct_cleanup_ver, /*cleanup may have removed data up to this version */
MAX(ctt.min_valid_version) AS ct_minimum_ver /*syncing applications should only expect data on or after this version */ 
,'grant view change tracking on ' + sct2.name + '.' +sot2.name +' to user_name;'
FROM sys.internal_tables it
JOIN sys.objects sot1 on it.object_id=sot1.object_id
JOIN sys.schemas AS sct1 ON sot1.schema_id=sct1.schema_id
JOIN sys.dm_db_partition_stats ps1 ON it.object_id = ps1. object_id AND ps1.index_id in (0,1)
LEFT JOIN sys.objects sot2 on it.parent_object_id=sot2.object_id
JOIN sys.change_tracking_tables AS ctt ON ctt.object_id = sot2.object_id
LEFT JOIN sys.schemas AS sct2 ON sot2.schema_id=sct2.schema_id
LEFT JOIN sys.dm_db_partition_stats ps2 ON sot2.object_id = ps2. object_id AND ps2.index_id in (0,1)
WHERE it.internal_type IN (209, 210)
GROUP BY sct2.name, sot2.name
ORDER BY sct2.name, sot2.name;
