
-- Missing Indexes for all databases by Index Advantage  (Query 26) (Missing Indexes All Databases)
SELECT	TOP 50 GETDATE() Hora_Coleta,
		CONVERT(decimal(18,2), user_seeks * avg_total_user_cost * (avg_user_impact * 0.01)) AS [Index Advantage], 
		migs.avg_user_impact AS [User Impact],
		CONVERT(decimal(18,2), migs.avg_total_user_cost) AS [AVG Cost], 
		migs.user_seeks AS [Seeks], 
		mid.[statement] AS [Table],
		ISNULL(mid.equality_columns, SPACE(0)) AS [Equality Columns], 
		ISNULL(mid.inequality_columns, SPACE(0)) AS [Inequality Columns], 
		ISNULL(mid.included_columns, SPACE(0)) AS [Included Columns],
		migs.last_user_seek AS [Last Seek],
		'CREATE INDEX [missing_index_' + CONVERT (varchar, mig.index_group_handle) + '_' + CONVERT (varchar, mid.index_handle)
			+ '_' + LEFT (PARSENAME(mid.statement, 1), 32) + ']'
			+ ' ON ' + mid.statement
			+ ' (' + ISNULL (mid.equality_columns,'')
			+ CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END
			+ ISNULL (mid.inequality_columns, '')
			+ ')'
			+ ISNULL (' INCLUDE (' + mid.included_columns + ')', '') AS [Create Index Statement]
	FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK)
			INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) ON migs.group_handle = mig.index_group_handle
			INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK) ON mig.index_handle = mid.index_handle
	ORDER BY [Index Advantage] DESC OPTION (RECOMPILE);

-- Getting missing index information for all of the databases on the instance is very useful
-- Look at last user seek time, number of user seeks to help determine source and importance
-- Also look at avg_user_impact and avg_total_user_cost to help determine importance
-- SQL Server is overly eager to add included columns, so beware
-- Do not just blindly add indexes that show up from this query!!!


-- Indexes not used in seeks, scans and lookups
DECLARE @Client_Abreviation VARCHAR(6) = SUBSTRING(@@SERVERNAME, 5, 6)
DECLARE @SQL VARCHAR(MAX), @Servername VARCHAR(MAX), @DatabaseName VARCHAR(MAX), @database_id BIGINT

DECLARE @databases TABLE (Servername VARCHAR(MAX), DatabaseName VARCHAR(MAX), database_id BIGINT)

DECLARE @indexes_not_used TABLE (Servername VARCHAR(MAX), DatabaseName VARCHAR(MAX), Table_View SYSNAME, IndexName SYSNAME, 
									Seeks BIGINT, Scans BIGINT, Lookups BIGINT, Updates BIGINT, [Index Size (KB)] BIGINT)

SELECT @SQL = 'SELECT ' + '''' + @@SERVERNAME + '''' + ' AS Servername, name AS DatabaseName, database_id ' +
				'FROM sys.databases ' +
				'WHERE name IN (''CampaignControl'',''IvrControl'',''MailingControl'',''SMSControl'',''AgentLoginControl'',''APM'',''AutoStrategy'',''DialerControl'',
									''ImportExportControl'',''LicenseControl'',''PBX'',''RouterControl'',''AlarmControl'',''BackupControl'',''Billing'',''MdmConfig'',
									''MultiLanguageLibrary'',''OlosWebAgent'',''Recorder'',''Reports'',''SysConfiguration'') AND State_Desc = ''ONLINE'' '

INSERT INTO @databases
	EXEC (@SQL)

DECLARE db_cursor CURSOR STATIC FOR
	SELECT Servername, DatabaseName, database_id
		FROM @databases
		ORDER BY Servername, DatabaseName

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @Servername, @DatabaseName, @database_id
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @SQL = 
		'SELECT ' + '''' + @Servername + '''' + ', ' +  '''' + @DatabaseName + '''' + ', O.Name AS Table_View, I.[NAME] AS IndexName, ' +
					'ISNULL(U.USER_SEEKS, 0) AS SEEKS, ' +
					'ISNULL(U.USER_SCANS, 0) AS SCANS, ISNULL(U.USER_LOOKUPS, 0) AS LOOKUPS, ISNULL(U.USER_UPDATES, 0) AS UPDATES, ' +
					'ISNULL((SUM(P.[USED_PAGE_COUNT]) * 8), 0) AS [Index Size (KB)] ' +
			'FROM ' + @DatabaseName + '.SYS.INDEXES I ' +
					'INNER JOIN ' + @DatabaseName + '.sys.objects O ON (I.[OBJECT_ID] = O.[OBJECT_ID]) ' +
					'LEFT OUTER JOIN ' + @DatabaseName + '.SYS.DM_DB_INDEX_USAGE_STATS U ON (I.[OBJECT_ID] = U.[OBJECT_ID]) AND (I.INDEX_ID = U.INDEX_ID) ' +
					'LEFT OUTER JOIN ' + @DatabaseName + '.SYS.DM_DB_PARTITION_STATS P ON (I.[OBJECT_ID] = P.[OBJECT_ID]) AND (I.INDEX_ID = P.INDEX_ID) ' +
			'WHERE (I.Name IS NOT NULL) AND (I.Name NOT LIKE ''PK_%'') AND (I.Type = 2) AND (I.Is_Unique = 0) ' +
					' AND (U.database_id = ' + CONVERT(VARCHAR(10), @database_id) + ') ' +
			'GROUP BY O.Name, I.[NAME], ISNULL(U.USER_SEEKS, 0), ISNULL(U.USER_SCANS, 0), ISNULL(U.USER_LOOKUPS, 0), ISNULL(U.USER_UPDATES, 0) ' +
			'HAVING ISNULL(U.USER_SEEKS, 0) = 0 AND ISNULL(U.USER_SCANS, 0) = 0 AND ISNULL(U.USER_LOOKUPS, 0) = 0 ' +
			'ORDER BY [Index Size (KB)] DESC '
			

	INSERT INTO @indexes_not_used
		EXEC (@SQL)

	FETCH NEXT FROM db_cursor INTO @Servername, @DatabaseName, @database_id
END
CLOSE db_cursor
DEALLOCATE db_cursor

SELECT GETDATE() Hora_Coleta,
		Servername, 
		DatabaseName,
		Table_View, 
		IndexName, 
		Seeks, 
		Scans, 
		Lookups, 
		Updates, 
		ROUND(([Index Size (KB)] / 1024), 2) AS [Index Size (MB)], 
		'DROP INDEX [' + IndexName + '] ON [' + Databasename + '].[dbo].[' + Table_View + '] WITH ( ONLINE = OFF )' AS [Drop Index Statement]
	FROM @indexes_not_used
	ORDER BY ServerName, [Index Size (KB)] DESC




select ix.name, ix.type_desc, vwy.partition_number, vw.user_seeks, vw.last_user_seek, vw.user_scans, vw.last_user_scan, vw.user_lookups, vw.user_updates as 'Total_User_Escrita',(vw.user_scans + vw.user_seeks + vw.user_lookups) as 'Total_User_Leitura',vw.user_updates - (vw.user_scans + vw.user_seeks + vw.user_lookups) as 'Dif_Read_Write',
		ix.allow_row_locks, vwx.row_lock_count, row_lock_wait_count, row_lock_wait_in_ms,ix.allow_page_locks, vwx.page_lock_count, page_lock_wait_count, page_lock_wait_in_ms,ix.fill_factor, ix.is_padded, vwy.avg_fragmentation_in_percent, 
		vwy.avg_page_space_used_in_percent, ps.in_row_used_page_count as Total_Pagina_Usada,ps.in_row_reserved_page_count as Total_Pagina_Reservada,convert(real,ps.in_row_used_page_count) * 8192 / 1024 / 1024 as Total_Indice_Usado_MB,
		convert(real,ps.in_row_reserved_page_count) * 8192 / 1024 / 1024 as Total_Indice_Reservado_MB,page_io_latch_wait_count, page_io_latch_wait_in_ms 
	from sys.dm_db_index_usage_stats vw
		join sys.indexes ix on ix.index_id = vw.index_id and ix.object_id = vw.object_id
		join sys.dm_db_index_operational_stats(db_id('CampaignControl'), OBJECT_ID(N'CallControl'), NULL, NULL) vwx on vwx.index_id = ix.index_id and ix.object_id = vwx.object_id
		join sys.dm_db_index_physical_stats(db_id('CampaignControl'), OBJECT_ID(N'CallControl'), NULL, NULL , 'SAMPLED') vwy on vwy.index_id = ix.index_id and ix.object_id = vwy.object_id and vwy.partition_number = vwx.partition_number
		join sys.dm_db_partition_stats PS on ps.index_id = vw.index_id and ps.object_id = vw.object_id
	where vw.database_id = db_id('CampaignControl') AND object_name(vw.object_id) = 'CallControl' 
	order by user_seeks desc, user_scans desc

