---
name: criar-pbi
description: Cria um PBI (Product Backlog Item) detalhado para este projeto, no formato e na estrutura de pastas já estabelecidos em docs/PBIs/. Use quando o usuário pedir para detalhar, quebrar ou criar uma PBI/user story/item de backlog para uma feature do docs/requisitos.md — inclui perguntar o número/pasta corretos quando não estiverem claros.
---

# Criar PBI

Gera um PBI detalhado seguindo exatamente o padrão já usado no projeto — o exemplo canônico e sempre atualizado é `docs/PBIs/E1-F1-adicionar-foto/E1.F1.1-captura-e-selecao-de-foto.md`. Leia esse arquivo antes de criar um novo, em vez de confiar só na descrição das seções abaixo — se o padrão real evoluir, esse arquivo é a fonte de verdade, não este skill.

## Antes de criar: identificar épico, feature e número

Todo PBI usa o ID `E<épico>.F<feature>.<número>` (ex: `E1.F1.3`). Para descobrir isso:

1. Se o usuário já deu o ID completo (ex: "crie a PBI E2.F1.2"), use-o diretamente.
2. Se o usuário descreveu a feature/PBI em texto livre, cheque `docs/requisitos.md` para achar o épico e a feature correspondentes, e `docs/backlog.md` para ver se essa feature já tem PBIs listados (com números) — reaproveite a numeração existente.
3. **Pergunte ao usuário** (não adivinhe) quando:
   - Não estiver claro a qual épico/feature a PBI pertence.
   - A feature ainda não tem nenhuma PBI listada em `docs/backlog.md` (não há como saber se essa seria a PBI 1, 2, etc. sem antes quebrar a feature inteira — ofereça fazer a quebra completa, como foi feito para o Épico 1 Feature 1, em vez de inventar um número isolado).
   - Houver mais de uma feature/épico plausível pro pedido do usuário.

## Passo a passo

1. **Confirme que existe uma entrada resumida em `docs/backlog.md`** para essa PBI (`### E<x>.F<y>.<n> — <título>` com Descrição/Critérios de aceite/Status/Estimativa/Dependências). Se não existir, crie-a primeiro, seguindo o mesmo formato das PBIs vizinhas naquele arquivo — não pule direto para o arquivo detalhado sem isso, ele é o que mantém a visão geral da feature coerente.

2. **Determine a pasta**: `docs/PBIs/E<épico>-F<feature>-<slug-curto-da-feature>/`. Se a pasta já existe pra essa feature (outras PBIs dela já foram detalhadas), reuse-a. Se não existe, crie-a — o slug é o nome da feature (de `docs/requisitos.md`) resumido em 2-4 palavras, minúsculo, sem acento, com hífen (ex: "Adicionar peça por foto, com remoção automática de fundo" → `adicionar-foto`).

3. **Nomeie o arquivo**: `E<épico>.F<feature>.<número>-<slug-curto-do-título-da-pbi>.md` (ex: `E1.F1.1-captura-e-selecao-de-foto.md`).

4. **Escreva o conteúdo** seguindo a estrutura abaixo, na mesma ordem, com o mesmo nível de detalhe do exemplo canônico. Não deixe seções genéricas ou de preenchimento — cada seção precisa refletir decisões reais sobre a PBI específica, ancoradas no código/documentos existentes do projeto (não invente tecnologia ou arquivo que não existe; se for algo novo, diga que é novo).

5. **Atualize `docs/backlog.md`**: adicione, logo abaixo do título `### E<x>.F<y>.<n> — ...`, a linha de link pro arquivo detalhado, no mesmo formato usado para E1.F1.1:
   ```markdown
   Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E<x>-F<y>-<slug>/E<x>.F<y>.<n>-<slug>.md](PBIs/E<x>-F<y>-<slug>/E<x>.F<y>.<n>-<slug>.md).
   ```

## Estrutura do arquivo detalhado (seções, nesta ordem)

1. `# PBI E<x>.F<y>.<n> — <título>`
2. Tabela de metadados: Épico, Feature, Estimativa, Status, Dependências, Arquivo principal.
3. Linha de link de volta para `../../backlog.md` e `../../requisitos.md` (ajuste a profundidade relativa se a estrutura de pastas mudar).
4. `## Contexto` — por que essa PBI importa, ligada à persona/visão do produto quando fizer sentido (ver `docs/visao.md`).
5. `## Descrição` — o que exatamente será entregue, e onde essa PBI **para** (o que ela explicitamente não faz, remetendo à próxima PBI que continua o fluxo).
6. `## Escopo` — "Dentro do escopo" e "Fora do escopo" como duas listas. Verifique ativamente se o escopo não se sobrepõe com PBIs vizinhas já existentes (isso já aconteceu neste projeto entre E1.F1.2 e E1.F1.4 — releia PBIs relacionadas antes de finalizar esta seção).
7. `## Como será feito` — decisões técnicas concretas: abordagem, gerenciamento de estado, arquivos que serão criados/alterados (caminhos reais do repositório), e qualquer armadilha específica da stack do projeto (ex: `dart:io File` não funciona no Flutter Web, `pydantic` vs SQLAlchemy, etc. — cheque `CLAUDE.md` e `docs/arquitetura.md` para as convenções já registradas antes de propor algo nesta seção).
8. `## Critérios de aceite` — formato "Dado / Quando / Então".
9. `## Definição de pronto` — checklist (`- [ ]`), distinto dos critérios de aceite (é sobre qualidade de engenharia — lint, dependências, testes manuais —, não sobre o comportamento da feature em si).
10. `## Riscos e pontos de atenção`.
11. `## Como testar` — passos concretos e executáveis, considerando as limitações reais do ambiente de desenvolvimento atual (ex: hoje só o Chrome está validado como plataforma Flutter funcional neste projeto — verifique se isso ainda é verdade antes de repetir a afirmação).

## Depois de criar

Aponte para o arquivo criado e resuma em 3-5 linhas as decisões mais importantes que ele tomou (não repita o arquivo inteiro na resposta) — igual ao que foi feito ao entregar `E1.F1.1-captura-e-selecao-de-foto.md`.
