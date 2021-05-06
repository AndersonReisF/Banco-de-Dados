
-- Get VLF (Virtual Log Files) Counts for all databases on the instance (Query 27) (Virtual Log Files Counts)
CREATE TABLE #VLFInfo (RecoveryUnitID int, FileID int, FileSize bigint, StartOffset bigint, FSeqNo bigint, [Status] bigint, Parity bigint, CreateLSN numeric(38));
CREATE TABLE #VLFCountResults(DatabaseName sysname, VLFCount int);
	 
EXEC sp_MSforeachdb N'

	Use [?]; 

	INSERT INTO #VLFInfo 
		EXEC sp_executesql N''DBCC LOGINFO([?])''; 
	 
	INSERT INTO #VLFCountResults 
		SELECT DB_NAME(), COUNT(*) 
			FROM #VLFInfo; 

	TRUNCATE TABLE #VLFInfo;'
	 
SELECT DatabaseName, VLFCount  
	FROM #VLFCountResults
	ORDER BY VLFCount DESC;
	 
DROP TABLE #VLFInfo;
DROP TABLE #VLFCountResults;
-- High VLF counts can affect write performance and they can make full database restores and recovery take much longer
-- Try to keep your VLF counts under 200 in most cases


-- Drive level latency information (Query 22) (Drive Level Latency)
-- Based on code from Jimmy May
SELECT GETDATE() Hora_Coleta, tab.[Drive], tab.volume_mount_point AS [Volume Mount Point], 
		CASE 
			WHEN num_of_reads = 0 THEN 0 
			ELSE (io_stall_read_ms/num_of_reads) 
		END AS [Read Latency],
		CASE 
			WHEN num_of_writes = 0 THEN 0 
			ELSE (io_stall_write_ms/num_of_writes) 
		END AS [Write Latency],
		CASE 
			WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 
			ELSE (io_stall/(num_of_reads + num_of_writes)) 
		END AS [Overall Latency],
		CASE 
			WHEN num_of_reads = 0 THEN 0 
			ELSE (num_of_bytes_read/num_of_reads) 
		END AS [Avg Bytes/Read],
		CASE 
			WHEN num_of_writes = 0 THEN 0 
			ELSE (num_of_bytes_written/num_of_writes) 
		END AS [Avg Bytes/Write],
		CASE 
			WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 
			ELSE ((num_of_bytes_read + num_of_bytes_written)/(num_of_reads + num_of_writes)) 
		END AS [Avg Bytes/Transfer]
	FROM (SELECT LEFT(UPPER(mf.physical_name), 2) AS Drive, SUM(num_of_reads) AS num_of_reads,
				 SUM(io_stall_read_ms) AS io_stall_read_ms, SUM(num_of_writes) AS num_of_writes,
				 SUM(io_stall_write_ms) AS io_stall_write_ms, SUM(num_of_bytes_read) AS num_of_bytes_read,
				 SUM(num_of_bytes_written) AS num_of_bytes_written, SUM(io_stall) AS io_stall, vs.volume_mount_point 
			FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
					INNER JOIN sys.master_files AS mf WITH (NOLOCK) ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
					CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.[file_id]) AS vs 
			GROUP BY LEFT(UPPER(mf.physical_name), 2), vs.volume_mount_point
		) AS tab
	ORDER BY [Overall Latency] DESC OPTION (RECOMPILE);
-- Shows you the drive-level latency for reads and writes, in milliseconds
-- Latency above 20-25ms is usually a problem



-- Calculates average stalls per read, per write, and per total input/output for each database file  (Query 23) (IO Stalls by File)
SELECT GETDATE() Hora_Coleta, DB_NAME(fs.database_id) AS [Database Name], CAST(fs.io_stall_read_ms/(1.0 + fs.num_of_reads) AS NUMERIC(10,1)) AS [avg_read_stall_ms],
		CAST(fs.io_stall_write_ms/(1.0 + fs.num_of_writes) AS NUMERIC(10,1)) AS [avg_write_stall_ms],
		CAST((fs.io_stall_read_ms + fs.io_stall_write_ms)/(1.0 + fs.num_of_reads + fs.num_of_writes) AS NUMERIC(10,1)) AS [avg_io_stall_ms],
		CONVERT(DECIMAL(18,2), mf.size/128.0) AS [File Size (MB)], mf.physical_name, mf.type_desc, fs.io_stall_read_ms, fs.num_of_reads, 
		fs.io_stall_write_ms, fs.num_of_writes, fs.io_stall_read_ms + fs.io_stall_write_ms AS [io_stalls], fs.num_of_reads + fs.num_of_writes AS [total_io]
	FROM sys.dm_io_virtual_file_stats(null,null) AS fs
			INNER JOIN sys.master_files AS mf WITH (NOLOCK) ON fs.database_id = mf.database_id AND fs.[file_id] = mf.[file_id]
ORDER BY avg_io_stall_ms DESC OPTION (RECOMPILE);
-- Helps determine which database files on the entire instance have the most I/O bottlenecks
-- This can help you decide whether certain LUNs are overloaded and whether you might
-- want to move some files to a different location or perhaps improve your I/O performance
-- These latency numbers include all file activity against each SQL Server 
-- database file since SQL Server was last started



-- Get I/O utilization by database (Query 29) (IO Usage By Database)
WITH Aggregate_IO_Statistics AS
	(
		SELECT GETDATE() Hora_Coleta, DB_NAME(database_id) AS [Database Name],
				CAST(SUM(num_of_bytes_read + num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_in_mb
			FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS [DM_IO_STATS]
			GROUP BY database_id
	)

	SELECT GETDATE() Hora_Coleta, ROW_NUMBER() OVER(ORDER BY io_in_mb DESC) AS [I/O Rank], [Database Name], io_in_mb AS [Total I/O (MB)],
			CAST(io_in_mb/ SUM(io_in_mb) OVER() * 100.0 AS DECIMAL(5,2)) AS [I/O Percent]
		FROM Aggregate_IO_Statistics
		ORDER BY [I/O Rank] OPTION (RECOMPILE);
-- Helps determine which database is using the most I/O resources on the instance



-- Look for I/O requests taking longer than 15 seconds in the five most recent SQL Server Error Logs (Query 24) (IO Warnings)
CREATE TABLE #IOWarningResults(LogDate datetime, ProcessInfo sysname, LogText nvarchar(1000));

	INSERT INTO #IOWarningResults 
		EXEC xp_readerrorlog 0, 1, N'taking longer than 15 seconds';

	INSERT INTO #IOWarningResults 
		EXEC xp_readerrorlog 1, 1, N'taking longer than 15 seconds';

	INSERT INTO #IOWarningResults 
		EXEC xp_readerrorlog 2, 1, N'taking longer than 15 seconds';

	INSERT INTO #IOWarningResults 
		EXEC xp_readerrorlog 3, 1, N'taking longer than 15 seconds';

	INSERT INTO #IOWarningResults 
		EXEC xp_readerrorlog 4, 1, N'taking longer than 15 seconds';

SELECT LogDate, ProcessInfo, LogText
	FROM #IOWarningResults
	ORDER BY LogDate DESC;

DROP TABLE #IOWarningResults;
-- Finding 15 second I/O warnings in the SQL Server Error Log is useful evidence of
-- poor I/O performance (which might have many different causes)
-- Look to see if you see any patterns in the results (same files, same drives, same time of day, etc.)

-- Diagnostics in SQL Server help detect stalled and stuck I/O operations
-- https://support.microsoft.com/en-us/kb/897284



-- Volume info for all LUNS that have database files on the current instance (Query 21) (LUNS and Volumes Info)
SELECT DISTINCT GETDATE() Hora_Coleta, vs.volume_mount_point, vs.file_system_type, 
				vs.logical_volume_name, CONVERT(DECIMAL(18,2),vs.total_bytes/1073741824.0) AS [Total Size (GB)],
				CONVERT(DECIMAL(18,2), vs.available_bytes/1073741824.0) AS [Available Size (GB)],  
				CONVERT(DECIMAL(18,2), vs.available_bytes * 1. / vs.total_bytes * 100.) AS [Space Free %]
	FROM sys.master_files AS f WITH (NOLOCK)
			CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.[file_id]) AS vs 
	ORDER BY vs.volume_mount_point OPTION (RECOMPILE);
-- Shows you the total and free space on the LUNs where you have database files
-- Being low on free space can negatively affect performance


USE Reports;
GO

-- Lists the top statements by average input/output usage for the current database  (Query 51) (Top IO Statements)
SELECT TOP(50) GETDATE() Hora_Coleta, OBJECT_NAME(qt.objectid, dbid) AS [SP Name],
		(qs.total_logical_reads + qs.total_logical_writes) /qs.execution_count AS [Avg IO], qs.execution_count AS [Execution Count],
		SUBSTRING(qt.[text],qs.statement_start_offset/2, 
			(CASE 
				WHEN qs.statement_end_offset = -1 
			 THEN LEN(CONVERT(nvarchar(max), qt.[text])) * 2 
				ELSE qs.statement_end_offset 
			 END - qs.statement_start_offset)/2) AS [Query Text]	
	FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
			CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
	WHERE qt.[dbid] = DB_ID()
	ORDER BY [Avg IO] DESC OPTION (RECOMPILE);
-- Helps you find the most expensive statements for I/O by SP

-- I/O Statistics by file for the current database  (Query 43) (IO Stats By File)
SELECT GETDATE() Hora_Coleta, DB_NAME(DB_ID()) AS [Database Name], df.name AS [Logical Name], vfs.[file_id], df.type_desc,
		df.physical_name AS [Physical Name], CAST(vfs.size_on_disk_bytes/1048576.0 AS DECIMAL(10, 2)) AS [Size on Disk (MB)],
		vfs.num_of_reads, vfs.num_of_writes, vfs.io_stall_read_ms, vfs.io_stall_write_ms,
		CAST(100. * vfs.io_stall_read_ms/(vfs.io_stall_read_ms + vfs.io_stall_write_ms) AS DECIMAL(10,1)) AS [IO Stall Reads Pct],
		CAST(100. * vfs.io_stall_write_ms/(vfs.io_stall_write_ms + vfs.io_stall_read_ms) AS DECIMAL(10,1)) AS [IO Stall Writes Pct],
		(vfs.num_of_reads + vfs.num_of_writes) AS [Writes + Reads], 
		CAST(vfs.num_of_bytes_read/1048576.0 AS DECIMAL(10, 2)) AS [MB Read], 
		CAST(vfs.num_of_bytes_written/1048576.0 AS DECIMAL(10, 2)) AS [MB Written],
		CAST(100. * vfs.num_of_reads/(vfs.num_of_reads + vfs.num_of_writes) AS DECIMAL(10,1)) AS [# Reads Pct],
		CAST(100. * vfs.num_of_writes/(vfs.num_of_reads + vfs.num_of_writes) AS DECIMAL(10,1)) AS [# Write Pct],
		CAST(100. * vfs.num_of_bytes_read/(vfs.num_of_bytes_read + vfs.num_of_bytes_written) AS DECIMAL(10,1)) AS [Read Bytes Pct],
		CAST(100. * vfs.num_of_bytes_written/(vfs.num_of_bytes_read + vfs.num_of_bytes_written) AS DECIMAL(10,1)) AS [Written Bytes Pct]
	FROM sys.dm_io_virtual_file_stats(DB_ID(), NULL) AS vfs
			INNER JOIN sys.database_files AS df WITH (NOLOCK) ON vfs.[file_id]= df.[file_id] OPTION (RECOMPILE);
-- This helps you characterize your workload better from an I/O perspective for this database
-- It helps you determine whether you has an OLTP or DW/DSS type of workload


-- Top Cached SPs By Total Logical Reads. Logical reads relate to memory pressure  (Query 48) (SP Logical Reads)
SELECT TOP(25) GETDATE() Hora_Coleta, p.name AS [SP Name], qs.total_logical_reads AS [TotalLogicalReads]
		, qs.total_logical_reads/qs.execution_count AS [AvgLogicalReads],qs.execution_count
		, ISNULL(qs.execution_count/DATEDIFF(Minute, qs.cached_time, GETDATE()), 0) AS [Calls/Minute] 
		, qs.total_elapsed_time, qs.total_elapsed_time/qs.execution_count AS [avg_elapsed_time], qs.cached_time
	FROM sys.procedures AS p WITH (NOLOCK)
			INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK) ON p.[object_id] = qs.[object_id]
	WHERE qs.database_id = DB_ID()
	ORDER BY qs.total_logical_reads DESC OPTION (RECOMPILE);
-- This helps you find the most expensive cached stored procedures from a memory perspective
-- You should look at this if you see signs of memory pressure


-- Top Cached SPs By Total Logical Writes (Query 50) (SP Logical Writes)
-- Logical writes relate to both memory and disk I/O pressure 
SELECT TOP(25) GETDATE() Hora_Coleta, p.name AS [SP Name], qs.total_logical_writes AS [TotalLogicalWrites]
		, qs.total_logical_writes/qs.execution_count AS [AvgLogicalWrites], qs.execution_count
		, ISNULL(qs.execution_count/DATEDIFF(Minute, qs.cached_time, GETDATE()), 0) AS [Calls/Minute]
		, qs.total_elapsed_time, qs.total_elapsed_time/qs.execution_count AS [avg_elapsed_time]
		, qs.cached_time
	FROM sys.procedures AS p WITH (NOLOCK)
			INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK) ON p.[object_id] = qs.[object_id]
	WHERE qs.database_id = DB_ID()
			AND qs.total_logical_writes > 0
	ORDER BY qs.total_logical_writes DESC OPTION (RECOMPILE);
-- This helps you find the most expensive cached stored procedures from a write I/O perspective
-- You should look at this if you see signs of I/O pressure or of memory pressure


-- Top Cached SPs By Total Physical Reads. Physical reads relate to disk read I/O pressure  (Query 49) (SP Physical Reads)
SELECT TOP(25) GETDATE() Hora_Coleta, p.name AS [SP Name],qs.total_physical_reads AS [TotalPhysicalReads]
		, qs.total_physical_reads/qs.execution_count AS [AvgPhysicalReads], qs.execution_count
		, qs.total_logical_reads,qs.total_elapsed_time, qs.total_elapsed_time/qs.execution_count AS [avg_elapsed_time], qs.cached_time 
	FROM sys.procedures AS p WITH (NOLOCK)
			INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK) ON p.[object_id] = qs.[object_id]
	WHERE qs.database_id = DB_ID()
			AND qs.total_physical_reads > 0
	ORDER BY qs.total_physical_reads DESC, qs.total_logical_reads DESC OPTION (RECOMPILE);
-- This helps you find the most expensive cached stored procedures from a read I/O perspective
-- You should look at this if you see signs of I/O pressure or of memory pressure


SELECT start_time, [dd hh:mm:ss.mss], writes, physical_reads, database_name, ISNULL('Job - ' + b.[name], a.[program_name]) AS [program_name]
	, host_name, wait_info, sql_text, sql_command
	FROM OlosDBA.dbo.tbl_WhoisActive a WITH (NOLOCK) 
	LEFT OUTER JOIN [msdb].[dbo].[sysjobs] b WITH(NOLOCK) ON (
																			SUBSTRING(REPLACE(a.[program_name], 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34) = 
																			master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(16), job_id))
																			)
	WHERE a.collection_time between '2019-05-31 08:00:00.753' and '2019-05-31 09:20:00.753'
	ORDER BY (writes + physical_reads) DESC