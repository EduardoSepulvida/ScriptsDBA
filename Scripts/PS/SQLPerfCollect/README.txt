O SQLPerfCollect é um projeto que ajuda a coletar  métricas de diversas fontes do Windows para analisarmos quando houver problemas no ambiente SQL.
As métricas possuem uma frequência muito alta, alguma na casa dos segundos, outras coletam atividade do kernel do Windows, sql, etc.

Isso é muito útil em situações de problemas. Aqui segue um pequeno mtutorial de instalação, seguindo os padrões para os clientes Power Tuning:


- Copiar todo o conteudo desta pasta para um diretorio no cliente
	O subd-diretório "tools" é opcional.
	Escolha um diretorio em um disco com pelo menos 50GB de espaço.
	Se não existir criar. Para manter o padrão:
		Letra:\PwtPerf		
	
	Eu geralmente tenho escolhido C:\PwtPerf (desde que o C:\ tenha espaço disponível)


- Abrir um powershell como Adminsitrador (Se não tiver acesso como administrador, nem adianta, pois é um pré-req para as coletas do perfmon)

	Executar o script abaixo:
		C:\PwtPerf\InstallPerfCollect.ps1 -ScriptRootBase -StartProfile SqlProcAsync

	Ele vai criar um script em C:\PwtPerf\StartPerfCollect.ps1
	Ele vai criar uma task agendada em DBA\
	Se algo falhar, ele vai exibir uma mensagem de erro na tela. Se tudo for ok, você vai ver "Done" e "ok"	

	A tarefa agendada deve iniciar em até 1 min, espere iniciar para testar que o agendamento está funcionando.
	O Status deverá ficar "Running".
	

- Quando a tarefada agendada executar, verifique se apareceu um diretório chamado C:\PwtPerf\collects
	Se tudo ocorreu bem, ele vai criar um arquivo log.log
	A partir dai, você pode acompanhar o processo por este arquivo de log.
	Ele vai gerar um série de subdiretórios contendo algumas coletas e configurações.
	Se o arquivo log.log não apareceu, procure o Rodrigo para ajudar no debug.

- Confirme que ele está gerando os arquivos (ordende pela data de modificação, descrescente)
	C:\PwtPerf\collects\log_perfcounters (arquivos .txt e .blog)
	C:\PwtPerf\collects\log_process (arquivos xml)
	C:\PwtPerf\collects\log_sql\<NOME_INSTANCIA> (arquivos .xml)

	Ordende pela data de modificação decrescente e observe se ela está avançando

	Caso não apareça, verifique se no log tem algo útil para entender o porque.
	caso não tenha log criado, verifique o event viewer e procure por um erro no log Application

Todo dia entre e verifique até garantir que tudo está ok e que o espaço em disco está se mantendo conforme configurado no parâmetro.
Abrir um ticket e colocar o vencimento para daqui 1 semana, para que você lembre de fazer o acompanhamento semanal.


- OPCIONAL: Se necessário ajuste os parametros dentro de StartPerfCollect.ps1 (max disk size, etc.)
	Geralmente, eu posso ajustar o MaxCollectSize.
	note que você não pode alterar nada na pasta C:\PwtPerf sem a permissão de Administrador.
	Por isso, se tiver que alterar qualquer coisa, use o powershell que abriu como administrador.

	Depois que ajustar de um "Stop/Start" na TAREFA AGENDADA que foi criada.


EM CASO DE PROBLEMAS:


- Pare a tarefa agenada e exclua ela.
- Remova os arquivos de \PwtPerf (se tiver com problemas de espaço em disco)
- Abra o performance monitor, vá em "Data Collector Sets", em "User Defined" e dé um stop nos collector com o nome "SQLPerfCollect" (caso estejam em execução)

O maior problema que pode ocorrer devido a isso, é espaço em disco, uma vez que ele coleta muitos arquivos.
O script tem a inteligência para manter o espaço em -MaxCollectSize, mas se ele não estiver cumprindo isso (por bug) você precisa atuar e informar o Rodrigo.

Outro problema que pode acontecer, mas as chances são muito pequenas, é a utilização de CPU ou memória aumentar.
Se isso ocorrer, avalie se é algum processo "powershell.exe". Se não for, dificilmente a culpa é isso.
Caso a culpa seja do powershell.exe, então pare a tarefa agenada conforme acima e avalie se normaliza.

		PORÉM, NÃO É ESPERADO QUE ESSA COLETA GERE IMPACTOS NEGATIVOS NO USO DOS RECURSOS DO CLIENTE
		ENTÃO, AVALIE BEM ANTES DE TOMAR ALGUMA AÇÃO



