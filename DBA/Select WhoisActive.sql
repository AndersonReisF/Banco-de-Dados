
DECLARE @DataInicial DATETIME, @DateFinal DATETIME

SET @DataInicial = '2021-01-15 06:00:00.753'
SET @DateFinal = '2021-01-15 11:00:00.753'

SELECT start_time, collection_time, [dd hh:mm:ss.mss], session_id, blocking_session_id, blocking_session_count, cpu, used_memory, reads, writes, login_name, database_name, ISNULL('Job - ' + b.[name], a.[program_name]) AS [program_name]
	, host_name, wait_info/*, cast(sql_text as varchar(max))*/, sql_text, sql_command
	FROM OlosDBA.dbo.tbl_WhoisActive a WITH (NOLOCK) 
		LEFT OUTER JOIN [msdb].[dbo].[sysjobs] b WITH(NOLOCK) ON (SUBSTRING(REPLACE(a.[program_name], 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34) = master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(16), job_id)))
	WHERE A.collection_time = (SELECT MAX(collection_time) FROM OlosDBA.dbo.tbl_WhoisActive a WITH (NOLOCK))
	--WHERE a.collection_time between @DataInicial and @DateFinal
	ORDER BY 1


--Processos mais ofensores de escrita e leitura.
SELECT start_time, [dd hh:mm:ss.mss], writes, physical_reads, database_name, ISNULL('Job - ' + b.[name], a.[program_name]) AS [program_name]
	, host_name, wait_info, sql_text, sql_command
	FROM OlosDBA.dbo.tbl_WhoisActive a WITH (NOLOCK) 
	LEFT OUTER JOIN [msdb].[dbo].[sysjobs] b WITH(NOLOCK) ON 
	(
	SUBSTRING(REPLACE(a.[program_name], 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34) = 
	master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(16), job_id))
	)
	WHERE a.collection_time between @DataInicial and @DateFinal
	ORDER BY (writes + physical_reads) DESC

--Processos bloqueando e bloqueados.
SELECT start_time, collection_time, [dd hh:mm:ss.mss], session_id, blocking_session_id, blocking_session_count, cpu, used_memory, reads, writes, login_name, database_name, ISNULL('Job - ' + b.[name], a.[program_name]) AS [program_name]
	, host_name, wait_info/*, cast(sql_text as varchar(max))*/, sql_text, sql_command
	FROM OlosDBA.dbo.tbl_WhoisActive a WITH (NOLOCK) 
		LEFT OUTER JOIN [msdb].[dbo].[sysjobs] b WITH(NOLOCK) ON (SUBSTRING(REPLACE(a.[program_name], 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34) = master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(16), job_id)))
	--WHERE A.collection_time = (SELECT MAX(collection_time) FROM OlosDBA.dbo.tbl_WhoisActive a WITH (NOLOCK))
	WHERE a.collection_time between @DataInicial and @DateFinal and (blocking_session_id is not null or blocking_session_count <>0)
	ORDER BY 1

--Quantidade de bloqueados
SELECT CONVERT(VARCHAR(13),collection_time, 121) Data, ISNULL('Job - ' + b.[name], a.[program_name]) Programa, COUNT(*) Qtd_Bloqueados
	FROM OlosDBA.dbo.tbl_WhoisActive a WITH (NOLOCK) 
		LEFT OUTER JOIN [msdb].[dbo].[sysjobs] b WITH(NOLOCK) ON (SUBSTRING(REPLACE(a.[program_name], 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34) = master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(16), job_id)))
	WHERE a.collection_time between @DataInicial and @DateFinal AND a.blocking_session_id IS NOT NULL
	GROUP BY CONVERT(VARCHAR(13),collection_time, 121), ISNULL('Job - ' + b.[name], a.[program_name])
	ORDER BY 1,3 desc

--Quantidade de bloqueando
SELECT CONVERT(VARCHAR(13),collection_time, 121) Data, ISNULL('Job - ' + b.[name], a.[program_name]) Programa, COUNT(*) Qtd_Bloqueando
	FROM OlosDBA.dbo.tbl_WhoisActive a WITH (NOLOCK) 
		LEFT OUTER JOIN [msdb].[dbo].[sysjobs] b WITH(NOLOCK) ON (SUBSTRING(REPLACE(a.[program_name], 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34) = master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(16), job_id)))
	WHERE a.collection_time between @DataInicial and @DateFinal AND a.blocking_session_count <> 0
	GROUP BY CONVERT(VARCHAR(13),collection_time, 121), ISNULL('Job - ' + b.[name], a.[program_name])
	ORDER BY 1,3 desc

--Quantidade de processos por programa
SELECT DISTINCT ISNULL('Job - ' + b.[name], a.[program_name]) Programa, [Host_name], COUNT(*) Qtd
	FROM OlosDBA.dbo.tbl_WhoisActive a WITH (NOLOCK) 
		LEFT OUTER JOIN [msdb].[dbo].[sysjobs] b WITH(NOLOCK) ON (SUBSTRING(REPLACE(a.[program_name], 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34) = master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(16), job_id)))
	WHERE a.collection_time between @DataInicial and @DateFinal-- and cast((sql_text) AS VARCHAR(MAX)) like '%TRUNC%'
	GROUP BY ISNULL('Job - ' + b.[name], a.[program_name]),[Host_name]
	ORDER BY 1


	

--Select Top 25000 CallIDMaster, RecordStart, DestinationServerName, DestinationDirectory, DestinationFileName, DestinationFileSize, CustomerId, CampaignId  
--from RECORDFILEDETAIL_072020 WITH(NOLOCK) 
--where RecordStart between '2020-07-10 00:00:00.000' and '2020-07-10 23:59:59.999'   and isnull(StoredInStorage, 0) in (0,10) and Stored = 0  
--order by RecordStart asc


--select top 1 * from RECORDFILEDETAIL_082020 (NOLOCK) where stored = 0 and isnull(StoredInStorage, 0) in (1,11,21)

