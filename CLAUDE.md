# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado atual

Atualizado em 2026-11-05 (auditoria de consistência). Backend FastAPI + mobile Flutter com os Épicos 1 a 8 implementados (cadastro de peças, armário, looks, preferências, sugestões por regras, look do dia, metadados por IA com Gemma 3 via Ollama, mural de referências com ligação automática). O estado real de cada PBI está em [docs/backlog.md](docs/backlog.md) — a maioria segue com "validação manual no Chrome pendente".

**Ainda não existe:** login real (só `LoginView` placeholder; o app usa `DEV_AUTH_TOKEN` via `--dart-define`), storage em nuvem (as imagens ficam em `backend/uploads/`), tamanho/data de compra/frequência de uso/marca/tecido na peça. O Épico 11 (paginação do armário: `GET /pecas` com `limite`/`deslocamento`/filtros e `X-Total-Count`, armário, gaveta, montar/editar look, escolher par e formulário) está **implementado** (2026-11-06), com validação manual no Chrome pendente; os Épicos 9, 10 e 12 (autenticação real, Supabase Storage, pesquisa do Pinterest) estão **planejados, nenhuma PBI iniciada**. A análise de concorrentes e a auditoria das referências do TCC não são épicos: são só uma lista de tarefas em [docs/checklist-tcc.md](docs/checklist-tcc.md).

**Limitações conhecidas (não corrigidas):**
- `POST /pecas/processar-imagem` e `POST /pecas/upload-original` **não exigem autenticação** (os demais endpoints exigem). Correção prevista na E10.F2.2.
- `DELETE /pecas/{id}` não apaga o arquivo da imagem (E10.F3.2).
- Só `referencias`, `colecoes`, `pastas` (E3.F6.1, incluindo o filtro e o `pasta_id` de `looks`), `GET /pecas` (paginação, E11.F1.1) e as peças paradas (`GET /pecas/paradas`, `POST /pecas/{id}/adiar-lembrete`, E13.F1.1) têm testes de rota; o resto de `pecas`, `looks`, `preferencias` e `sugestoes` não tem testes de integração (E9.F3.1; E1.F1.5 para `processar-imagem`).
- Exclusão de conta e dos dados associados está fora do escopo; precisa ser resolvida antes de disponibilizar o app para terceiros em escala (ver `docs/requisitos.md`).

Atualize este arquivo quando decisões reais divergirem do plano.

Este arquivo é o resumo **operacional** — o que basta saber para trabalhar no código. Os documentos completos, com o racional por trás das decisões, estão em `docs/`: [visão](docs/visao.md) (objetivo, público-alvo, persona, não-objetivos), [arquitetura](docs/arquitetura.md) (diagrama, stack com justificativa, trade-offs) e [requisitos](docs/requisitos.md) (épicos, features, histórias de usuário, ordem de implementação). Quando este arquivo e os documentos completos divergirem sobre o "porquê" de uma decisão, os documentos em `docs/` são a fonte de verdade — atualize ambos juntos quando possível.

## O produto

Guarda-roupa digital com IA. O usuário fotografa suas peças, o app extrai metadados automaticamente e sugere looks montados **exclusivamente com roupas que o usuário já possui**.

Essa restrição é a regra central do produto: **nenhuma feature de IA pode sugerir, recomendar ou exibir uma peça que não esteja cadastrada no armário do usuário.** Vale inclusive para a inspiração por imagem — a foto de referência define estilo, paleta e composição, mas o look devolvido é sempre um mapeamento para itens reais do banco. Se não houver peça equivalente, a resposta é uma lacuna explícita ("nenhum item compatível para a camada X"), nunca uma sugestão genérica.

### Funcionalidades

- **Cadastro** — peça por foto; categorias (camisetas, calças, vestidos, sapatos, acessórios); filtros por cor, tecido, estação, ocasião, marca; campos opcionais de tamanho, data de compra e frequência de uso. *(Visão do produto. Implementado hoje: filtros por cor, estação e ocasião; tecido, marca, tamanho, data de compra e frequência de uso não existem.)*
- **Looks manuais** — criar, favoritar, organizar por ocasião (trabalho, faculdade, festa, academia, viagem), histórico de uso.
- **Recomendação por IA** — considera ocasião, clima e preferências; varia sugestões para puxar peças subutilizadas.
- **Inspiração por imagem** — analisa foto de referência (Pinterest/Instagram/TikTok) e reconstrói o look com o acervo do usuário.
- **Preferências de estilo** — combinações de cor favoritas, gosto por sobreposições, estilos (casual, streetwear, elegante, minimalista, esportivo), peças que evita, nível de criatividade das combinações.

## Stack

| Camada | Tecnologia |
| --- | --- |
| Mobile | Flutter (Dart) — iOS e Android |
| API | FastAPI, Python 3.11+, assíncrono |
| Banco | PostgreSQL + `pgvector` |
| ORM / migrações | SQLAlchemy 2.0 + Alembic |
| Auth | Supabase Auth (JWT validado na API) |
| Visão computacional | `rembg` (remoção de fundo) + Gemma 3 4B via Ollama local (extração de metadados; decisão de 2026-10-23, substituiu Gemini/Llama) |
| Storage | S3 ou Supabase Storage |
| Dev local | Docker Compose (Postgres com `pgvector`) |

## Arquitetura

### Fluxo de cadastro de peça

O caminho crítico do produto, e o que mais exige cuidado ao alterar:

1. App captura/seleciona foto → upload para a API.
2. API envia a imagem para `rembg` → PNG com fundo transparente.
3. Imagem processada vai para o Cloud Storage; a URL pública é persistida.
4. O Gemma 3 4B (via Ollama) analisa a imagem recortada e retorna metadados estruturados (categoria, cores dominantes, tecido aparente, estação, formalidade).
5. Um embedding de estilo da peça é gravado em coluna `vector` do `pgvector`.
6. Usuário revisa e corrige os metadados antes de salvar — **a extração da IA é sempre sugestão, nunca verdade final.**

Os passos 2–5 são lentos e devem rodar fora do request HTTP (background task / fila), com a peça criada em estado `processing` e atualizada quando terminar. O app precisa lidar com esse estado intermediário.

**Estado real hoje (2026-11-05), diferente do plano acima:**
- Passo 1: o app oferece recorte manual da foto antes do envio (E1.F1.6, retroativa).
- Passos 2 e 4 rodam **dentro do request** de `POST /pecas/processar-imagem` (CPU em `run_in_threadpool`), sem estado `processing` nem fila; o app mostra carregamento e, se falhar, oferece seguir sem remoção de fundo (`POST /pecas/upload-original`).
- Passo 3: a imagem vai para o disco local (`backend/uploads/`, servido em `/uploads`), não para o Cloud Storage.
- Passo 4: o Gemma só sugere **categoria, subcategoria, cor principal e tonalidade** (valores das listas fixas); estação, ocasião, tecido e formalidade não são sugeridos.
- Passo 5 (embedding em `vector`) **não existe**.
- Esses dois endpoints não exigem autenticação (limitação conhecida; E10.F2.2).

### Papel do pgvector

`pgvector` é o que torna a inspiração por imagem viável: a foto de referência vira um embedding, e a busca por similaridade acontece **restrita ao `user_id`**. Toda query vetorial precisa filtrar por usuário — sem isso o app sugere roupa de outra pessoa. Guarde os embeddings junto das peças, não em um índice separado, para que o filtro por usuário seja natural.

*Evolução:* esse é o plano original. Em 2026-10-23 a "ligação automática" do mural (E8.F5) passou a usar etiquetas de texto mais a comparação visual do Gemma em vez de embeddings. A extensão `pgvector` é criada na migração `0001`, mas **não existe coluna `vector` nem busca vetorial**; embeddings continuam sendo uma evolução futura, não uma prioridade atual.

### Camadas do backend

Mantenha a orquestração de IA isolada das rotas. Regra prática: um router FastAPI não chama `rembg` nem o modelo de IA diretamente — chama um serviço, que chama os adaptadores. Isso mantém trocáveis o provedor de visão e o de storage, que são as peças mais propensas a mudar.

```
routers/   → HTTP, validação Pydantic, dependência de auth
services/  → regras de negócio (montagem de look, rotação de peças, matching de inspiração)
adapters/  → rembg, Ollama (Gemma 3), storage, clima — cada um atrás de uma interface
models/    → SQLAlchemy 2.0 (mapped_column, tipagem explícita)
schemas/   → Pydantic, separados dos models
```

### Auth

Supabase Auth emite o JWT; a API **valida** o token e deriva o `user_id` dele. O `user_id` nunca vem do corpo ou da query da requisição. Todo dado é escopado por usuário — peças, looks, preferências e histórico.

### Banco em produção

`docker-compose.yml` é só para desenvolvimento local. Em produção, `DATABASE_URL`/`ALEMBIC_DATABASE_URL` apontam para o Postgres gerenciado do **próprio projeto Supabase** (mesmo provedor do Auth — evita espalhar por múltiplos serviços), que já suporta `pgvector` como extensão habilitável. O código não muda entre ambientes, só o valor das variáveis. Usar a connection string **pooled** do Supabase para `DATABASE_URL` (runtime da API) e a **direta** para `ALEMBIC_DATABASE_URL` (migrações, que nem sempre funcionam bem através do pooler). Migrações em produção rodam como passo explícito do deploy, não automaticamente no boot da API.

### Recomendação

O motor de looks é determinístico o suficiente para ser testável: dado um armário fixo, uma ocasião e um conjunto de preferências, o resultado deve ser reproduzível. A variação ("incentivar peças menos usadas") é um parâmetro explícito de entrada — frequência de uso e recência entram na pontuação —, não aleatoriedade solta no meio do código.

As regras aprovadas (cores/ousadia, estrutura do look, filtros, coringas, ordenação, páginas) estão em [docs/regras-sugestoes.md](docs/regras-sugestoes.md) — fonte única; não duplique as regras em outro lugar. Numeração dos épicos: 5 = sugestões sob demanda (motor de regras, sem IA), 6 = look do dia (reaproveita o motor), 7 = cadastro assistido por IA (Gemma 3 via Ollama), 8 = inspiração por imagem (mural de referências e ligação automática a um look com o Gemma — implementados; análise por embeddings e `pgvector`, futuro). Planejados e ainda não iniciados: 9 = autenticação real (Supabase Auth), 10 = imagens no Supabase Storage, 11 = paginação do armário, 12 = pesquisa sobre o Pinterest (só viabilidade e decisão go/no-go), 14 = avatar pixelado (plano futuro, sem PBIs). Implementado em 2026-11-07, validação manual no Chrome pendente: 13 = peças paradas (aviso na abertura do app de peça sem uso há 90 dias, com doar/sugerir look/lembrar depois; coluna `pecas.lembrete_adiado_ate`, migração 0018). Também implementada em 2026-11-07 (validação manual no Chrome pendente): E3.F6 (pastas de looks: tabela `pastas_looks`, `looks.pasta_id`, migração 0019; chips na aba Looks e "Mover para pasta"). Análise de concorrentes e auditoria das referências do TCC não são épicos: ficam em [docs/checklist-tcc.md](docs/checklist-tcc.md). O PostgreSQL continua fora do Supabase; login social não é requisito.

## Estrutura de diretórios

```
backend/
  app/
    core/       config.py (pydantic-settings), security.py (validação JWT Supabase)
    db/         session.py (engine/SessionLocal/Base), models.py
    schemas/    Pydantic, separados dos models
    services/   orquestra os adapters (ex: image_service.py)
    adapters/   rembg_adapter, storage_adapter (local por ora), ollama_adapter (Gemma 3 via Ollama; falha vira sugestão vazia)
    api/v1/     router.py + um módulo por recurso (ex: pecas.py)
  alembic/      migrações — a 0001 já habilita a extensão pgvector
  uploads/      imagens salvas localmente em dev (gitignored, exceto .gitkeep)
mobile/
  lib/
    core/       constants, theme, network (api_client.dart)
    models/     espelham os schemas Pydantic do backend
    services/   um service por recurso, chama o api_client
    views/      home, wardrobe, upload, looks, suggestions, references, preferences (implementados); auth (só `LoginView` placeholder)
docker-compose.yml   Postgres + pgvector para dev local
```

`app/db/models.py` ainda não tem a coluna de embedding (`vector`) — ela entra em migração própria quando a recomendação por IA ou a inspiração por imagem forem implementadas, não antes.

## Comandos

Backend (dentro de `backend/`, com o venv ativado):

```bash
docker compose up -d              # sobe Postgres+pgvector (rodar da raiz do repo)
alembic upgrade head              # aplica migrações
uvicorn app.main:app --reload     # sobe a API em localhost:8000
alembic revision -m "mensagem"    # nova migração manual
```

Testes (dentro de `backend/`, com o venv ativado; desde a E5.F1.1):

```bash
pip install -r requirements-dev.txt                                   # pytest
pytest                                                                # suíte inteira (tests/)
pytest tests/test_sugestoes_cores.py::test_mesma_cor_vale_0           # um teste único
```

Estado dos testes em 2026-11-07: 326 testes coletados (todos passando com o Postgres do `docker compose` no ar) (motor de sugestões, adaptador do Ollama e módulo de inspiração são funções puras, sem banco; `tests/test_referencias.py`, `tests/test_colecoes.py`, `tests/test_pecas_paginacao.py`, `tests/test_pecas_paradas.py` e `tests/test_pastas.py` são testes de rota que usam o Postgres do `docker compose` e são pulados sem ele). Não há testes de rota para o resto de `pecas` (além do `GET` e das peças paradas), `looks`, `preferencias` e `sugestoes`. Não há linter configurado no backend.

Mobile (dentro de `mobile/`):

```bash
flutter pub get
flutter run
flutter test                      # 392 testes em 2026-11-07 (usam serviços falsos, não o backend)
flutter analyze                   # neste PC trava (FormatException) por causa do "Área" no caminho: rodar via `subst W: <raiz do repo>` e `W:\mobile`
```

## MVP

Escopo da primeira versão, em ordem:

1. Cadastro de roupas
2. Organização por categorias
3. Criação manual de looks
4. Sugestões automáticas simples com as peças cadastradas
5. Upload de imagem de inspiração gerando look semelhante
6. Configuração de preferências de estilo

Aprendizado contínuo de estilo, análise de gaps do armário e social ficam para depois do MVP — não implemente por conta própria.

## Convenções

- Português no domínio voltado ao usuário (labels, mensagens de erro, conteúdo). Inglês em código, nomes de tabela e API.
- Nada de chamada de IA sem timeout e fallback: se o modelo de IA falhar, a peça é salva com os metadados que o usuário informar manualmente.
- Migrações sempre via Alembic — nunca alterar o esquema direto no banco, nem confiar em `create_all`.
