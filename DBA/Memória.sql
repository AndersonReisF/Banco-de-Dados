
SELECT total_physical_memory_kb/1024 AS [Physical Memory (MB)], available_physical_memory_kb/1024 AS [Available Memory (MB)], total_page_file_kb/1024 AS [Total Page File (MB)], available_page_file_kb/1024 AS [Available Page File (MB)], system_cache_kb/1024 AS [System Cache (MB)],system_memory_state_desc AS [System Memory State]	FROM sys.dm_os_sys_memory WITH (NOLOCK) OPTION (RECOMPILE);

SELECT  process_physical_memory_low AS [External Pressure], process_virtual_memory_low AS [VAS Pressure],physical_memory_in_use_kb/1024 AS [SQL Server Memory Usage (MB)],large_page_allocations_kb AS [Large Pages Alloc (Kb)], locked_page_allocations_kb AS [Locked Pages Alloc (Kb)], page_fault_count AS [Pages Fault],memory_utilization_percentage AS [%_Mem_Usage], available_commit_limit_kb AS [Available Commit Limit (Kb)]	FROM sys.dm_os_process_memory WITH (NOLOCK) OPTION (RECOMPILE);
		
SELECT	GETDATE() Hora_Coleta, @@SERVERNAME AS [Server Name],  [object_name] AS [Obj Name],  instance_name AS [Instance Name],  cntr_value AS [Page Life Expectancy]
	FROM sys.dm_os_performance_counters WITH (NOLOCK)
	WHERE [object_name] LIKE N'%Buffer Node%' -- Handles named instances
			AND counter_name = N'Page life expectancy' OPTION (RECOMPILE);

SELECT TOP(10) GETDATE() Hora_Coleta, mc.[type] AS [Memory Clerk Type],  CAST((SUM(mc.pages_kb)/1024.0) AS DECIMAL (15,2)) AS [Memory Usage (MB)] 
	FROM sys.dm_os_memory_clerks AS mc WITH (NOLOCK)
	GROUP BY mc.[type]  
	ORDER BY SUM(mc.pages_kb) DESC OPTION (RECOMPILE);

WITH AggregateBufferPoolUsage AS
	(
		SELECT DB_NAME(database_id) AS [Database Name], CAST(COUNT(*) * 8/1024.0 AS DECIMAL (10,2))  AS [CachedSize]
			FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
			WHERE database_id <> 32767 -- ResourceDB
			GROUP BY DB_NAME(database_id)
	)

	SELECT GETDATE() Hora_Coleta, ROW_NUMBER() OVER(ORDER BY CachedSize DESC) AS [Buffer Pool Rank], [Database Name], CachedSize AS [Cached Size (MB)],
			CAST(CachedSize / SUM(CachedSize) OVER() * 100.0 AS DECIMAL(5,2)) AS [Buffer Pool Percent]
		FROM AggregateBufferPoolUsage
		ORDER BY [Buffer Pool Rank] OPTION (RECOMPILE);

/*Processos Aguardando*/
SELECT session_id, requested_memory_kb / 1024 as RequestedMemMb, granted_memory_kb / 1024 as GrantedMemMb, text
	FROM sys.dm_exec_query_memory_grants qmg
		CROSS APPLY sys.dm_exec_sql_text(sql_handle)

/*Processos em cache*/
SELECT *
	FROM sys.dm_exec_cached_plans 
		CROSS APPLY sys.dm_exec_sql_text(plan_handle)
 

USE Recorder;
GO

-- Breaks down buffers used by current database by object (table, index) in the buffer cache  (Query 55) (Buffer Usage)
-- Note: This query could take some time on a busy instance
SELECT GETDATE() Hora_Coleta, OBJECT_NAME(p.[object_id]) AS [Object Name], p.index_id, CAST(COUNT(*)/128.0 AS DECIMAL(10, 2)) AS [Buffer size(MB)],  COUNT(*) AS [BufferCount], p.Rows AS [Row Count], p.data_compression_desc AS [Compression Type]
	FROM sys.allocation_units AS a WITH (NOLOCK)
			INNER JOIN sys.dm_os_buffer_descriptors AS b WITH (NOLOCK) ON a.allocation_unit_id = b.allocation_unit_id
			INNER JOIN sys.partitions AS p WITH (NOLOCK) ON a.container_id = p.hobt_id
	WHERE b.database_id = CONVERT(int,DB_ID())
			AND p.[object_id] > 100
	GROUP BY p.[object_id], p.index_id, p.data_compression_desc, p.[Rows]
	ORDER BY [BufferCount] DESC OPTION (RECOMPILE);
-- Tells you what tables and indexes are using the most memory in the buffer cache
-- It can help identify possible candidates for data compression

SELECT GETDATE() Hora_Coleta, OBJECT_NAME(p.[object_id]) AS [Object Name], p.index_id, CAST(COUNT(*)/128.0 AS DECIMAL(10, 2)) AS [Buffer size(MB)],  COUNT(*) AS [BufferCount]/*, p.Rows AS [Row Count]*/, p.data_compression_desc AS [Compression Type]
	FROM sys.allocation_units AS a WITH (NOLOCK)
			INNER JOIN sys.dm_os_buffer_descriptors AS b WITH (NOLOCK) ON a.allocation_unit_id = b.allocation_unit_id
			INNER JOIN sys.partitions AS p WITH (NOLOCK) ON a.container_id = p.hobt_id
	WHERE b.database_id = CONVERT(int,DB_ID())
			AND p.[object_id] > 100
	GROUP BY p.[object_id], p.index_id, p.data_compression_desc
	ORDER BY [BufferCount] DESC OPTION (RECOMPILE);


SELECT GETDATE() Hora_Coleta, OBJECT_NAME(p.[object_id]) AS [Object Name], CAST(COUNT(*)/128.0 AS DECIMAL(10, 2)) AS [Buffer size(MB)],  COUNT(*) AS [BufferCount]/*, p.Rows AS [Row Count]*/, p.data_compression_desc AS [Compression Type]
	FROM sys.allocation_units AS a WITH (NOLOCK)
			INNER JOIN sys.dm_os_buffer_descriptors AS b WITH (NOLOCK) ON a.allocation_unit_id = b.allocation_unit_id
			INNER JOIN sys.partitions AS p WITH (NOLOCK) ON a.container_id = p.hobt_id
	WHERE b.database_id = CONVERT(int,DB_ID())
			AND p.[object_id] > 100
	GROUP BY p.[object_id], p.data_compression_desc
	ORDER BY [BufferCount] DESC OPTION (RECOMPILE);




	
---- Good basic information about OS memory amounts and state  (Query 12) (System Memory)
--SELECT total_physical_memory_kb/1024 AS [Physical Memory (MB)], available_physical_memory_kb/1024 AS [Available Memory (MB)], total_page_file_kb/1024 AS [Total Page File (MB)], available_page_file_kb/1024 AS [Available Page File (MB)], system_cache_kb/1024 AS [System Cache (MB)],system_memory_state_desc AS [System Memory State]
--	FROM sys.dm_os_sys_memory WITH (NOLOCK) OPTION (RECOMPILE);
---- You want to see "Available physical memory is high" for System Memory State
---- This indicates that you are not under external memory pressure


---- SQL Server Process Address space info  (Query 6) (SQL Server Process Memory)
---- (shows whether locked pages is enabled, among other things)
--SELECT  process_physical_memory_low AS [External Pressure], process_virtual_memory_low AS [VAS Pressure],physical_memory_in_use_kb/1024 AS [SQL Server Memory Usage (MB)],large_page_allocations_kb AS [Large Pages Alloc (Kb)], locked_page_allocations_kb AS [Locked Pages Alloc (Kb)], page_fault_count AS [Pages Fault],memory_utilization_percentage AS [%_Mem_Usage], available_commit_limit_kb AS [Available Commit Limit (Kb)]
--	FROM sys.dm_os_process_memory WITH (NOLOCK) OPTION (RECOMPILE);

---- You want to see 0 for process_physical_memory_low
---- You want to see 0 for process_virtual_memory_low
---- This indicates that you are not under internal memory pressure


---- Page Life Expectancy (PLE) value for each NUMA node in current instance  (Query 37) (PLE by NUMA Node)
--SELECT	GETDATE() Hora_Coleta, @@SERVERNAME AS [Server Name],  [object_name] AS [Obj Name],  instance_name AS [Instance Name],  cntr_value AS [Page Life Expectancy]
--	FROM sys.dm_os_performance_counters WITH (NOLOCK)
--	WHERE [object_name] LIKE N'%Buffer Node%' -- Handles named instances
--			AND counter_name = N'Page life expectancy' OPTION (RECOMPILE);
---- PLE is a good measurement of memory pressure
---- Higher PLE is better. Watch the trend over time, not the absolute value
---- This will only return one row for non-NUMA systems
---- Page Life Expectancy isn't what you think
---- http://www.sqlskills.com/blogs/paul/page-life-expectancy-isnt-what-you-think/



---- Memory Clerk Usage for instance  (Query 39) (Memory Clerk Usage)
---- Look for high value for CACHESTORE_SQLCP (Ad-hoc query plans)
--SELECT TOP(10) GETDATE() Hora_Coleta, mc.[type] AS [Memory Clerk Type],  CAST((SUM(mc.pages_kb)/1024.0) AS DECIMAL (15,2)) AS [Memory Usage (MB)] 
--	FROM sys.dm_os_memory_clerks AS mc WITH (NOLOCK)
--	GROUP BY mc.[type]  
--	ORDER BY SUM(mc.pages_kb) DESC OPTION (RECOMPILE);

---- MEMORYCLERK_SQLBUFFERPOOL - was new for SQL Server 2012. It should be your highest consumer of memory

---- CACHESTORE_SQLCP  SQL Plans - These are cached SQL statements or batches that aren't in stored procedures, functions and triggers 
--	-- (Watch out for high values for CACHESTORE_SQLCP)

---- CACHESTORE_OBJCP  Object Plans - These are compiled plans for stored procedures, functions and triggers


---- Get total buffer usage by database for current instance  (Query 30) (Total Buffer Usage by Database)
---- This make take some time to run on a busy instance
--WITH AggregateBufferPoolUsage AS
--	(
--		SELECT DB_NAME(database_id) AS [Database Name], CAST(COUNT(*) * 8/1024.0 AS DECIMAL (10,2))  AS [CachedSize]
--			FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
--			WHERE database_id <> 32767 -- ResourceDB
--			GROUP BY DB_NAME(database_id)
--	)

--	SELECT GETDATE() Hora_Coleta, ROW_NUMBER() OVER(ORDER BY CachedSize DESC) AS [Buffer Pool Rank], [Database Name], CachedSize AS [Cached Size (MB)],
--			CAST(CachedSize / SUM(CachedSize) OVER() * 100.0 AS DECIMAL(5,2)) AS [Buffer Pool Percent]
--		FROM AggregateBufferPoolUsage
--		ORDER BY [Buffer Pool Rank] OPTION (RECOMPILE);
---- Tells you how much memory (in the buffer pool) 
---- is being used by each database on the instance

--USE Recorder;
--GO

---- Breaks down buffers used by current database by object (table, index) in the buffer cache  (Query 55) (Buffer Usage)
---- Note: This query could take some time on a busy instance
--SELECT GETDATE() Hora_Coleta, OBJECT_NAME(p.[object_id]) AS [Object Name], p.index_id, CAST(COUNT(*)/128.0 AS DECIMAL(10, 2)) AS [Buffer size(MB)],  COUNT(*) AS [BufferCount], p.Rows AS [Row Count], p.data_compression_desc AS [Compression Type]
--	FROM sys.allocation_units AS a WITH (NOLOCK)
--			INNER JOIN sys.dm_os_buffer_descriptors AS b WITH (NOLOCK) ON a.allocation_unit_id = b.allocation_unit_id
--			INNER JOIN sys.partitions AS p WITH (NOLOCK) ON a.container_id = p.hobt_id
--	WHERE b.database_id = CONVERT(int,DB_ID())
--			AND p.[object_id] > 100
--	GROUP BY p.[object_id], p.index_id, p.data_compression_desc, p.[Rows]
--	ORDER BY [BufferCount] DESC OPTION (RECOMPILE);
---- Tells you what tables and indexes are using the most memory in the buffer cache
---- It can help identify possible candidates for data compression

--SELECT GETDATE() Hora_Coleta, OBJECT_NAME(p.[object_id]) AS [Object Name], p.index_id, CAST(COUNT(*)/128.0 AS DECIMAL(10, 2)) AS [Buffer size(MB)],  COUNT(*) AS [BufferCount]/*, p.Rows AS [Row Count]*/, p.data_compression_desc AS [Compression Type]
--	FROM sys.allocation_units AS a WITH (NOLOCK)
--			INNER JOIN sys.dm_os_buffer_descriptors AS b WITH (NOLOCK) ON a.allocation_unit_id = b.allocation_unit_id
--			INNER JOIN sys.partitions AS p WITH (NOLOCK) ON a.container_id = p.hobt_id
--	WHERE b.database_id = CONVERT(int,DB_ID())
--			AND p.[object_id] > 100
--	GROUP BY p.[object_id], p.index_id, p.data_compression_desc
--	ORDER BY [BufferCount] DESC OPTION (RECOMPILE);


--SELECT GETDATE() Hora_Coleta, OBJECT_NAME(p.[object_id]) AS [Object Name], CAST(COUNT(*)/128.0 AS DECIMAL(10, 2)) AS [Buffer size(MB)],  COUNT(*) AS [BufferCount]/*, p.Rows AS [Row Count]*/, p.data_compression_desc AS [Compression Type]
--	FROM sys.allocation_units AS a WITH (NOLOCK)
--			INNER JOIN sys.dm_os_buffer_descriptors AS b WITH (NOLOCK) ON a.allocation_unit_id = b.allocation_unit_id
--			INNER JOIN sys.partitions AS p WITH (NOLOCK) ON a.container_id = p.hobt_id
--	WHERE b.database_id = CONVERT(int,DB_ID())
--			AND p.[object_id] > 100
--	GROUP BY p.[object_id], p.data_compression_desc
--	ORDER BY [BufferCount] DESC OPTION (RECOMPILE);

