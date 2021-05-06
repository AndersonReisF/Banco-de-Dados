--Do que se trata este artigo:
--Nesse artigo vamos demonstrar como avaliar a utilização e performance de índices no SQL Server 2005 e 2008 utilizando as DMVs (Dynamic Management Views) e DMFs (Dynamic Management Functions). Dentre os tópicos abordados em nossa análise sobre índices, teremos: fragmentação, espaço utilizado, Missing Index e consultas que nos permitirão elencar e entender detalhadamente se os índices estão sendo utilizados de forma eficaz ou se estão apenas ocupando espaço no banco de dados.
 
--Para que serve:
--Este artigo visa auxiliar administradores de banco de dados e desenvolvedores a identificarem como de fato os índices estão sendo utilizados pelo banco de dados, e com base na análise realizada avaliar se determinado índice deve ser excluído, alterado, reorganizado, reindexado ou se existe a necessidade de novos índices para contemplar consultas realizadas pela aplicação.

--Em que situação o tema é útil:
--Este tema é útil para profissionais que desejam ter uma visão ampla dos recursos disponíveis no SQL Server 2005 e 2008 que podem ser utilizados para realizar uma análise técnica detalhada sobre a utilização de índices no banco de dados.

--Avaliando Índices
--A partir da versão 2005 do SQL Server, contamos com novos recursos como DMVs (Dynamic Management Views) e DMFs (Dynamic Management Functions), que, através de metadados, coletados pelo serviço do SQL Server, nos dão uma visão diferenciada sobre como nosso banco e instância estão se comportando.
--Neste artigo, utilizaremos as informações disponibilizadas por estes recursos para realizar uma análise detalhada de como nossos índices estão sendo utilizados, e com base nestas informações, identificarmos, por exemplo, quais são os índices mais utilizados, que tipo de manutenção seria mais apropriada para eles, assim como encontrar índices que não estão sendo utilizados de forma adequada pelas consultas.
--Índices são utilizados para aumentar o desempenho em operações de leitura no banco de dados. Um índice utilizado corretamente pode melhorar exponencialmente a velocidade com que as consultas são retornadas pelo SGBD e diminuir significativamente a quantidade de I/O em disco.
--Essa redução de I/O ocorre porque os dados ao serem indexados passam a utilizar a estrutura criada pelo índice, se limitando a uma busca apenas nas páginas de dados do índice.
--Sem um índice, o SQL Server é obrigado a realizar uma leitura completa em todas as páginas de dados referente à tabela em que o dado solicitado está armazenado.

--Apesar do índice, se bem definido, aumentar o desempenho em operações de leitura e reduzir I/O, ele também gera um custo considerável em operações de escrita. Esse comportamento ocorre porque o índice deve se manter atualizado.
--Para manter o índice atualizado o SQL Server replica, de forma síncrona, todas as alterações (Insert, Update e Delete) realizadas na tabela para o índice. Logo, se uma tabela contém quatro índices, uma única operação de inserção de dados (insert) irá gerar cinco inserções, sendo uma para a tabela e mais uma para cada índice existente.
--O mesmo procedimento ocorre em operações que apagam informações (delete). Em operações que atualizam dados (update) apenas índices que contêm as colunas atualizadas serão afetados.
--Devido a este processo de atualização dos índices, o tamanho utilizado pelo índice em disco estará sempre em constante crescimento. Dessa forma, quanto maior a quantidade de índices, mais espaço em disco precisamos reservar para seu crescimento.
--Uma forma de acompanharmos detalhadamente todos os processos envolvendo índices, desde seu crescimento até a forma com que é utilizado, é utilizando as DMVs e DMFs.

--Visões e Funções Dinâmicas para Índices

--As DMVs e DMFs são visões e funções carregadas pelo próprio serviço do SQL Server com diversos dados sobre operações realizadas no servidor de banco de dados.
--Elas permitem ao administrador do banco uma melhor e mais ampla interpretação das informações sobre armazenamento, manipulação e utilização de seus recursos.
--Dentre as DMVs e DMFs disponíveis a partir do SQL Server 2005, existe uma categoria dedicada apenas a análise de informações sobre índices. Essa categoria é chamada de Index Related Dynamic Management Views and Functions, onde contamos com as seguintes visões e funções:

--sys.dm_db_index_operational_stats: Esta DMF retorna informações referentes a atualizações realizadas, como inserção, atualização ou deleção, para cada partição de uma tabela ou índice;
--sys.dm_db_index_usage_stats: Visão que exibe diferentes tipos de contadores de operações realizadas nos índices, como quantidade de acessos realizados pelo usuário, tipos de acesso como seek ou scan e a última vez em que o índice foi utilizado por uma consulta;
--sys.dm_db_index_physical_stats: Função que lista informações sobre espaço utilizado e fragmentação de índices.
--Na categoria Index Related Dynamic Management Views and Functions ainda temos mais quatro opções, divididas entre funções e visões, que podemos utilizar em conjunto com as DMVs e DMFs citadas acima, para obter informações sobre índices que o SQL Server sugere a criação para aumento de performance em consultas realizadas na base de dados. Estes índices são conhecidos como missing index.

--O SQL Server sugere um novo índice sempre que uma consulta não encontrar um índice que a contemple e o mesmo interpretar que um índice, com as características necessárias para contemplar esta consulta, aumentaria sua performance.

--Sempre que o SQL Server interpretar que um novo índice beneficiaria a performance das consultas realizadas, ele automaticamente irá inserir um registro contendo as informações necessárias para a criação deste novo índice nas seguintes DMVs e DMFs:

--sys.dm_db_missing_index_details: Esta DMV sugere índices que poderiam ser criados para melhorar a performance em consultas realizadas em determinadas tabelas;
--sys.dm_db_missing_index_columns: Ao informar o ID do missing índex, esta função retorna um registro para cada coluna sugerida ao índice e a forma que as colunas devem ser referenciadas pelos operadores na cláusula Where, inclusive colunas que poderiam ser utilizadas para se criar um Covered Index. (ver Nota 2). Estas informações também podem ser visualizadas de forma agrupada na visão sys.dm_db_missing_index_details;
--sys.dm_db_missing_index_group_stats: Esta visão contém informações como: última data em que uma consulta requisitou um índice com as características do índice que está sendo sugerido, o tipo de acesso realizado no índice (Index Scan ou Index  Seek) (ver Nota Adicional 3) e um indicador contendo o impacto que a criação deste índice significaria para as consultas realizadas na tabela afetada;
--sys.dm_db_missing_index_groups: Através desta DMV relacionamos o ID do índice com um ID de grupo. O ID do grupo é utilizado pela visão sys.dm_db_missing_index_group_stats.

--Os valores encontrados nas visões e funções são zerados todas as vezes que o serviço do SQL Server é reiniciado. A partir de agora, veremos como as DMVs e DMFs podem ser utilizadas para realizar uma análise completa sobre os índices criados e os índices sugeridos (missing index).

--Nota Adicional 2: Covered Index são índices que contemplam por completo uma consulta realizada no banco de dados. Normalmente em sua criação é utilizada cláusula INCLUDE, contendo as colunas referenciadas no SELECT. Para um índice ser considerado Covered, todas as colunas referenciadas pelo SELECT, WHERE e JOIN devem fazer parte do índice. Dessa forma, o resultado da consulta pode ser retornado sem a necessidade de acessar os dados da tabela. Covered Index são recomendados apenas para consultas que são muito executadas. Para mais informações sobre índices que cobrem toda a consulta, acesse: http://msdn.microsoft.com/en-us/library/ms189607.aspx.

--Nota Adicional 3: Index Scan, acontece sempre que uma consulta acessa um índice, porém não se utiliza de sua estrutura hierárquica (b-tree) para consultar e retornar os dados de forma eficiente, fazendo com que o otimizador de consulta (query optimizer) percorra todo o índice, atrás dos registros consultados. Este método na grande maioria das vezes consome mais recursos do servidor que o método Index Seek, que percorre o índice através de níveis utilizando a estrutura b-tree, diminuindo assim a quantidade de dados a ser analisado para que seja possível encontrar a informação solicitada. Para mais informações, acesse: http://msdn.microsoft.com/en-us/library/ms177443.aspx.

--Principalmente em bases de dados do tipo OLTP (ver Nota Adicional 4), é muito importante ponderar na criação dos índices e tentar achar sempre um meio termo, onde atenda tanto as necessidades de leitura como de escrita. Este meio termo nem sempre é fácil de identificar.

--Nota Adicional 4: Online Transaction Processing (OLTP), é um tipo de banco de dados onde transações são realizadas em tempo real. São características de uma base de dados OLTP: grande quantidade de usuários; alta concorrência, base de dados normalizada utilizando as formas normais; operações de insert e update predominam sobre operações de select; normalmente são utilizadas para controlar a parte operacional de uma empresa, como um ERP.

--Uma das formas para começar a encontrar este equilíbrio é verificar se os índices criados estão sendo utilizados de forma eficiente. As DMVs e DMFs além de auxiliar neste tipo de análise, podem ser utilizadas para verificar a necessidade de:

--  Criar novos índices;
--  Excluir índices desnecessários;
--  Alterar índices existentes;
--  Realizar manutenções nos índices.
--Neste artigo apresentaremos uma série consultas empregando as visões e funções dinâmicas disponíveis no SQL Server 2005 e 2008, que podem ser utilizadas por administradores de banco de dados (DBA) e desenvolvedores para compreender melhor como os índices de seu banco de dados estão sendo utilizados.

--Será parte do escopo das consultas tópicos como: espaço em disco utilizado pelos índices; avaliar se um índice está sendo bem utilizado; métodos de acesso utilizados pelas consultas que utilizam os índices; tabelas candidatas a receberem novos índices; índices criados, porém não utilizados; identificar quando devemos realizar uma desfragmentação ou reindexação de um índice e, por fim, veremos as consultas que mais consomem recursos de processamento do servidor.

--Tabelas candidatas a receber novos índices

--Como dito anteriormente, existem mecanismos que nos dão uma visão dos índices que poderiam ser criados para aumentar a performance em consultas realizadas em determinadas tabelas.

--Com o intuito de identificar índices que poderiam ser criados para atender esta finalidade, veremos a seguir, uma sequência de consultas que irão se utilizar além das DMVs e DMFs já citadas neste artigo, algumas visões de sistema do SQL Server.

--Iniciaremos nossa analise verificando quais tabelas do banco de dados não possui índices clusterizados. A consulta disponível na Listagem 1 irá informar todas as tabelas onde não existe um índice clusterizado.

-- Listagem 1. Tabelas que não contêm índices clusteriazados.

select distinct(tb.name) as Table_name, p.rows from sys.objects tb join sys.partitions p on p.object_id = tb.object_id Where type = 'U' and tb.object_id not in ( select ix.object_id from sys.indexes ix where type = 1 ) order by p.rows desc

--Índices clusterizados determinam a forma com que a tabela é ordenada fisicamente e são extremamente importantes para as consultas realizadas em uma tabela. Com a criação do índice clusterizado , a tabela deixa de utilizar uma estrutura chamada Heap (ver Nota Adicional 5) e se torna uma Clustered Table.

--Nota Adicional 5: Heap é uma tabela que não contém um índice clusterizado. Seus dados são gravados fisicamente sem uma ordenação estabelecida. Dessa forma, sempre que for necessário encontrar um dado na tabela, é realizado um scan completo em suas páginas de dados.

--Normalmente, índices clusterizados estão associados a chaves primárias. Por padrão, quando você cria uma chave primária, a não ser que seja definido pelo usuário outro tipo de índice ou já exista um índice deste tipo na tabela, é criado um índice clusterizado utilizando as colunas da chave criada. A Listagem 2 mostra como identificar todas as tabelas que não possuem chave primária definida.

-- Listagem 2. Tabelas que não possuem chave primária.

select distinct(tb.name) as Table_name, p.rows from sys.objects tb join sys.partitions p on p.object_id = tb.object_id Where type = 'U' and tb.object_id not in ( select ix.parent_object_id from sys.key_constraints ix where type = 'PK' ) order by p.rows desc

--Chave primária (Primary Key – PK) e índice clusterizado são conceitos básicos que devem ser aplicados a todas as tabelas de um banco de dados, principalmente para os bancos com o perfil OLTP (ver Nota Adicional 4).

--Sem uma PK não temos um ponto de referencia, utilizado para identificar e relacionar registros entre tabelas, já sem um índice clusterizado a tabela é gravada de forma desordenada, afetando diretamente a performance em operações de leitura. Assim, poderíamos criar índices clusterizados e chaves primarias nas tabelas indicadas na Listagens 1 e 2, respectivamente.

--É importante salientar que não basta apenas criar índices clusterizados e chaves primarias nas tabelas. Os mesmos devem ser definidos estrategicamente, levando em consideração as boas práticas para tal atividade. Caso contrário, poderíamos gerar outros problemas, como fragmentação, uso excessivo de espaço em disco e desnormalização.

--Os conceitos e boas práticas para criação destes objetos é um assunto amplo e não será abordado neste artigo. Para quem desejar mais informações sobre, acesse o link: http://msdn.microsoft.com/pt-br/library/ms186342.aspx.

--Outra forma de identificar tabelas candidatas a receber novos índices é analisar os índices sugeridos pelo SQL Server.

--A Listagem 3, traz um lista das tabelas mais impactadas pela falta de índices que contemplassem as consultas realizadas contra a tabela, ordenadas pelo impacto positivo gerado na performance das consultas, caso fosse criado os índices sugeridos pelo SQL Server.

--Quanto maior o impacto, maior a chance das consultas realizadas na tabela se beneficiarem com a criação dos índices.

--Listagem 3. Tabelas que mais seriam beneficiadas com novos índices.

SELECT TOP 30 AVG((avg_total_user_cost * avg_user_impact * (user_seeks + user_scans))) as Impacto,mid.object_id, mid.statement as Tabela
FROM sys.dm_db_missing_index_group_stats AS migs
JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle 
JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle and database_id = db_id() 
GROUP BY mid.object_id, mid.statement 
ORDER BY Impacto DESC;

--A lista das tabelas que mais se beneficiariam com a criação de novos índices já nos dá uma informação valiosa, indicando que estão sendo realizadas consultas não contempladas pelos índices existentes nestas tabelas. A partir deste momento, poderíamos dar uma atenção especial à forma com que elas estão sendo acessadas pelas aplicações.

--Para completar a informação obtida com a execução da consulta na Listagem 3, veremos agora, como trazer a lista dos índices sugeridos pelo SQL Server que mais impactariam nas tabelas obtidas anteriormente.

--Para obter a lista dos índices, execute, em seu banco de dados a consulta demonstrada na Listagem 4.

--Listagem 4. Top 30 índices, sugeridos pelo SGBD.

SELECT TOP 30 (avg_total_user_cost * avg_user_impact * (user_seeks + user_scans)) as Impacto, migs.group_handle, mid.index_handle, migs.user_seeks,migs.user_scans, mid.object_id, mid.statement, mid.equality_columns, mid.inequality_columns, mid.included_columns 
FROM sys.dm_db_missing_index_group_stats AS migs
JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle 
JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle and database_id = db_id() 
--AND mid.object_id = object_id('conceitos') -- se desejar ver apenas para uma tabela específica
ORDER BY Impacto DESC;
--ORDER BY user_seeks DESC;


--Abaixo segue uma breve descrição das colunas listadas pela consulta apresentada na Listagem 4.

--Impacto: Quanto maior o impacto, mais benefícios serão obtidos com a criação do índice;
--Group_handle: Identificador único do índice sugerido.
--User_seeks: Quantidade de vezes, utilizando o método de busca 'Index Seek', que uma consulta realizada pelo usuário seria contemplada por este índice, caso existisse;
--User_scan: Quantidade de vezes, utilizando o método de busca 'Index Scan', que uma consulta realizada pelo usuário seria contemplada por este índice, caso existisse.;
--Object_id: Identificador único da tabela no banco de dados
--Statement: Tabela onde o índice deveria ser criado;
--Equality_columns: Colunas que fazem parte do Where de uma consulta utilizando o operador igual (=). Ex: select * from tab where val = 1. Neste caso a coluna chamada 'val', aparecerá como resultado desta coluna.
--Inequality_columns: Colunas que fazem parte da clausula Where de uma consulta e se utilizam de operadores diferentres de igual (=) como os operadores (> < <> between); Ex: select * from tab where val <> 1.
--Included_columns: Colunas que poderiam ser adicionadas para criar um Covered Index (ver Nota Adicional 2).
--As colunas equality_columns e inequality_columns indicam as colunas chaves do indice e a coluna included_columns indica as colunas não-chaves. As colunas não chaves são incluidas através da clausula 'include' na sentença de criação do indice

--Uma observação importante é que nem todos os índices sugeridos pelo SGBD devem ser criados sem uma prévia análise. Podem ocorrer casos em que já existam índices parecidos com o índice que foi sugerido. Neste caso, talvez apenas uma alteração no índice existente já atenda a necessidade das consultas que atualmente não estão sendo contempladas por este índice.
--A decisão final, que confirma se o índice deve ser criado ou não, sempre deve ficar com o DBA.

-- Índices candidatos a serem excluídos

--Quando criamos um índice, é de extrema importância, realizar periodicamente consultas nos metadados do SQL Server, para verificar seu estado e desta forma definir se existe a necessidade ou não de realizar manutenções.

--Sem este acompanhamento pode ocorrer de surgirem índices inuteis, que apenas geram trabalho ao SGBD. Isso pode acontecer devido a uma falta de manutenção ou até uma má definição na criação do índices.

--Estes índices que estão criados e não são utilizados, poderiam ser exluidos, melhorando assim performance de operações que realizam insert, delete ou update e ainda diminuindo o esforço realizado para manter estes índices atualizados.

--Sempre que ocorrer uma operação de Insert ou Delete em uma tabela, a mesma deverá ser replicada para todos os índices criados na mesma, independente de serem utilizados ou não pelas consultas realizadas pelos usuários. Em operações de Update, apenas os índices contendo as colunas atualizadas serão afetados.

--Deste modo, manter índices não utilizados pode custar caro, pois além de desperdiçar espaço em disco, gera um trabalho extra de administração ao SGBD.

--Após identificar os índices que não estão sendo utilizados, antes de apagá-los, é recomendável realizar um backup de sua estrutura. Assim, caso algum dia seja necessário recriá-lo, basta utilizar o backup de estrutura criado para este índice.

--Para verificar todos os índices que nunca foram utilizados pelo banco de dados, execute a consulta da Listagem 5.

-- Listagem 5. Índices nunca ou pouco utilizados pelo SGBD.

select tb.name as Table_Name, ix.name as Index_Name, ix.type_desc, leaf_insert_count,leaf_delete_count, leaf_update_count, nonleaf_insert_count ,nonleaf_delete_count, nonleaf_update_count, vw.user_seeks, vw.user_scans, vw.user_lookups, vw.system_seeks, vw.system_scans, vw.system_lookups 
from sys.dm_db_index_usage_stats vw join sys.objects tb on tb.object_id = vw.object_id join sys.indexes ix on ix.index_id = vw.index_id and ix.object_id = tb.object_id
join sys.dm_db_index_operational_stats(db_id('CampaignControl'), Null, NULL, NULL) vwx on vwx.object_id = tb.object_id and vwx.index_id = ix.index_id where vw.database_id = db_id('CampaignControl')
and vw.user_seeks <= 50 and vw.user_scans <= 50 and vw.user_lookups <= 50 and vw.system_seeks <= 50 and vw.system_scans <= 50 and vw.system_lookups <= 50 and ix.name like 'IX_%'
order By leaf_insert_count desc, tb.name asc, ix.name asc


--As colunas leaf_insert_count,leaf_delete_count,leaf_update_count, indicam a quantidade de atualizações ocorridas no nível folha do índice por operações de Insert, Delete e Update, respectivamente.

--As mesmas colunas precedidas do prefixo 'non', representam as operações de Insert, Delete e Update, porém no nível root e intermediário (ver Nota Adicional 6) de um índice.

--A coluna Type_Desc descreve o tipo do índice listado, podendo ser HEAP, CLUSTERED, NONCLUSTERED, XML ou SPATIAL (sendo este último, apenas disponível no SQL Server 2008).

--Nota Adicional 6: No SQL Server, índices são organizados em B-trees. Cada página em uma B-tree é conhecida como um nó (index node). O nó mais alto é chamado de root (root node). O nível mais baixo é chamado leaf (leaf nodes). Outros níveis (nós) de um índice ficam entre os nós root e leaf, estes são conhecidos como intermediate levels (níveis intermediários). No índice clusterizado, o nível mais baixo (leaf node ou nível folha), contém todos os dados da tabela. Para o índice não clusterizado o nível mais baixo contém os valores das chaves que foram definidas na criação do índice, mais o apontamento para o índice clusterizado. Nos níveis root e intermediate ficam os apontamentos (ponteiros), contendo as palavras chaves definidas para o índice que apontam para nível mais baixo, onde de fato está a informação.

--Avaliando a utilização dos índices

--Até o momento vimos como identificar índices que, se criados, poderiam beneficiar o desempenho em consultas a determinadas tabelas, e índices que que não são utilizados pelo SGBD e portanto poderiam ser excluidos.

--É importante salientar que até o momento adotamos como parâmetro para decidir quando excluir um índice apenas o fato dele já ter sido utilizado ou não em uma consulta. No entanto, além destes, existem outros fatores que podemos considerar para tomar uma decisão como esta.

--A seguir, através da consulta disponível na Listagem 6, iremos muito além de avaliar dados que influenciam na decisão de manter ou não um índice. Veremos informações referentes à fragmentação dos índices, o que determina se um índice deve ser desfragmentado ou reindexado. A média de operações de insert, update e delete realizadas contra o índice, comparadas com a quantidade de vezes que o índice foi utilizado por uma consulta, determinando desta forma a qualidade deste índice. Veremos também algumas propriedades que, de acordo com sua definição, podem afetar diretamente a forma com que o índice é armazenado em disco, além de outros dados que são de extrema importância para uma avaliação mais precisa sobre a utilização dos índices.

-- Listagem 6. Avaliando índices.
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

--Abaixo veremos uma breve descrição de como devemos avaliar as colunas utilizadas pela consulta descrita na Listagem 6.

--Podemos utilizar as colunas user_seeks, user_scans e user_lookups para identificarmos os indices mais e menos utilizados. Caso estas três colunas retornem o valor 0, indica que se trata de um índice que nunca foi utilizado pelo usuário.

--O ideal é que o valor de user_seeks sempre esteja superior aos das colunas user_scans e user_lookups, indicando, desta forma, que o SQL Server está navegando no índice e não varrendo-o por completo (user_scans) ou se utilizando de outros índices, como o índice clusterizado para resgatar as demais colunas solicitadas na busca, porém não contempladas pelo índice (user_lookups).

--A coluna Total_User_Escrita representa o quanto o índice está sendo atualizado por operações de inserção, atualização e deleção de dados realizadas na tabela (Insert, Update e Delete), e a coluna Total_User_Leitura (Select) indica o quanto o índice está sendo utilizado para operações de leitura.

--Índices onde a quantidade de atualizações (Total_User_Escrita) é consideravelmente maior que a quantidade de consultas (Total_User_Leitura), indica a necessidade de uma avaliação mais detalhada do DBA. Neste caso, pode ser que o custo empregado para mantê-los atualizado seja muito maior que o benefício adquirido com sua existencia, já que o principal objetivo de um índice é otimizar a performance em consultas.

--Sempre que uma informação é alterada, incluída ou apagada de uma tabela, a mesma coisa acontece nos índices criados para esta tabela. Logo, quanto mais índices existir em uma tabela, mais demorado será o processo de inserção ou atualização dos dados, sendo assim, podemos considerar um índice de boa qualidade, quando a quantidade de vezes que o índice foi utilizado por uma consulta for maior que a quantidade de atualizações (insert, update e delete) realizadas no índice.

--As colunas last_user_seek e last_user_scan apesar de trazerem informações simples, indicando a última vez que foi realizado index seek ou index scan, não devem ser esquecidas. A casos, onde os valores das colunas user_seeks, user_scans e user_lookups, que indicam a quantidade de vezes que o índice foi utilizado estarem altos, ou seja, indicando que o índice é bem utilizado, os valores das colunas last_user_seek e last_user_scan podem indicar que a ultima vez de utilização deste índice aconteceu a meses atrás.

--Isso pode indicar uma mudança na regra de negócio ou até que determinados procedimentos ou relatórios deixaram de ser utilizados. Quando isso acontece, é importante novamente analisar se vale a pena manter o SGBD trabalhando para manter um índice que não é mais utilizado, além do fator espaço em disco.

--Nestes casos onde identificamos índices que já foram muito utilizados e atualmente não são mais, antes de apagá-los guarde um script com seu statement para uma eventual necessidade de recriá-lo.

--Dentre as principais colunas da consulta exposta na Listagem 6 estão: avg_fragmentation_in_percent, que indica como está a fragmentação externa do índice; e a coluna avg_page_space_used_in_percent, que indica a fragmentação interna.

--Na fragmentação Interna o espaço interno das páginas dos índices não é utilizado de forma eficiente, fazendo com que seja necessário um maior número de páginas para armazenar a mesma quantidade de linhas no índice, aumentando assim o número de páginas que o SQL Server deve ler e alocar em memória para satisfazer operações de leitura (select).

--Como o disco rígido é um dos componentes mais lentos do servidor, diminuir a quantidade de páginas que devem ser localizadas no disco para serem enviadas a memória pode gerar um bom ganho em performance.

--Quando o SQL Server precisar adicionar novas linhas de dados nas páginas dos índices e a página não contém espaço necessário para receber esta nova linha, ocorre o que chamamos de page split, onde uma nova página é adicionada. Page split mantém apenas a ordem lógica das páginas, ou seja, o SQL Server sabe onde esta página nova está localizada, porém não mantém a ordem física contínua das páginas. Quando as páginas não estão ordenadas fisicamente temos a fragmentação externa.

--Fragmentação externa é sempre algo indesejado para um índice, já uma pequena quantidade de fragmentação interna pode ser útil, evitando assim muitas ocorrências de page split. Contudo, grande quantidade de fragmentação seja interna ou externa é sempre indesejável, pois afetará diretamente de forma negativa a performance.

--No caso de fragmentação interna, as linhas serão distribuídas de forma mais esparsa através das páginas, aumentando o número de operações de I/O. Já a fragmentação externa causa leituras não sequenciais das páginas de índices em disco, consequentemente quando o SQL Server realizar um scan ou seek no índice ele terá que trocar entre extents (ver Nota Adicional 7) mais que o necessário, não realizando assim o que chamamos de read-ahead (leituras continuas).

--Nota Adicional 7:  A principal unidade de armazenamento de dados em disco no SQL Server é uma página, com 8KB cada página. Os espaços alocados em disco pelos arquivos de dados (mdf) e log (ldf), são logicamente divididos e representados por páginas. Operações em disco de entrada e saída (I/O) são realizadas no nível de uma página. Extents é uma coleção de oito páginas contínuas, somando 64KB.

--Para resolver o problema de fragmentação de um índice, seja interna ou externa, é necessário realizar uma manutenção neste índice. Esta manutenção pode ser realizada através de uma desfragmentação, onde o índice é reorganizado, ou uma reindexação, onde o índice é refeito.

--Para decidir entre desfragmentação (Reorganize) ou reindexação (Rebuild), devemos avaliar a porcentagem de fragmentação interna e externa para o índice. Abaixo seguem os limites recomendados para decidir entre estas manutenções:

--avg_fragmentation_in_percent: entre 10 e 15 indica que dever ser realizado um reorganize. Valores superiores a 15 indicam a necessidade de realizar um rebuild;
--avg_page_space_used_in_percent: entre 60 e 75 indica que deve ser realizado um reorganize. Valores abaixo de 60 indicam a necessidade de realizar um rebuild.
--As colunas Total_Pagina_Usada, Total_Pagina_Reservada, Total_Indice_Usado_MB e Total_Indice_Reservado_MB indicam a quantidade de páginas utilizadas e reservadas para o índice e seus respectivos espaços ocupadosem disco. Estas informações são importantes principalmente no momento de decidir em manter ou apagar determinado índice. Por exemplo: ao identificarmos que determinado índice não está mais sendo utilizado ou é muito pouco utilizado, porém ocupa alguns gigabytes de espaço, poderíamos decidir apagar este índice e liberar este espaço para a criação de novos índices. Em ambientes onde o espaço em disco é um fator crítico, esta pode ser uma informação valiosa.

--A coluna fill_factor indica o espaço interno reservado na página no momento de criação do indice, caso definido para 80% por exemplo, indica que 20% da página se manterá livre ao se criar o índice. Estes 20%, seriam preenchidos posteriormente através de inserções na tabela.

--Caso os valores de colunas chaves de um índice não forem sequenciais, pode ser interessante deixar uma pequena porcentagem de espaço livre em suas páginas no momento de sua criação. Isso poderia evitar operações de page split, visto que ao tentar atualizar o índice com uma nova inserção de dados, a página que irá recebê-lo já terá um espaço disponível.

--É importante saber que estes 20% deixados no momento da criação do índice não são mantidos ao longo do tempo, ou seja, a porcentagem livre será menor a cada atualização realizada no índice. No entanto, ao fazer uma reindexação, como o índice é recriado, o espaço indicado no fill_factor é liberado novamente.

--Apesar dos pontos abordados acima, temos que ter cuidado ao definir o fill_factor, pois da mesma forma que ele pode ajudar diminuindo operações de page split, se definido de forma exagerada – deixando muito espaço livre nas páginas – pode gerar fragmentação interna, pois o espaço interno das páginas não será utilizado de forma eficiente, fazendo com que seja necessário um maior número de páginas para armazenar a mesma quantidade de dados.

--A coluna is_padded pode ser 1 ou 0. Caso definida como 1, indica que o mesmo espaço reservado no nível folha pela coluna fill_factor será reservado para o nível não-folha.

--Allow_row_lock e allow_page_lock indicam se é permitido ou não locks (bloqueios) em linha e páginas no índice. As colunas row_lock_count e row_page_count mostram quantos locks foram adquiridos em linhas e em páginas até o momento. As colunas row_lock_wait_count, row_page_wait_count, row_lock_wait_in_ms e row_page_wait_in_ms, informam respectivamente, quantas vezes foram necessárias ficar aguardando a liberação de uma página ou linha de um índice e a soma do tempo que o SGBD aguardou por estes locks, para executar as solicitações feitas pelos usuários.

--Finalmente, as colunas page_io_latch_wait_count e page_io_latch_wait_in_ms, indicam se houve operações físicas de I/O para trazer uma página de índice ou heap para a memória e quanto tempo foi necessário. A análise destas colunas deve ser feita de acordo com o baseline de seu ambiente, pois trazer informações de disco para memória é uma operação normal, principalmente se as páginas solicitadas no momento são pouco acessadas. Entretanto, quando isso ocorre sempre em grande quantidade e o tempo necessário para realizar esta operação é demasiadamente elevado, principalmente em índices que são acessados a todo momento, é um comportamento que deve ser investigado.

--Como podemos observar, a consulta na Listagem 6 traz informações sobre índices de apenas uma tabela. Apesar de ser possível adaptá-la para trazer informações sobre todos os índices de um ou mais bancos de dados esta pratica não é recomendada, principalmente em grandes bancos de dados.

--Isso se deve principalmente à DMF sys.dm_db_index_physical_stats, que apesar de requerer apenas um Intent-Shared (IS) table lock (ver Nota Adicional 8), dependendo do modo em que é utilizada, varre todas as páginas de uma tabela ou índice e este cenário aplicado a várias tabelas com milhões de registros pode gerar um uso excessivo de recursos do servidor do gerenciador de banco de dados.

--Nota Adicional 8: No SQL Server temos 11 tipos de lock, que vão de uma linha até toda a base de dados. Bloquear um recurso no banco de dados é uma operação normal, sendo feito para garantir a consistência entre transações concorrentes. Além dos tipos de locks existe também o modo de lock, responsável por definir como o recurso escolhido pelo SGBD será bloqueado e como os locks irão se comportar, como por exemplo, compartilhar ou não o recurso bloqueado com outra transação. Intent-shared (IS) table lock é um modo de lock que permite o compartilhamento do recurso bloqueado por outras transações. Para saber mais sobre tipos e modos de lock, acesse os links: http://msdn.microsoft.com/en-us/library/ms189849.aspx e http://msdn.microsoft.com/en-us/library/ms186396.aspx

--Podemos utilizar a consulta demonstrada na Listagem 6, para ter uma visão detalhada de como estão os índices criados em sua base de dados, e com base nisso, tomar decisões relacionadas a criação, deleção ou manutenção de índices.

--Como dito, ela está preparada por questões de performance, para consultar apenas uma tabela por vez. As tabelas a serem consultadas normalmente são as principais tabelas do banco de dados, como tabelas de movimentação, tabelas com grandes quantidades de registros, tabelas com grande quantidade de índices ver (Listagem 7), tabelas com consultas que mais consomem recursos do servidor ver (Listagem 8) e tabelas apontadas nas demais consultas explicadas neste artigo (Listagem 1, Listagem 2, Listagem 3, Listagem 4 e Listagem 5). Podemos também utiliza-la para criar uma rotina de análise geral sobre os índices de um banco de dados ou ainda apenas consultar um determinado índice específico.

-- Listagem 7. Tabelas com maior quantidade de índices.

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

--Conclusão

--Índices são extremamente importantes para um banco de dados, pois através deles conseguimos maior performance para consultas realizadas por aplicações e usuários.

--Tão importante como definir um índice de forma correta e eficiente é sua manutenção e monitoração, visto que sem uma manutenção preventiva e pró-ativa, com o tempo, mesmos os índices mais utilizados podem se tornar obsoletos, devido a sua alta fragmentação.

--Outra razão para um índice deixar de ser utilizado são alterações realizadas nas consultas que acessam este índice, como por exemplo, alterar as colunas da cláusula Where de uma consulta. Este, juntamente com a fragmentação, é apenas alguns dos tipos de problemas que podemos identificar utilizando as DMVs e DMFs expostas neste artigo.

--Vimos ao longo deste artigo diversas técnicas para monitorar, analisar e entender melhor como um índice está sendo de fato utilizado pelo SGBD. Com base nestas informações podemos tomar decisões importantes, como, criar, alterar ou remover um índice para melhorar a performance de consultas.

--Foram também apresentados, os limites da fragmentação externa e interna que devemos considerar no momento de decidir entre que tipo de manutenção deverá ser realizada em um índice, podendo ser um rebuild ou reorganize.


--todos os índices criado em virtude de lentidão
select tb.name as table_name, ix.name, ix.fill_factor from sys.indexes ix join sys.objects tb on tb.object_id = ix.object_id and tb.type = 'u' where ix.name like '%analysis%' order by tb.name desc



--Índices mais utilizados
SELECT DISTINCT so.name as table_name,b.name as index_name, ps.user_scans, ps.user_seeks from sys.dm_db_index_usage_stats ps inner join sysobjects so on so.id = ps.object_id INNER JOIN sys.indexes b ON ps.Object_id = b.OBJECT_ID 
WHERE user_scans > 25 AND user_seeks > 25 AND b.name LIKE '%analysis%'
ORDER BY user_seeks DESC

select DISTINCT b.name as index_name, ps.user_seeks from sys.dm_db_index_usage_stats ps inner join sysobjects so on so.id = ps.object_id INNER JOIN sys.indexes b ON ps.Object_id = b.OBJECT_ID 
AND b.name like '%analysis%'
ORDER BY user_seeks ASC


--Query Lenta
SELECT TOP 10 SUBSTRING(qt.TEXT, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.TEXT) ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1), qs.execution_count, qs.total_logical_reads as total_leitura_memoria, qs.last_logical_reads as ultima_leitura_memoria, qs.total_logical_writes as total_escrita_memoria, qs.last_logical_writes as ultima_escrita_memoria, qs.total_physical_reads as total_leitura_disco, qs.last_physical_reads as ultima_leitura_disco, qs.total_worker_time as tempo_CPU_total, qs.last_worker_time as ultimo_tempo_CPU, qs.total_elapsed_time/1000000 as tempo_total_execucao, qs.last_elapsed_time/1000000 as ultimo_tempo_execucao, qs.last_execution_time as data_ultima_execucao, qp.query_plan as plano_execucao FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
--ORDER BY qs.total_logical_reads DESC -- ordenando por leituras em memória
-- ORDER BY qs.total_logical_writes DESC -- escritas em memória
 ORDER BY qs.total_worker_time DESC -- tempo de CPU
-- ORDER BY qs.total_physical_reads DESC -- leituras do disco

--Se eu quisesse ordenar por tempo de CPU, bastaria trocar as linhas:
--De
--ORDER BY qs.total_logical_reads DESC — ordenando por leituras em memória
--Para
--— ORDER BY qs.total_logical_reads DESC — ordenando por leituras em memória
--De
--— ORDER BY qs.total_worker_time DESC — tempo de CPU
--Para
--ORDER BY qs.total_worker_time DESC — tempo de CPU


--Query Lenta
--SELECT TOP 20 GETDATE() AS 'Collection Date', qs.execution_count AS 'Execution Count', SUBSTRING(qt.text,qs.statement_start_offset/2 +1, (CASE WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 ELSE qs.statement_end_offset END - qs.statement_start_offset )/2 ) AS 'Query Text', DB_NAME(qt.dbid) AS 'DB Name', qs.total_worker_time AS 'Total CPU Time', qs.total_worker_time/qs.execution_count AS 'Avg CPU Time (ms)', qs.total_physical_reads AS 'Total Physical Reads', qs.total_physical_reads/qs.execution_count AS 'Avg Physical Reads', qs.total_logical_reads AS 'Total Logical Reads', qs.total_logical_reads/qs.execution_count AS 'Avg Logical Reads',  qs.total_logical_writes AS 'Total Logical Writes', qs.total_logical_writes/qs.execution_count AS 'Avg Logical Writes', qs.total_elapsed_time AS 'Total Duration', qs.total_elapsed_time/qs.execution_count AS 'Avg Duration (ms)', qp.query_plan AS 'Plan' FROM sys.dm_exec_query_stats AS qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp WHERE qs.execution_count > 50 OR qs.total_worker_time/qs.execution_count > 100 OR qs.total_physical_reads/qs.execution_count > 1000 OR qs.total_logical_reads/qs.execution_count > 1000 OR qs.total_logical_writes/qs.execution_count > 1000 OR qs.total_elapsed_time/qs.execution_count > 1000  ORDER BY qs.execution_count DESC, qs.total_elapsed_time/qs.execution_count DESC, qs.total_worker_time/qs.execution_count DESC, qs.total_physical_reads/qs.execution_count DESC, qs.total_logical_reads/qs.execution_count DESC, qs.total_logical_writes/qs.execution_count DESC

--indice nunca usado
SELECT DISTINCT so.name as table_name,b.name as index_name, ps.user_scans, ps.user_seeks from sys.dm_db_index_usage_stats ps inner join sysobjects so on so.id = ps.object_id INNER JOIN sys.indexes b ON ps.Object_id = b.OBJECT_ID WHERE ps.user_scans = 0 AND ps.user_seeks = 0 ORDER BY user_seeks DESC


