
SELECT

       D.name

       ,B.backup_finish_date

       ,BF.*

       ,DiasSemBackup = DATEDIFF(DD,B.backup_finish_date,GETDATE())

FROM

       sys.databases D

       CROSS APPLY

       (

             SELECT TOP 1

                    *

             FROM

                    msdb..backupset BS

             WHERE

                    BS.database_name = D.name COLLATE DATABASE_DEFAULT

                    AND

                    BS.type = 'D'

                    AND

                    BS.is_copy_only = 0

             ORDER BY

                    BS.backup_set_id desc

       ) B

       CROSS APPLY

       (

             SELECT

                    Paths               = STRING_AGG(BMF.physical_device_name,',')

                    ,TargetCount = COUNT(*)

             FROM

                    msdb..backupmediafamily BMF

             WHERE

                    BMF.media_set_id = B.media_set_id

       ) BF

ORDER BY    

       B.backup_finish_date