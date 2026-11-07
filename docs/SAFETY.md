# Segurança e limites

Este projeto é uma **reescrita independente e genérica para portfólio**. O script de referência continha detalhes de ambiente e uma rotina destrutiva de retenção. Nenhuma infraestrutura, código corporativo ou nome interno foi transportado para esta demonstração.

## O que o projeto FAZ

1. Mostra registros fictícios e, opcionalmente, registra metadados em JSON no próprio repositório.
2. Calcula pastas lógicas com nomes gerados a partir de valores validados.
3. Filtra registros por data e localidade e exporta CSV e HTML a pedido do usuário.
4. Sinaliza registros antigos para revisão, sem executar exclusões.
5. Pode gravar um único registro em um banco SQL Server local, manualmente configurado, somente após confirmação explícita.

## O que NÃO faz

- Não gera, restaura, copia, move ou valida arquivos `.bak`.
- Não remove backups antigos, pastas da rede, bancos SQL ou arquivos do usuário.
- Não abre conexões automáticas a SQL Server ou compartilhamentos de rede.
- Não armazena senhas, tokens ou credenciais.
- Não apresenta garantia de retenção, recuperação de desastre ou disponibilidade.

## Proteções e limitações

- `Read-BackupConfiguration` aceita apenas `environment=LAB`.
- `lab-data/records.json` é a única categoria de armazenamento escrita pela aplicação, dentro do repositório.
- Para persistir metadados, a CLI exige `-Apply -ConfirmEnvironment LAB`; a GUI exige `-EnableLabWrites` e confirmação.
- Não existe bloqueio de arquivo entre múltiplos processos concorrentes: **não use como sistema multiusuário**.
- O adapter SQL limita o destino a uma instância local e ao banco `BackupPortfolioLab`. O operador deve conferir a instância real antes de executar o script SQL.
- CSV usa mitigação simples contra fórmulas; HTML é codificado para impedir injeção de marcação.
- A rotina de varredura de segredos no CI é limitada; revise sempre todo `git diff` antes de publicar.
- O projeto foi criado para apresentação de competências, não homologado para produção.

## Sobre propriedade intelectual

O fato de uma solução ter sido desenvolvida durante um contrato de trabalho não torna automaticamente sua publicação permitida. Este exemplo apresenta apenas habilidades e princípios gerais. Não publique o arquivo de origem, procedimentos internos, documentação, dados, endereços, imagens de produção ou implementações proprietárias sem autorização formal.
