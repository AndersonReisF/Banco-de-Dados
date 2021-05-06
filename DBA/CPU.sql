
-- Get socket, physical core and logical core count from the SQL Server Error log. (Query 2) (Core Counts)
-- This query might take a few seconds if you have not recycled your error log recently

EXEC sys.xp_readerrorlog 0, 1, N'detected', N'socket';

-- This can help you determine the exact core counts used by SQL Server and whether HT is enabled or not
-- It can also help you confirm your SQL Server licensing model
-- Be on the lookout for this message "using 20 logical processors based on SQL Server licensing" 
-- which means grandfathered Server/CAL licensing
-- This query will return no results if your error log has been recycled since the instance was last started


-- Get processor description from Windows Registry  (Query 18) (Processor Description)
EXEC sys.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'HARDWARE\DESCRIPTION\System\CentralProcessor\0', N'ProcessorNameString';

-- Gives you the model number and rated clock speed of your processor(s)
-- Your processors may be running at less than the rated clock speed due
-- to the Windows Power Plan or hardware power management

-- You can use CPU-Z to get your actual CPU core speed and a lot of other useful information
-- http://www.cpuid.com/softwares/cpu-z.html

-- You can learn more about processor selection for SQL Server by following this link
-- http://www.sqlskills.com/blogs/glenn/processor-selection-for-sql-server/

SELECT COUNT(*),parent_node_id 
	FROM sys.dm_os_schedulers 
	WHERE status='VISIBLE ONLINE'
	GROUP BY parent_node_id  

SELECT 	GETDATE() Hora_Coleta, [status], COUNT(*) AS Quant,  SUM(current_tasks_count) AS current_tasks_count, SUM(runnable_tasks_count) AS runnable_tasks_count, SUM(active_workers_count) AS active_workers_count, AVG(load_factor) AS load_factor
	FROM sys.dm_os_schedulers
GROUP BY [status]

-- Get CPU Utilization History for last 256 minutes (in one minute intervals)  (Query 35) (CPU Utilization History)
-- This version works with SQL Server 2012
DECLARE @ts_now bigint = (SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info WITH (NOLOCK)); 

SELECT TOP(256) SQLProcessUtilization AS [SQL Server Process CPU Utilization], SystemIdle AS [System Idle Process], 100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization], DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event Time] 
	FROM (
			SELECT  record.value('(./Record/@id)[1]', 'int') AS record_id, 
					record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS [SystemIdle], 
					record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS [SQLProcessUtilization], [timestamp] 
			  FROM (
						SELECT [timestamp], CONVERT(xml, record) AS [record] 
							FROM sys.dm_os_ring_buffers WITH (NOLOCK)
							WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
									AND record LIKE N'%<SystemHealth>%'
					) AS x
		) AS y 
	ORDER BY record_id DESC OPTION (RECOMPILE);
-- Look at the trend over the entire period. 
-- Also look at high sustained Other Process CPU Utilization values


-- Get CPU utilization by database (Query 28) (CPU Usage by Database)
WITH DB_CPU_Stats AS
	(
		SELECT GETDATE() Hora_Coleta, pa.DatabaseID, DB_Name(pa.DatabaseID) AS [Database Name], SUM(qs.total_worker_time/1000) AS [CPU_Time_Ms]
			FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
					CROSS APPLY (SELECT CONVERT(int, value) AS [DatabaseID] 
									FROM sys.dm_exec_plan_attributes(qs.plan_handle)
									WHERE attribute = N'dbid') AS pa 
									GROUP BY DatabaseID
	)
	
	SELECT GETDATE() Hora_Coleta,
			ROW_NUMBER() OVER(ORDER BY [CPU_Time_Ms] DESC) AS [CPU Rank],
			[Database Name], [CPU_Time_Ms] AS [CPU Time (ms)], 
			CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CPU Percent]
		FROM DB_CPU_Stats
		WHERE DatabaseID <> 32767 -- ResourceDB
		ORDER BY [CPU Rank] OPTION (RECOMPILE);
-- Helps determine which database is using the most CPU resources on the instance


-- Get top total worker time queries for entire instance (Query 36) (Top Worker Time Queries)
SELECT TOP(50) 	GETDATE() Hora_Coleta,
		DB_NAME(t.[dbid]) AS [Database Name], 
		t.[text] AS [Query Text],  
		qs.total_worker_time AS [Total Worker Time], qs.min_worker_time AS [Min Worker Time],
		qs.total_worker_time/qs.execution_count AS [Avg Worker Time], 
		qs.max_worker_time AS [Max Worker Time], 
		qs.min_elapsed_time AS [Min Elapsed Time], 
		qs.total_elapsed_time/qs.execution_count AS [Avg Elapsed Time], 
		qs.max_elapsed_time AS [Max Elapsed Time],
		qs.min_logical_reads AS [Min Logical Reads],
		qs.total_logical_reads/qs.execution_count AS [Avg Logical Reads],
		qs.max_logical_reads AS [Max Logical Reads], 
		qs.execution_count AS [Execution Count], qs.creation_time AS [Creation Time]
		-- ,t.[text] AS [Query Text], qp.query_plan AS [Query Plan] -- uncomment out these columns if not copying results to Excel
	FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
			CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS t 
			CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp 
	ORDER BY qs.total_worker_time DESC OPTION (RECOMPILE);
-- Helps you find the most expensive queries from a CPU perspective across the entire instance
-- Can also help track down parameter sniffing issues


USE MailingControl;
GO

-- Top Cached SPs By Total Worker time. Worker time relates to CPU cost  (Query 47) (SP Worker Time)
SELECT TOP(25) 	GETDATE() Hora_Coleta, p.name AS [SP Name], qs.total_worker_time AS [TotalWorkerTime], 
		CASE WHEN qs.execution_count > 0 THEN qs.total_worker_time/qs.execution_count ELSE NULL END AS [AvgWorkerTime], qs.execution_count, 
		CASE WHEN DATEDIFF(Minute, qs.cached_time, GETDATE())> 0 THEN ISNULL(qs.execution_count/DATEDIFF(Minute, qs.cached_time, GETDATE()), 0) ELSE NULL END AS [Calls/Minute],
		qs.total_elapsed_time, 
		CASE WHEN qs.execution_count > 0 THEN qs.total_elapsed_time/qs.execution_count ELSE NULL END AS [avg_elapsed_time], qs.cached_time
	FROM sys.procedures AS p WITH (NOLOCK)
			INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK) ON p.[object_id] = qs.[object_id]
	WHERE qs.database_id = DB_ID()
	ORDER BY qs.total_worker_time DESC OPTION (RECOMPILE);
-- This helps you find the most expensive cached stored procedures from a CPU perspective
-- You should look at this if you see signs of CPU pressure

SELECT	GETDATE() Hora_Coleta,
		req.session_id,
		sql_text.TEXT AS Text_command,
		DB_NAME(req.database_id) AS Base_name,
		ses.Host_name,
		ses.program_name AS Program_name,
		req.status,
		req.command,
		req.cpu_time,
		req.reads,
		req.writes,
		/*req.total_elapsed_time,*/
		CONVERT(VARCHAR, DATEDIFF(DAY, req.start_time, GETDATE())) + 'd ' /*Dia*/
        + RIGHT('00' + CONVERT(VARCHAR, DATEDIFF(HOUR, req.start_time, GETDATE()) % 24), 2) + ':' /*Horas*/
        + RIGHT('00' + CONVERT(VARCHAR, DATEDIFF(MINUTE, req.start_time, GETDATE()) % 60), 2) + ':' /*Minutos*/
        + RIGHT('00' + CONVERT(VARCHAR, DATEDIFF(SECOND, req.start_time, GETDATE()) % 60), 2) /*Segundos*/ AS Duration,
		req.start_time,
		req.blocking_session_id,
		req.wait_type,
		req.wait_time,
		req.last_wait_type,
		CAST('<?query --'+CHAR(13)+SUBSTRING(sql_text.text,
			(req.statement_start_offset / 2)+1,     ((CASE req.statement_end_offset
			WHEN -1 THEN DATALENGTH(sql_text.text)    ELSE req.statement_end_offset
			END - req.statement_start_offset)/2) + 1)+CHAR(13)+'--?>' AS xml) AS sql_statement,
		sql_plan.query_plan
	FROM sys.dm_exec_requests AS req
		INNER JOIN sys.dm_exec_sessions AS ses ON (req.session_id = ses.session_id)
		CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sql_text
		OUTER APPLY sys.dm_exec_query_plan(req.plan_handle) AS sql_plan
	WHERE req.session_Id NOT IN (@@SPID)
	ORDER BY req.start_time



-- Find queries that take the most CPU overall
SELECT TOP 50
    ObjectName          = OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid)
    ,TextData           = qt.text
    ,DiskReads          = qs.total_physical_reads   -- The worst reads, disk reads
    ,MemoryReads        = qs.total_logical_reads    --Logical Reads are memory reads
    ,Executions         = qs.execution_count
    ,TotalCPUTime       = qs.total_worker_time
    ,AverageCPUTime     = qs.total_worker_time/qs.execution_count
    ,DiskWaitAndCPUTime = qs.total_elapsed_time
    ,MemoryWrites       = qs.max_logical_writes
    ,DateCached         = qs.creation_time
    ,DatabaseName       = DB_Name(qt.dbid)
    ,LastExecutionTime  = qs.last_execution_time
 FROM sys.dm_exec_query_stats AS qs
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
 ORDER BY qs.total_worker_time DESC
 
-- Find queries that have the highest average CPU usage
SELECT TOP 50
    ObjectName          = OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid)
    ,TextData           = qt.text   
    ,DiskReads          = qs.total_physical_reads   -- The worst reads, disk reads
    ,MemoryReads        = qs.total_logical_reads    --Logical Reads are memory reads
    ,Executions         = qs.execution_count
    ,TotalCPUTime       = qs.total_worker_time
    ,AverageCPUTime     = qs.total_worker_time/qs.execution_count
    ,DiskWaitAndCPUTime = qs.total_elapsed_time
    ,MemoryWrites       = qs.max_logical_writes
    ,DateCached         = qs.creation_time
    ,DatabaseName       = DB_Name(qt.dbid)
    ,LastExecutionTime  = qs.last_execution_time
 FROM sys.dm_exec_query_stats AS qs
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
 ORDER BY qs.total_worker_time/qs.execution_count DESC

 SELECT
    spid
    ,sp.STATUS
    ,loginame   = SUBSTRING(loginame, 1, 12)
    ,hostname   = SUBSTRING(hostname, 1, 12)
    ,blk        = CONVERT(CHAR(3), blocked)
    ,open_tran
    ,dbname     = SUBSTRING(DB_NAME(sp.dbid),1,10)
    ,cmd
    ,waittype
    ,waittime
    ,last_batch
    ,SQLStatement       =
        SUBSTRING
        (
            qt.text,
            er.statement_start_offset/2,
            (CASE WHEN er.statement_end_offset = -1
                THEN LEN(CONVERT(nvarchar(MAX), qt.text)) * 2
                ELSE er.statement_end_offset
                END - er.statement_start_offset)/2
        )
FROM master.dbo.sysprocesses sp
LEFT JOIN sys.dm_exec_requests er
    ON er.session_id = sp.spid
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS qt
WHERE spid IN (SELECT blocked FROM master.dbo.sysprocesses)
AND blocked = 0
