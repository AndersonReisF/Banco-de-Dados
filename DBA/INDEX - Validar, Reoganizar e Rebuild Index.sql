--Do que se trata este artigo:
--Nesse artigo vamos demonstrar como avaliar a utiliza��o e performance de �ndices no SQL Server 2005 e 2008 utilizando as DMVs (Dynamic Management Views) e DMFs (Dynamic Management Functions). Dentre os t�picos abordados em nossa an�lise sobre �ndices, teremos: fragmenta��o, espa�o utilizado, Missing Index e consultas que nos permitir�o elencar e entender detalhadamente se os �ndices est�o sendo utilizados de forma eficaz ou se est�o apenas ocupando espa�o no banco de dados.
 
--Para que serve:
--Este artigo visa auxiliar administradores de banco de dados e desenvolvedores a identificarem como de fato os �ndices est�o sendo utilizados pelo banco de dados, e com base na an�lise realizada avaliar se determinado �ndice deve ser exclu�do, alterado, reorganizado, reindexado ou se existe a necessidade de novos �ndices para contemplar consultas realizadas pela aplica��o.

--Em que situa��o o tema � �til:
--Este tema � �til para profissionais que desejam ter uma vis�o ampla dos recursos dispon�veis no SQL Server 2005 e 2008 que podem ser utilizados para realizar uma an�lise t�cnica detalhada sobre a utiliza��o de �ndices no banco de dados.

--Avaliando �ndices
--A partir da vers�o 2005 do SQL Server, contamos com novos recursos como DMVs (Dynamic Management Views) e DMFs (Dynamic Management Functions), que, atrav�s de metadados, coletados pelo servi�o do SQL Server, nos d�o uma vis�o diferenciada sobre como nosso banco e inst�ncia est�o se comportando.
--Neste artigo, utilizaremos as informa��es disponibilizadas por estes recursos para realizar uma an�lise detalhada de como nossos �ndices est�o sendo utilizados, e com base nestas informa��es, identificarmos, por exemplo, quais s�o os �ndices mais utilizados, que tipo de manuten��o seria mais apropriada para eles, assim como encontrar �ndices que n�o est�o sendo utilizados de forma adequada pelas consultas.
--�ndices s�o utilizados para aumentar o desempenho em opera��es de leitura no banco de dados. Um �ndice utilizado corretamente pode melhorar exponencialmente a velocidade com que as consultas s�o retornadas pelo SGBD e diminuir significativamente a quantidade de I/O em disco.
--Essa redu��o de I/O ocorre porque os dados ao serem indexados passam a utilizar a estrutura criada pelo �ndice, se limitando a uma busca apenas nas p�ginas de dados do �ndice.
--Sem um �ndice, o SQL Server � obrigado a realizar uma leitura completa em todas as p�ginas de dados referente � tabela em que o dado solicitado est� armazenado.

--Apesar do �ndice, se bem definido, aumentar o desempenho em opera��es de leitura e reduzir I/O, ele tamb�m gera um custo consider�vel em opera��es de escrita. Esse comportamento ocorre porque o �ndice deve se manter atualizado.
--Para manter o �ndice atualizado o SQL Server replica, de forma s�ncrona, todas as altera��es (Insert, Update e Delete) realizadas na tabela para o �ndice. Logo, se uma tabela cont�m quatro �ndices, uma �nica opera��o de inser��o de dados (insert) ir� gerar cinco inser��es, sendo uma para a tabela e mais uma para cada �ndice existente.
--O mesmo procedimento ocorre em opera��es que apagam informa��es (delete). Em opera��es que atualizam dados (update) apenas �ndices que cont�m as colunas atualizadas ser�o afetados.
--Devido a este processo de atualiza��o dos �ndices, o tamanho utilizado pelo �ndice em disco estar� sempre em constante crescimento. Dessa forma, quanto maior a quantidade de �ndices, mais espa�o em disco precisamos reservar para seu crescimento.
--Uma forma de acompanharmos detalhadamente todos os processos envolvendo �ndices, desde seu crescimento at� a forma com que � utilizado, � utilizando as DMVs e DMFs.

--Vis�es e Fun��es Din�micas para �ndices

--As DMVs e DMFs s�o vis�es e fun��es carregadas pelo pr�prio servi�o do SQL Server com diversos dados sobre opera��es realizadas no servidor de banco de dados.
--Elas permitem ao administrador do banco uma melhor e mais ampla interpreta��o das informa��es sobre armazenamento, manipula��o e utiliza��o de seus recursos.
--Dentre as DMVs e DMFs dispon�veis a partir do SQL Server 2005, existe uma categoria dedicada apenas a an�lise de informa��es sobre �ndices. Essa categoria � chamada de Index Related Dynamic Management Views and Functions, onde contamos com as seguintes vis�es e fun��es:

--sys.dm_db_index_operational_stats: Esta DMF retorna informa��es referentes a atualiza��es realizadas, como inser��o, atualiza��o ou dele��o, para cada parti��o de uma tabela ou �ndice;
--sys.dm_db_index_usage_stats: Vis�o que exibe diferentes tipos de contadores de opera��es realizadas nos �ndices, como quantidade de acessos realizados pelo usu�rio, tipos de acesso como seek ou scan e a �ltima vez em que o �ndice foi utilizado por uma consulta;
--sys.dm_db_index_physical_stats: Fun��o que lista informa��es sobre espa�o utilizado e fragmenta��o de �ndices.
--Na categoria Index Related Dynamic Management Views and Functions ainda temos mais quatro op��es, divididas entre fun��es e vis�es, que podemos utilizar em conjunto com as DMVs e DMFs citadas acima, para obter informa��es sobre �ndices que o SQL Server sugere a cria��o para aumento de performance em consultas realizadas na base de dados. Estes �ndices s�o conhecidos como missing index.

--O SQL Server sugere um novo �ndice sempre que uma consulta n�o encontrar um �ndice que a contemple e o mesmo interpretar que um �ndice, com as caracter�sticas necess�rias para contemplar esta consulta, aumentaria sua performance.

--Sempre que o SQL Server interpretar que um novo �ndice beneficiaria a performance das consultas realizadas, ele automaticamente ir� inserir um registro contendo as informa��es necess�rias para a cria��o deste novo �ndice nas seguintes DMVs e DMFs:

--sys.dm_db_missing_index_details: Esta DMV sugere �ndices que poderiam ser criados para melhorar a performance em consultas realizadas em determinadas tabelas;
--sys.dm_db_missing_index_columns: Ao informar o ID do missing �ndex, esta fun��o retorna um registro para cada coluna sugerida ao �ndice e a forma que as colunas devem ser referenciadas pelos operadores na cl�usula Where, inclusive colunas que poderiam ser utilizadas para se criar um Covered Index. (ver Nota 2). Estas informa��es tamb�m podem ser visualizadas de forma agrupada na vis�o sys.dm_db_missing_index_details;
--sys.dm_db_missing_index_group_stats: Esta vis�o cont�m informa��es como: �ltima data em que uma consulta requisitou um �ndice com as caracter�sticas do �ndice que est� sendo sugerido, o tipo de acesso realizado no �ndice (Index Scan ou Index  Seek) (ver Nota Adicional 3) e um indicador contendo o impacto que a cria��o deste �ndice significaria para as consultas realizadas na tabela afetada;
--sys.dm_db_missing_index_groups: Atrav�s desta DMV relacionamos o ID do �ndice com um ID de grupo. O ID do grupo � utilizado pela vis�o sys.dm_db_missing_index_group_stats.

--Os valores encontrados nas vis�es e fun��es s�o zerados todas as vezes que o servi�o do SQL Server � reiniciado. A partir de agora, veremos como as DMVs e DMFs podem ser utilizadas para realizar uma an�lise completa sobre os �ndices criados e os �ndices sugeridos (missing index).

--Nota Adicional 2: Covered Index s�o �ndices que contemplam por completo uma consulta realizada no banco de dados. Normalmente em sua cria��o � utilizada cl�usula INCLUDE, contendo as colunas referenciadas no SELECT. Para um �ndice ser considerado Covered, todas as colunas referenciadas pelo SELECT, WHERE e JOIN devem fazer parte do �ndice. Dessa forma, o resultado da consulta pode ser retornado sem a necessidade de acessar os dados da tabela. Covered Index s�o recomendados apenas para consultas que s�o muito executadas. Para mais informa��es sobre �ndices que cobrem toda a consulta, acesse: http://msdn.microsoft.com/en-us/library/ms189607.aspx.

--Nota Adicional 3: Index Scan, acontece sempre que uma consulta acessa um �ndice, por�m n�o se utiliza de sua estrutura hier�rquica (b-tree) para consultar e retornar os dados de forma eficiente, fazendo com que o otimizador de consulta (query optimizer) percorra todo o �ndice, atr�s dos registros consultados. Este m�todo na grande maioria das vezes consome mais recursos do servidor que o m�todo Index Seek, que percorre o �ndice atrav�s de n�veis utilizando a estrutura b-tree, diminuindo assim a quantidade de dados a ser analisado para que seja poss�vel encontrar a informa��o solicitada. Para mais informa��es, acesse: http://msdn.microsoft.com/en-us/library/ms177443.aspx.

--Principalmente em bases de dados do tipo OLTP (ver Nota Adicional 4), � muito importante ponderar na cria��o dos �ndices e tentar achar sempre um meio termo, onde atenda tanto as necessidades de leitura como de escrita. Este meio termo nem sempre � f�cil de identificar.

--Nota Adicional 4: Online Transaction Processing (OLTP), � um tipo de banco de dados onde transa��es s�o realizadas em tempo real. S�o caracter�sticas de uma base de dados OLTP: grande quantidade de usu�rios; alta concorr�ncia, base de dados normalizada utilizando as formas normais; opera��es de insert e update predominam sobre opera��es de select; normalmente s�o utilizadas para controlar a parte operacional de uma empresa, como um ERP.

--Uma das formas para come�ar a encontrar este equil�brio � verificar se os �ndices criados est�o sendo utilizados de forma eficiente. As DMVs e DMFs al�m de auxiliar neste tipo de an�lise, podem ser utilizadas para verificar a necessidade de:

--  Criar novos �ndices;
--  Excluir �ndices desnecess�rios;
--  Alterar �ndices existentes;
--  Realizar manuten��es nos �ndices.
--Neste artigo apresentaremos uma s�rie consultas empregando as vis�es e fun��es din�micas dispon�veis no SQL Server 2005 e 2008, que podem ser utilizadas por administradores de banco de dados (DBA) e desenvolvedores para compreender melhor como os �ndices de seu banco de dados est�o sendo utilizados.

--Ser� parte do escopo das consultas t�picos como: espa�o em disco utilizado pelos �ndices; avaliar se um �ndice est� sendo bem utilizado; m�todos de acesso utilizados pelas consultas que utilizam os �ndices; tabelas candidatas a receberem novos �ndices; �ndices criados, por�m n�o utilizados; identificar quando devemos realizar uma desfragmenta��o ou reindexa��o de um �ndice e, por fim, veremos as consultas que mais consomem recursos de processamento do servidor.

--Tabelas candidatas a receber novos �ndices

--Como dito anteriormente, existem mecanismos que nos d�o uma vis�o dos �ndices que poderiam ser criados para aumentar a performance em consultas realizadas em determinadas tabelas.

--Com o intuito de identificar �ndices que poderiam ser criados para atender esta finalidade, veremos a seguir, uma sequ�ncia de consultas que ir�o se utilizar al�m das DMVs e DMFs j� citadas neste artigo, algumas vis�es de sistema do SQL Server.

--Iniciaremos nossa analise verificando quais tabelas do banco de dados n�o possui �ndices clusterizados. A consulta dispon�vel na Listagem 1 ir� informar todas as tabelas onde n�o existe um �ndice clusterizado.

-- Listagem 1. Tabelas que n�o cont�m �ndices clusteriazados.

select distinct(tb.name) as Table_name, p.rows from sys.objects tb join sys.partitions p on p.object_id = tb.object_id Where type = 'U' and tb.object_id not in ( select ix.object_id from sys.indexes ix where type = 1 ) order by p.rows desc

--�ndices clusterizados determinam a forma com que a tabela � ordenada fisicamente e s�o extremamente importantes para as consultas realizadas em uma tabela. Com a cria��o do �ndice clusterizado , a tabela deixa de utilizar uma estrutura chamada Heap (ver Nota Adicional 5) e se torna uma Clustered Table.

--Nota Adicional 5: Heap � uma tabela que n�o cont�m um �ndice clusterizado. Seus dados s�o gravados fisicamente sem uma ordena��o estabelecida. Dessa forma, sempre que for necess�rio encontrar um dado na tabela, � realizado um scan completo em suas p�ginas de dados.

--Normalmente, �ndices clusterizados est�o associados a chaves prim�rias. Por padr�o, quando voc� cria uma chave prim�ria, a n�o ser que seja definido pelo usu�rio outro tipo de �ndice ou j� exista um �ndice deste tipo na tabela, � criado um �ndice clusterizado utilizando as colunas da chave criada. A Listagem 2 mostra como identificar todas as tabelas que n�o possuem chave prim�ria definida.

-- Listagem 2. Tabelas que n�o possuem chave prim�ria.

select distinct(tb.name) as Table_name, p.rows from sys.objects tb join sys.partitions p on p.object_id = tb.object_id Where type = 'U' and tb.object_id not in ( select ix.parent_object_id from sys.key_constraints ix where type = 'PK' ) order by p.rows desc

--Chave prim�ria (Primary Key � PK) e �ndice clusterizado s�o conceitos b�sicos que devem ser aplicados a todas as tabelas de um banco de dados, principalmente para os bancos com o perfil OLTP (ver Nota Adicional 4).

--Sem uma PK n�o temos um ponto de referencia, utilizado para identificar e relacionar registros entre tabelas, j� sem um �ndice clusterizado a tabela � gravada de forma desordenada, afetando diretamente a performance em opera��es de leitura. Assim, poder�amos criar �ndices clusterizados e chaves primarias nas tabelas indicadas na Listagens 1 e 2, respectivamente.

--� importante salientar que n�o basta apenas criar �ndices clusterizados e chaves primarias nas tabelas. Os mesmos devem ser definidos estrategicamente, levando em considera��o as boas pr�ticas para tal atividade. Caso contr�rio, poder�amos gerar outros problemas, como fragmenta��o, uso excessivo de espa�o em disco e desnormaliza��o.

--Os conceitos e boas pr�ticas para cria��o destes objetos � um assunto amplo e n�o ser� abordado neste artigo. Para quem desejar mais informa��es sobre, acesse o link: http://msdn.microsoft.com/pt-br/library/ms186342.aspx.

--Outra forma de identificar tabelas candidatas a receber novos �ndices � analisar os �ndices sugeridos pelo SQL Server.

--A Listagem 3, traz um lista das tabelas mais impactadas pela falta de �ndices que contemplassem as consultas realizadas contra a tabela, ordenadas pelo impacto positivo gerado na performance das consultas, caso fosse criado os �ndices sugeridos pelo SQL Server.

--Quanto maior o impacto, maior a chance das consultas realizadas na tabela se beneficiarem com a cria��o dos �ndices.

--Listagem 3. Tabelas que mais seriam beneficiadas com novos �ndices.

SELECT TOP 30 AVG((avg_total_user_cost * avg_user_impact * (user_seeks + user_scans))) as Impacto,mid.object_id, mid.statement as Tabela
FROM sys.dm_db_missing_index_group_stats AS migs
JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle 
JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle and database_id = db_id() 
GROUP BY mid.object_id, mid.statement 
ORDER BY Impacto DESC;

--A lista das tabelas que mais se beneficiariam com a cria��o de novos �ndices j� nos d� uma informa��o valiosa, indicando que est�o sendo realizadas consultas n�o contempladas pelos �ndices existentes nestas tabelas. A partir deste momento, poder�amos dar uma aten��o especial � forma com que elas est�o sendo acessadas pelas aplica��es.

--Para completar a informa��o obtida com a execu��o da consulta na Listagem 3, veremos agora, como trazer a lista dos �ndices sugeridos pelo SQL Server que mais impactariam nas tabelas obtidas anteriormente.

--Para obter a lista dos �ndices, execute, em seu banco de dados a consulta demonstrada na Listagem 4.

--Listagem 4. Top 30 �ndices, sugeridos pelo SGBD.

SELECT TOP 30 (avg_total_user_cost * avg_user_impact * (user_seeks + user_scans)) as Impacto, migs.group_handle, mid.index_handle, migs.user_seeks,migs.user_scans, mid.object_id, mid.statement, mid.equality_columns, mid.inequality_columns, mid.included_columns 
FROM sys.dm_db_missing_index_group_stats AS migs
JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle 
JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle and database_id = db_id() 
--AND mid.object_id = object_id('conceitos') -- se desejar ver apenas para uma tabela espec�fica
ORDER BY Impacto DESC;
--ORDER BY user_seeks DESC;


--Abaixo segue uma breve descri��o das colunas listadas pela consulta apresentada na Listagem 4.

--Impacto: Quanto maior o impacto, mais benef�cios ser�o obtidos com a cria��o do �ndice;
--Group_handle: Identificador �nico do �ndice sugerido.
--User_seeks: Quantidade de vezes, utilizando o m�todo de busca 'Index Seek', que uma consulta realizada pelo usu�rio seria contemplada por este �ndice, caso existisse;
--User_scan: Quantidade de vezes, utilizando o m�todo de busca 'Index Scan', que uma consulta realizada pelo usu�rio seria contemplada por este �ndice, caso existisse.;
--Object_id: Identificador �nico da tabela no banco de dados
--Statement: Tabela onde o �ndice deveria ser criado;
--Equality_columns: Colunas que fazem parte do Where de uma consulta utilizando o operador igual (=). Ex: select * from tab where val = 1. Neste caso a coluna chamada 'val', aparecer� como resultado desta coluna.
--Inequality_columns: Colunas que fazem parte da clausula Where de uma consulta e se utilizam de operadores diferentres de igual (=) como os operadores (> < <> between); Ex: select * from tab where val <> 1.
--Included_columns: Colunas que poderiam ser adicionadas para criar um Covered Index (ver Nota Adicional 2).
--As colunas equality_columns e inequality_columns indicam as colunas chaves do indice e a coluna included_columns indica as colunas n�o-chaves. As colunas n�o chaves s�o incluidas atrav�s da clausula 'include' na senten�a de cria��o do indice

--Uma observa��o importante � que nem todos os �ndices sugeridos pelo SGBD devem ser criados sem uma pr�via an�lise. Podem ocorrer casos em que j� existam �ndices parecidos com o �ndice que foi sugerido. Neste caso, talvez apenas uma altera��o no �ndice existente j� atenda a necessidade das consultas que atualmente n�o est�o sendo contempladas por este �ndice.
--A decis�o final, que confirma se o �ndice deve ser criado ou n�o, sempre deve ficar com o DBA.

-- �ndices candidatos a serem exclu�dos

--Quando criamos um �ndice, � de extrema import�ncia, realizar periodicamente consultas nos metadados do SQL Server, para verificar seu estado e desta forma definir se existe a necessidade ou n�o de realizar manuten��es.

--Sem este acompanhamento pode ocorrer de surgirem �ndices inuteis, que apenas geram trabalho ao SGBD. Isso pode acontecer devido a uma falta de manuten��o ou at� uma m� defini��o na cria��o do �ndices.

--Estes �ndices que est�o criados e n�o s�o utilizados, poderiam ser exluidos, melhorando assim performance de opera��es que realizam insert, delete ou update e ainda diminuindo o esfor�o realizado para manter estes �ndices atualizados.

--Sempre que ocorrer uma opera��o de Insert ou Delete em uma tabela, a mesma dever� ser replicada para todos os �ndices criados na mesma, independente de serem utilizados ou n�o pelas consultas realizadas pelos usu�rios. Em opera��es de Update, apenas os �ndices contendo as colunas atualizadas ser�o afetados.

--Deste modo, manter �ndices n�o utilizados pode custar caro, pois al�m de desperdi�ar espa�o em disco, gera um trabalho extra de administra��o ao SGBD.

--Ap�s identificar os �ndices que n�o est�o sendo utilizados, antes de apag�-los, � recomend�vel realizar um backup de sua estrutura. Assim, caso algum dia seja necess�rio recri�-lo, basta utilizar o backup de estrutura criado para este �ndice.

--Para verificar todos os �ndices que nunca foram utilizados pelo banco de dados, execute a consulta da Listagem 5.

-- Listagem 5. �ndices nunca ou pouco utilizados pelo SGBD.

select tb.name as Table_Name, ix.name as Index_Name, ix.type_desc, leaf_insert_count,leaf_delete_count, leaf_update_count, nonleaf_insert_count ,nonleaf_delete_count, nonleaf_update_count, vw.user_seeks, vw.user_scans, vw.user_lookups, vw.system_seeks, vw.system_scans, vw.system_lookups 
from sys.dm_db_index_usage_stats vw join sys.objects tb on tb.object_id = vw.object_id join sys.indexes ix on ix.index_id = vw.index_id and ix.object_id = tb.object_id
join sys.dm_db_index_operational_stats(db_id('CampaignControl'), Null, NULL, NULL) vwx on vwx.object_id = tb.object_id and vwx.index_id = ix.index_id where vw.database_id = db_id('CampaignControl')
and vw.user_seeks <= 50 and vw.user_scans <= 50 and vw.user_lookups <= 50 and vw.system_seeks <= 50 and vw.system_scans <= 50 and vw.system_lookups <= 50 and ix.name like 'IX_%'
order By leaf_insert_count desc, tb.name asc, ix.name asc


--As colunas leaf_insert_count,leaf_delete_count,leaf_update_count, indicam a quantidade de atualiza��es ocorridas no n�vel folha do �ndice por opera��es de Insert, Delete e Update, respectivamente.

--As mesmas colunas precedidas do prefixo 'non', representam as opera��es de Insert, Delete e Update, por�m no n�vel root e intermedi�rio (ver Nota Adicional 6) de um �ndice.

--A coluna Type_Desc descreve o tipo do �ndice listado, podendo ser HEAP, CLUSTERED, NONCLUSTERED, XML ou SPATIAL (sendo este �ltimo, apenas dispon�vel no SQL Server 2008).

--Nota Adicional 6: No SQL Server, �ndices s�o organizados em B-trees. Cada p�gina em uma B-tree � conhecida como um n� (index node). O n� mais alto � chamado de root (root node). O n�vel mais baixo � chamado leaf (leaf nodes). Outros n�veis (n�s) de um �ndice ficam entre os n�s root e leaf, estes s�o conhecidos como intermediate levels (n�veis intermedi�rios). No �ndice clusterizado, o n�vel mais baixo (leaf node ou n�vel folha), cont�m todos os dados da tabela. Para o �ndice n�o clusterizado o n�vel mais baixo cont�m os valores das chaves que foram definidas na cria��o do �ndice, mais o apontamento para o �ndice clusterizado. Nos n�veis root e intermediate ficam os apontamentos (ponteiros), contendo as palavras chaves definidas para o �ndice que apontam para n�vel mais baixo, onde de fato est� a informa��o.

--Avaliando a utiliza��o dos �ndices

--At� o momento vimos como identificar �ndices que, se criados, poderiam beneficiar o desempenho em consultas a determinadas tabelas, e �ndices que que n�o s�o utilizados pelo SGBD e portanto poderiam ser excluidos.

--� importante salientar que at� o momento adotamos como par�metro para decidir quando excluir um �ndice apenas o fato dele j� ter sido utilizado ou n�o em uma consulta. No entanto, al�m destes, existem outros fatores que podemos considerar para tomar uma decis�o como esta.

--A seguir, atrav�s da consulta dispon�vel na Listagem 6, iremos muito al�m de avaliar dados que influenciam na decis�o de manter ou n�o um �ndice. Veremos informa��es referentes � fragmenta��o dos �ndices, o que determina se um �ndice deve ser desfragmentado ou reindexado. A m�dia de opera��es de insert, update e delete realizadas contra o �ndice, comparadas com a quantidade de vezes que o �ndice foi utilizado por uma consulta, determinando desta forma a qualidade deste �ndice. Veremos tamb�m algumas propriedades que, de acordo com sua defini��o, podem afetar diretamente a forma com que o �ndice � armazenado em disco, al�m de outros dados que s�o de extrema import�ncia para uma avalia��o mais precisa sobre a utiliza��o dos �ndices.

-- Listagem 6. Avaliando �ndices.
select ix.name, ix.type_desc, vwy.partition_number, vw.user_seeks, vw.last_user_seek, vw.user_scans, vw.last_user_scan, vw.user_lookups, vw.user_updates as 'Total_User_Escrita',(vw.user_scans + vw.user_seeks + vw.user_lookups) as 'Total_User_Leitura',vw.user_updates - (vw.user_scans + vw.user_seeks + vw.user_lookups) as 'Dif_Read_Write',
ix.allow_row_locks, vwx.row_lock_count, row_lock_wait_count, row_lock_wait_in_ms,ix.allow_page_locks, vwx.page_lock_count, page_lock_wait_count, page_lock_wait_in_ms,ix.fill_factor, ix.is_padded, vwy.avg_fragmentation_in_percent, 
vwy.avg_page_space_used_in_percent, ps.in_row_used_page_count as Total_Pagina_Usada,ps.in_row_reserved_page_count as Total_Pagina_Reservada,convert(real,ps.in_row_used_page_count) * 8192 / 1024 / 1024 as Total_Indice_Usado_MB,
convert(real,ps.in_row_reserved_page_count) * 8192 / 1024 / 1024 as Total_Indice_Reservado_MB,page_io_latch_wait_count, page_io_latch_wait_in_ms 
from sys.dm_db_index_usage_stats vw
join sys.indexes ix on ix.index_id = vw.index_id and ix.object_id = vw.object_id
join sys.dm_db_index_operational_stats(db_id('CampaignControl'), OBJECT_ID(N'CallControl'), NULL, NULL) vwx on vwx.index_id = ix.index_id and ix.object_id = vwx.object_id
join sys.dm_db_index_physical_stats(db_id('CampaignControl'), OBJECT_ID(N'CallControl'), NULL, NULL , 'SAMPLED') vwy 
on vwy.index_id = ix.index_id and ix.object_id = vwy.object_id and vwy.partition_number = vwx.partition_number
join sys.dm_db_partition_stats PS on ps.index_id = vw.index_id and ps.object_id = vw.object_id
where vw.database_id = db_id('CampaignControl') AND object_name(vw.object_id) = 'CallControl' 
order by user_seeks desc, user_scans desc

--Abaixo veremos uma breve descri��o de como devemos avaliar as colunas utilizadas pela consulta descrita na Listagem 6.

--Podemos utilizar as colunas user_seeks, user_scans e user_lookups para identificarmos os indices mais e menos utilizados. Caso estas tr�s colunas retornem o valor 0, indica que se trata de um �ndice que nunca foi utilizado pelo usu�rio.

--O ideal � que o valor de user_seeks sempre esteja superior aos das colunas user_scans e user_lookups, indicando, desta forma, que o SQL Server est� navegando no �ndice e n�o varrendo-o por completo (user_scans) ou se utilizando de outros �ndices, como o �ndice clusterizado para resgatar as demais colunas solicitadas na busca, por�m n�o contempladas pelo �ndice (user_lookups).

--A coluna Total_User_Escrita representa o quanto o �ndice est� sendo atualizado por opera��es de inser��o, atualiza��o e dele��o de dados realizadas na tabela (Insert, Update e Delete), e a coluna Total_User_Leitura (Select) indica o quanto o �ndice est� sendo utilizado para opera��es de leitura.

--�ndices onde a quantidade de atualiza��es (Total_User_Escrita) � consideravelmente maior que a quantidade de consultas (Total_User_Leitura), indica a necessidade de uma avalia��o mais detalhada do DBA. Neste caso, pode ser que o custo empregado para mant�-los atualizado seja muito maior que o benef�cio adquirido com sua existencia, j� que o principal objetivo de um �ndice � otimizar a performance em consultas.

--Sempre que uma informa��o � alterada, inclu�da ou apagada de uma tabela, a mesma coisa acontece nos �ndices criados para esta tabela. Logo, quanto mais �ndices existir em uma tabela, mais demorado ser� o processo de inser��o ou atualiza��o dos dados, sendo assim, podemos considerar um �ndice de boa qualidade, quando a quantidade de vezes que o �ndice foi utilizado por uma consulta for maior que a quantidade de atualiza��es (insert, update e delete) realizadas no �ndice.

--As colunas last_user_seek e last_user_scan apesar de trazerem informa��es simples, indicando a �ltima vez que foi realizado index seek ou index scan, n�o devem ser esquecidas. A casos, onde os valores das colunas user_seeks, user_scans e user_lookups, que indicam a quantidade de vezes que o �ndice foi utilizado estarem altos, ou seja, indicando que o �ndice � bem utilizado, os valores das colunas last_user_seek e last_user_scan podem indicar que a ultima vez de utiliza��o deste �ndice aconteceu a meses atr�s.

--Isso pode indicar uma mudan�a na regra de neg�cio ou at� que determinados procedimentos ou relat�rios deixaram de ser utilizados. Quando isso acontece, � importante novamente analisar se vale a pena manter o SGBD trabalhando para manter um �ndice que n�o � mais utilizado, al�m do fator espa�o em disco.

--Nestes casos onde identificamos �ndices que j� foram muito utilizados e atualmente n�o s�o mais, antes de apag�-los guarde um script com seu statement para uma eventual necessidade de recri�-lo.

--Dentre as principais colunas da consulta exposta na Listagem 6 est�o: avg_fragmentation_in_percent, que indica como est� a fragmenta��o externa do �ndice; e a coluna avg_page_space_used_in_percent, que indica a fragmenta��o interna.

--Na fragmenta��o Interna o espa�o interno das p�ginas dos �ndices n�o � utilizado de forma eficiente, fazendo com que seja necess�rio um maior n�mero de p�ginas para armazenar a mesma quantidade de linhas no �ndice, aumentando assim o n�mero de p�ginas que o SQL Server deve ler e alocar em mem�ria para satisfazer opera��es de leitura (select).

--Como o disco r�gido � um dos componentes mais lentos do servidor, diminuir a quantidade de p�ginas que devem ser localizadas no disco para serem enviadas a mem�ria pode gerar um bom ganho em performance.

--Quando o SQL Server precisar adicionar novas linhas de dados nas p�ginas dos �ndices e a p�gina n�o cont�m espa�o necess�rio para receber esta nova linha, ocorre o que chamamos de page split, onde uma nova p�gina � adicionada. Page split mant�m apenas a ordem l�gica das p�ginas, ou seja, o SQL Server sabe onde esta p�gina nova est� localizada, por�m n�o mant�m a ordem f�sica cont�nua das p�ginas. Quando as p�ginas n�o est�o ordenadas fisicamente temos a fragmenta��o externa.

--Fragmenta��o externa � sempre algo indesejado para um �ndice, j� uma pequena quantidade de fragmenta��o interna pode ser �til, evitando assim muitas ocorr�ncias de page split. Contudo, grande quantidade de fragmenta��o seja interna ou externa � sempre indesej�vel, pois afetar� diretamente de forma negativa a performance.

--No caso de fragmenta��o interna, as linhas ser�o distribu�das de forma mais esparsa atrav�s das p�ginas, aumentando o n�mero de opera��es de I/O. J� a fragmenta��o externa causa leituras n�o sequenciais das p�ginas de �ndices em disco, consequentemente quando o SQL Server realizar um scan ou seek no �ndice ele ter� que trocar entre extents (ver Nota Adicional 7) mais que o necess�rio, n�o realizando assim o que chamamos de read-ahead (leituras continuas).

--Nota Adicional 7:  A principal unidade de armazenamento de dados em disco no SQL Server � uma p�gina, com 8KB cada p�gina. Os espa�os alocados em disco pelos arquivos de dados (mdf) e log (ldf), s�o logicamente divididos e representados por p�ginas. Opera��es em disco de entrada e sa�da (I/O) s�o realizadas no n�vel de uma p�gina. Extents � uma cole��o de oito p�ginas cont�nuas, somando 64KB.

--Para resolver o problema de fragmenta��o de um �ndice, seja interna ou externa, � necess�rio realizar uma manuten��o neste �ndice. Esta manuten��o pode ser realizada atrav�s de uma desfragmenta��o, onde o �ndice � reorganizado, ou uma reindexa��o, onde o �ndice � refeito.

--Para decidir entre desfragmenta��o (Reorganize) ou reindexa��o (Rebuild), devemos avaliar a porcentagem de fragmenta��o interna e externa para o �ndice. Abaixo seguem os limites recomendados para decidir entre estas manuten��es:

--avg_fragmentation_in_percent: entre 10 e 15 indica que dever ser realizado um reorganize. Valores superiores a 15 indicam a necessidade de realizar um rebuild;
--avg_page_space_used_in_percent: entre 60 e 75 indica que deve ser realizado um reorganize. Valores abaixo de 60 indicam a necessidade de realizar um rebuild.
--As colunas Total_Pagina_Usada, Total_Pagina_Reservada, Total_Indice_Usado_MB e Total_Indice_Reservado_MB indicam a quantidade de p�ginas utilizadas e reservadas para o �ndice e seus respectivos espa�os ocupadosem disco. Estas informa��es s�o importantes principalmente no momento de decidir em manter ou apagar determinado �ndice. Por exemplo: ao identificarmos que determinado �ndice n�o est� mais sendo utilizado ou � muito pouco utilizado, por�m ocupa alguns gigabytes de espa�o, poder�amos decidir apagar este �ndice e liberar este espa�o para a cria��o de novos �ndices. Em ambientes onde o espa�o em disco � um fator cr�tico, esta pode ser uma informa��o valiosa.

--A coluna fill_factor indica o espa�o interno reservado na p�gina no momento de cria��o do indice, caso definido para 80% por exemplo, indica que 20% da p�gina se manter� livre ao se criar o �ndice. Estes 20%, seriam preenchidos posteriormente atrav�s de inser��es na tabela.

--Caso os valores de colunas chaves de um �ndice n�o forem sequenciais, pode ser interessante deixar uma pequena porcentagem de espa�o livre em suas p�ginas no momento de sua cria��o. Isso poderia evitar opera��es de page split, visto que ao tentar atualizar o �ndice com uma nova inser��o de dados, a p�gina que ir� receb�-lo j� ter� um espa�o dispon�vel.

--� importante saber que estes 20% deixados no momento da cria��o do �ndice n�o s�o mantidos ao longo do tempo, ou seja, a porcentagem livre ser� menor a cada atualiza��o realizada no �ndice. No entanto, ao fazer uma reindexa��o, como o �ndice � recriado, o espa�o indicado no fill_factor � liberado novamente.

--Apesar dos pontos abordados acima, temos que ter cuidado ao definir o fill_factor, pois da mesma forma que ele pode ajudar diminuindo opera��es de page split, se definido de forma exagerada � deixando muito espa�o livre nas p�ginas � pode gerar fragmenta��o interna, pois o espa�o interno das p�ginas n�o ser� utilizado de forma eficiente, fazendo com que seja necess�rio um maior n�mero de p�ginas para armazenar a mesma quantidade de dados.

--A coluna is_padded pode ser 1 ou 0. Caso definida como 1, indica que o mesmo espa�o reservado no n�vel folha pela coluna fill_factor ser� reservado para o n�vel n�o-folha.

--Allow_row_lock e allow_page_lock indicam se � permitido ou n�o locks (bloqueios) em linha e p�ginas no �ndice. As colunas row_lock_count e row_page_count mostram quantos locks foram adquiridos em linhas e em p�ginas at� o momento. As colunas row_lock_wait_count, row_page_wait_count, row_lock_wait_in_ms e row_page_wait_in_ms, informam respectivamente, quantas vezes foram necess�rias ficar aguardando a libera��o de uma p�gina ou linha de um �ndice e a soma do tempo que o SGBD aguardou por estes locks, para executar as solicita��es feitas pelos usu�rios.

--Finalmente, as colunas page_io_latch_wait_count e page_io_latch_wait_in_ms, indicam se houve opera��es f�sicas de I/O para trazer uma p�gina de �ndice ou heap para a mem�ria e quanto tempo foi necess�rio. A an�lise destas colunas deve ser feita de acordo com o baseline de seu ambiente, pois trazer informa��es de disco para mem�ria � uma opera��o normal, principalmente se as p�ginas solicitadas no momento s�o pouco acessadas. Entretanto, quando isso ocorre sempre em grande quantidade e o tempo necess�rio para realizar esta opera��o � demasiadamente elevado, principalmente em �ndices que s�o acessados a todo momento, � um comportamento que deve ser investigado.

--Como podemos observar, a consulta na Listagem 6 traz informa��es sobre �ndices de apenas uma tabela. Apesar de ser poss�vel adapt�-la para trazer informa��es sobre todos os �ndices de um ou mais bancos de dados esta pratica n�o � recomendada, principalmente em grandes bancos de dados.

--Isso se deve principalmente � DMF sys.dm_db_index_physical_stats, que apesar de requerer apenas um Intent-Shared (IS) table lock (ver Nota Adicional 8), dependendo do modo em que � utilizada, varre todas as p�ginas de uma tabela ou �ndice e este cen�rio aplicado a v�rias tabelas com milh�es de registros pode gerar um uso excessivo de recursos do servidor do gerenciador de banco de dados.

--Nota Adicional 8: No SQL Server temos 11 tipos de lock, que v�o de uma linha at� toda a base de dados. Bloquear um recurso no banco de dados � uma opera��o normal, sendo feito para garantir a consist�ncia entre transa��es concorrentes. Al�m dos tipos de locks existe tamb�m o modo de lock, respons�vel por definir como o recurso escolhido pelo SGBD ser� bloqueado e como os locks ir�o se comportar, como por exemplo, compartilhar ou n�o o recurso bloqueado com outra transa��o. Intent-shared (IS) table lock � um modo de lock que permite o compartilhamento do recurso bloqueado por outras transa��es. Para saber mais sobre tipos e modos de lock, acesse os links: http://msdn.microsoft.com/en-us/library/ms189849.aspx e http://msdn.microsoft.com/en-us/library/ms186396.aspx

--Podemos utilizar a consulta demonstrada na Listagem 6, para ter uma vis�o detalhada de como est�o os �ndices criados em sua base de dados, e com base nisso, tomar decis�es relacionadas a cria��o, dele��o ou manuten��o de �ndices.

--Como dito, ela est� preparada por quest�es de performance, para consultar apenas uma tabela por vez. As tabelas a serem consultadas normalmente s�o as principais tabelas do banco de dados, como tabelas de movimenta��o, tabelas com grandes quantidades de registros, tabelas com grande quantidade de �ndices ver (Listagem 7), tabelas com consultas que mais consomem recursos do servidor ver (Listagem 8) e tabelas apontadas nas demais consultas explicadas neste artigo (Listagem 1, Listagem 2, Listagem 3, Listagem 4 e Listagem 5). Podemos tamb�m utiliza-la para criar uma rotina de an�lise geral sobre os �ndices de um banco de dados ou ainda apenas consultar um determinado �ndice espec�fico.

-- Listagem 7. Tabelas com maior quantidade de �ndices.

select x.id, x.table_name, x.Total_index, count(*) as Total_column
from sys.columns cl join
(select ix.object_id as id, tb.name as table_name, count(ix.object_id) as Total_index
from sys.indexes ix join sys.objects tb on tb.object_id = ix.object_id and tb.type = 'u'
group by ix.object_id, tb.name) x on x.id = cl.object_id
group by id, table_name, Total_index
order by 3 desc

--Listagem 8. Consultas que mais consomem processamento do servidor.

SELECT TOP 30 (total_worker_time/execution_count) / 1000 AS [Avg CPU Time ms], SUBSTRING(st.text, (qs.statement_start_offset/2)+1, 
((CASE qs.statement_end_offset
WHEN -1 THEN DATALENGTH(st.text)ELSE qs.statement_end_offset
END - qs.statement_start_offset)/2) + 1) AS statement_text,
execution_count,last_execution_time, 
last_worker_time / 1000 as last_worker_time, 
min_worker_time / 1000 as min_worker_time, 
max_worker_time / 1000 as max_worker_time,
total_physical_reads,last_physical_reads, 
min_physical_reads, max_physical_reads, 
total_logical_writes,last_logical_writes, 
min_logical_writes, max_logical_writes, query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, DEFAULT, DEFAULT) AS qp
ORDER BY 1 DESC;

--Conclus�o

--�ndices s�o extremamente importantes para um banco de dados, pois atrav�s deles conseguimos maior performance para consultas realizadas por aplica��es e usu�rios.

--T�o importante como definir um �ndice de forma correta e eficiente � sua manuten��o e monitora��o, visto que sem uma manuten��o preventiva e pr�-ativa, com o tempo, mesmos os �ndices mais utilizados podem se tornar obsoletos, devido a sua alta fragmenta��o.

--Outra raz�o para um �ndice deixar de ser utilizado s�o altera��es realizadas nas consultas que acessam este �ndice, como por exemplo, alterar as colunas da cl�usula Where de uma consulta. Este, juntamente com a fragmenta��o, � apenas alguns dos tipos de problemas que podemos identificar utilizando as DMVs e DMFs expostas neste artigo.

--Vimos ao longo deste artigo diversas t�cnicas para monitorar, analisar e entender melhor como um �ndice est� sendo de fato utilizado pelo SGBD. Com base nestas informa��es podemos tomar decis�es importantes, como, criar, alterar ou remover um �ndice para melhorar a performance de consultas.

--Foram tamb�m apresentados, os limites da fragmenta��o externa e interna que devemos considerar no momento de decidir entre que tipo de manuten��o dever� ser realizada em um �ndice, podendo ser um rebuild ou reorganize.


--todos os �ndices criado em virtude de lentid�o
select tb.name as table_name, ix.name, ix.fill_factor from sys.indexes ix join sys.objects tb on tb.object_id = ix.object_id and tb.type = 'u' where ix.name like '%analysis%' order by tb.name desc



--�ndices mais utilizados
SELECT DISTINCT so.name as table_name,b.name as index_name, ps.user_scans, ps.user_seeks from sys.dm_db_index_usage_stats ps inner join sysobjects so on so.id = ps.object_id INNER JOIN sys.indexes b ON ps.Object_id = b.OBJECT_ID 
WHERE user_scans > 25 AND user_seeks > 25 AND b.name LIKE '%analysis%'
ORDER BY user_seeks DESC

select DISTINCT b.name as index_name, ps.user_seeks from sys.dm_db_index_usage_stats ps inner join sysobjects so on so.id = ps.object_id INNER JOIN sys.indexes b ON ps.Object_id = b.OBJECT_ID 
AND b.name like '%analysis%'
ORDER BY user_seeks ASC


--Query Lenta
SELECT TOP 10 SUBSTRING(qt.TEXT, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.TEXT) ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1), qs.execution_count, qs.total_logical_reads as total_leitura_memoria, qs.last_logical_reads as ultima_leitura_memoria, qs.total_logical_writes as total_escrita_memoria, qs.last_logical_writes as ultima_escrita_memoria, qs.total_physical_reads as total_leitura_disco, qs.last_physical_reads as ultima_leitura_disco, qs.total_worker_time as tempo_CPU_total, qs.last_worker_time as ultimo_tempo_CPU, qs.total_elapsed_time/1000000 as tempo_total_execucao, qs.last_elapsed_time/1000000 as ultimo_tempo_execucao, qs.last_execution_time as data_ultima_execucao, qp.query_plan as plano_execucao FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
--ORDER BY qs.total_logical_reads DESC -- ordenando por leituras em mem�ria
-- ORDER BY qs.total_logical_writes DESC -- escritas em mem�ria
 ORDER BY qs.total_worker_time DESC -- tempo de CPU
-- ORDER BY qs.total_physical_reads DESC -- leituras do disco

--Se eu quisesse ordenar por tempo de CPU, bastaria trocar as linhas:
--De
--ORDER BY qs.total_logical_reads DESC � ordenando por leituras em mem�ria
--Para
--� ORDER BY qs.total_logical_reads DESC � ordenando por leituras em mem�ria
--De
--� ORDER BY qs.total_worker_time DESC � tempo de CPU
--Para
--ORDER BY qs.total_worker_time DESC � tempo de CPU


--Query Lenta
--SELECT TOP 20 GETDATE() AS 'Collection Date', qs.execution_count AS 'Execution Count', SUBSTRING(qt.text,qs.statement_start_offset/2 +1, (CASE WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 ELSE qs.statement_end_offset END - qs.statement_start_offset )/2 ) AS 'Query Text', DB_NAME(qt.dbid) AS 'DB Name', qs.total_worker_time AS 'Total CPU Time', qs.total_worker_time/qs.execution_count AS 'Avg CPU Time (ms)', qs.total_physical_reads AS 'Total Physical Reads', qs.total_physical_reads/qs.execution_count AS 'Avg Physical Reads', qs.total_logical_reads AS 'Total Logical Reads', qs.total_logical_reads/qs.execution_count AS 'Avg Logical Reads',  qs.total_logical_writes AS 'Total Logical Writes', qs.total_logical_writes/qs.execution_count AS 'Avg Logical Writes', qs.total_elapsed_time AS 'Total Duration', qs.total_elapsed_time/qs.execution_count AS 'Avg Duration (ms)', qp.query_plan AS 'Plan' FROM sys.dm_exec_query_stats AS qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp WHERE qs.execution_count > 50 OR qs.total_worker_time/qs.execution_count > 100 OR qs.total_physical_reads/qs.execution_count > 1000 OR qs.total_logical_reads/qs.execution_count > 1000 OR qs.total_logical_writes/qs.execution_count > 1000 OR qs.total_elapsed_time/qs.execution_count > 1000  ORDER BY qs.execution_count DESC, qs.total_elapsed_time/qs.execution_count DESC, qs.total_worker_time/qs.execution_count DESC, qs.total_physical_reads/qs.execution_count DESC, qs.total_logical_reads/qs.execution_count DESC, qs.total_logical_writes/qs.execution_count DESC

--indice nunca usado
SELECT DISTINCT so.name as table_name,b.name as index_name, ps.user_scans, ps.user_seeks from sys.dm_db_index_usage_stats ps inner join sysobjects so on so.id = ps.object_id INNER JOIN sys.indexes b ON ps.Object_id = b.OBJECT_ID WHERE ps.user_scans = 0 AND ps.user_seeks = 0 ORDER BY user_seeks DESC


