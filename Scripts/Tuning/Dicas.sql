-- HASH JOIN, MERGE JOIN E NESTED LOOP
https://imasters.com.br/data/otimizador-de-consultas-e-dica-hash-join

HASH JOIN: neste método, cria-se uma tabela com a lista de campos pesquisados (com base nos valores da menor das duas tabelas) e os registros da outra tabela são comparados com os valores da tabela construída;
MERGE JOIN: quando as tabelas são grandes e possuem índices apropriados, geralmente o otimizador de consultas prefere este método;
NESTED LOOP: quando uma das tabelas envolvidas não for tão grande ou quando os dados não estiverem ordenados, este método costuma ser mais eficiente.


-- limpeza de cache, planos e paginas
CHECKPOINT -- flushes dirty pages to disk
DBCC DROPCLEANBUFFERS -- clears data cache
DBCC FREEPROCCACHE -- clears execution plan cache