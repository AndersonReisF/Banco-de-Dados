
WITH [Latches] AS
    (SELECT GETDATE() Hora_Coleta,
        [latch_class],
        [wait_time_ms] / 1000.0 AS [WaitS],
        [waiting_requests_count] AS [WaitCount],
        100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
        ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_os_latch_stats
    WHERE [latch_class] NOT IN (
        N'BUFFER')
    AND [wait_time_ms] > 0
)
SELECT GETDATE() Hora_Coleta,
    MAX ([W1].[latch_class]) AS [LatchClass],
    CAST (MAX ([W1].[WaitS]) AS DECIMAL(14, 2)) AS [Wait_S],
    MAX ([W1].[WaitCount]) AS [WaitCount],
    CAST (MAX ([W1].[Percentage]) AS DECIMAL(14, 2)) AS [Percentage],
    CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (14, 4)) AS [AvgWait_S]
FROM [Latches] AS [W1]
INNER JOIN [Latches] AS [W2]
    ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM ([W2].[Percentage]) - MAX ([W1].[Percentage]) < 95; -- percentage threshold
GO

WITH [Waits] 
     AS (SELECT GETDATE() Hora_Coleta,
				[wait_type], 
                [wait_time_ms] / 1000.0                             AS [WaitS], 
                ( [wait_time_ms] - [signal_wait_time_ms] ) / 1000.0 AS 
                [ResourceS], 
                [signal_wait_time_ms] / 1000.0                      AS [SignalS] 
                , 
                [waiting_tasks_count] 
                AS [WaitCount], 
                100.0 * [wait_time_ms] / Sum ([wait_time_ms]) 
                                           OVER()                   AS 
                [Percentage], 
                Row_number() 
                  OVER( 
                    ORDER BY [wait_time_ms] DESC)                   AS [RowNum] 
         FROM   sys.dm_os_wait_stats 
         WHERE  [wait_type] NOT IN ( 
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', 
        N'BROKER_TASK_STOP', 
                           N'BROKER_TO_FLUSH', 
                     N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE', 
        N'CHKPT', 
                             N'CLR_AUTO_EVENT', 
                     N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE', 
                     -- Maybe uncomment these four if you have mirroring issues 
                     N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE', 
                     N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD', 
                             N'DIRTY_PAGE_POLL', 
        N'DISPATCHER_QUEUE_SEMAPHORE', 
                     N'EXECSYNC', N'FSAGENT', 
        N'FT_IFTS_SCHEDULER_IDLE_WAIT', 
                             N'FT_IFTSHC_MUTEX', 
                     -- Maybe uncomment these six if you have AG issues 
                     N'HADR_CLUSAPI_CALL', 
        N'HADR_FILESTREAM_IOMGR_IOCOMPLETION' 
                             , 
        N'HADR_LOGCAPTURE_WAIT', 
        N'HADR_NOTIFICATION_DEQUEUE', 
                     N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE', 
        N'KSOURCE_WAKEUP', 
                             N'LAZYWRITER_SLEEP' 
                                                , 
                     N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT', 
                             N'ONDEMAND_TASK_QUEUE', 
        N'PREEMPTIVE_XE_GETTARGETSTATE', 
                     N'PWAIT_ALL_COMPONENTS_INITIALIZED', 
                             N'PWAIT_DIRECTLOGCONSUMER_GETNEXT', 
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP' 
        , 
                                                N'QDS_ASYNC_QUEUE', 
                     N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', 
        N'QDS_SHUTDOWN_QUEUE', 
        N'REDO_THREAD_PENDING_WORK', 
        N'REQUEST_FOR_DEADLOCK_SEARCH', 
                     N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', 
        N'SLEEP_BPOOL_FLUSH', 
                                                N'SLEEP_DBSTARTUP', 
                     N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', 
        N'SLEEP_MASTERMDREADY', 
                                                N'SLEEP_MASTERUPGRADED', 
                     N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', 
        N'SLEEP_TASK', 
                                                N'SLEEP_TEMPDBSTARTUP', 
                     N'SNI_HTTP_ACCEPT', N'SP_SERVER_DIAGNOSTICS_SLEEP', 
        N'SQLTRACE_BUFFER_FLUSH', 
        N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', 
                     N'SQLTRACE_WAIT_ENTRIES', N'WAIT_FOR_RESULTS', 
        N'WAITFOR', 
                                                N'WAITFOR_TASKSHUTDOWN', 
                     N'WAIT_XTP_RECOVERY', N'WAIT_XTP_HOST_WAIT', 
        N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', 
                                                N'WAIT_XTP_CKPT_CLOSE', 
                     N'XE_DISPATCHER_JOIN', N'XE_DISPATCHER_WAIT', 
        N'XE_TIMER_EVENT' ) 
                AND [waiting_tasks_count] > 0) 
SELECT GETDATE() Hora_Coleta,
		Max ([W1].[wait_type]) AS 
       [WaitType], 
       Cast (Max ([W1].[waits]) AS DECIMAL (16, 2)) AS [Wait_S], 
       Cast (Max ([W1].[resources]) AS DECIMAL (16, 2)) AS [Resource_S], 
       Cast (Max ([W1].[signals]) AS DECIMAL (16, 2)) AS [Signal_S], 
       Max ([W1].[waitcount]) AS [WaitCount], 
       Cast (Max ([W1].[percentage]) AS DECIMAL (5, 2)) AS [Percentage], 
       Cast (( Max ([W1].[waits]) / Max ([W1].[waitcount]) ) AS DECIMAL (16, 4)) AS [AvgWait_S], 
       Cast (( Max ([W1].[resources]) / Max ([W1].[waitcount]) ) AS DECIMAL (16, 4)) AS [AvgRes_S], 
       Cast (( Max ([W1].[signals]) / Max ([W1].[waitcount]) ) AS DECIMAL (16, 4))   AS [AvgSig_S], 
       Cast ('https://www.sqlskills.com/help/waits/' + Max ([W1].[wait_type]) AS XML) AS [Help/Info URL] 
FROM   [Waits] AS [W1] 
       INNER JOIN [Waits] AS [W2] ON [W2].[rownum] <= [W1].[rownum] 
GROUP  BY [W1].[rownum] 
HAVING Sum ([W2].[percentage]) - Max([W1].[percentage]) < 95; -- percentage threshold 

