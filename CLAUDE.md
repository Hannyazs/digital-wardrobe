# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado atual

Atualizado em 2026-11-05 (auditoria de consistência). Backend FastAPI + mobile Flutter com os Épicos 1 a 8 implementados (cadastro de peças, armário, looks, preferências, sugestões por regras, look do dia, metadados por IA com Gemma 3 via Ollama, mural de referências com ligação automática). O estado real de cada PBI está em [docs/backlog.md](docs/backlog.md) — o status "concluída" se apoia nos testes automatizados e nas verificações registradas em cada PBI; a V1 não exige validação manual individual de cada uma, e as pendências técnicas reais ficam registradas nas próprias PBIs.

**Ainda não existe:** link profundo no celular para a recuperação de senha, storage em nuvem (as imagens ficam em `backend/uploads/`), tamanho/data de compra/frequência de uso/marca/tecido na peça. O Épico 11 (paginação do armário: `GET /pecas` com `limite`/`deslocamento`/filtros e `X-Total-Count`, armário, gaveta, montar/editar look, escolher par e formulário) está **implementado** (2026-11-06); o Épico 9 (autenticação real) está **concluído** (2026-11-08): 7 PBIs concluídas e 1 não aplicável (E9.F1.3); login, sessão e recuperação de senha validados no Chrome, isolamento e configuração verificados por testes automatizados: projeto Supabase `https://vxzadsokzxwqalqvnepd.supabase.co` (tokens ES256), backend valida o token real pelo JWKS (E9.F1.1; `iat` não conferido, tolerância de 30 s), dados antigos descartáveis (E9.F1.2; E9.F1.3 não aplicável), login/cadastro/logout (E9.F2.1), token real nas chamadas com renovação e "sessão expirada" (E9.F2.2, `core/network/auth_interceptor.dart`), recuperação de senha só no Chrome (E9.F2.3), isolamento entre usuários testado em todas as rotas com dados (E9.F3.1, `tests/test_isolamento.py`) e trava de configuração de produção (E9.F3.2, `AMBIENTE=producao`). Confirmação de e-mail desligada; o app não usa mais `DEV_AUTH_TOKEN`. A raiz do app (`AppComConta`, `main.dart`) recria o `ProviderScope` a cada troca de usuário: não é preciso invalidar providers no logout. O Épico 10 (Supabase Storage) está **planejado para versão futura, fora da V1** (decisão de 2026-11-08), com nenhuma PBI iniciada; o Épico 12 (pesquisa do Pinterest) está planejado, nenhuma PBI iniciada. A análise de concorrentes e a auditoria das referências do TCC não são épicos: são só uma lista de tarefas em [docs/checklist-tcc.md](docs/checklist-tcc.md).

**Limitações conhecidas (não corrigidas):**
- ~~`POST /pecas/processar-imagem` e `POST /pecas/upload-original` não exigem autenticação~~ — **corrigido na E1.F1.7 (2026-11-08)**: as duas rotas exigem token (401 sem ele), validam o formato real pelo conteúdo (JPEG, PNG ou WebP; senão 422), recusam arquivo acima de 10 MB e `upload-original` grava com a extensão do formato detectado (`app/services/validacao_imagem.py`). **Continua aberto:** as imagens já salvas ficam em `backend/uploads/`, servidas em `/uploads` **sem autenticação** (acessíveis a quem tiver o endereço); bucket privado, isolamento dos arquivos e fim do acesso público são o Épico 10, **fora da V1**.
- `DELETE /pecas/{id}` não apaga o arquivo da imagem (E10.F3.2).
- Todas as rotas com dados de usuário têm teste de isolamento entre dois usuários (E9.F3.1), mas o comportamento funcional de `pecas` (criar/editar/excluir), `looks`, `preferencias` e `sugestoes` só é testado no nível de serviço. `processar-imagem` e `upload-original` têm testes de rota com `rembg` e Ollama simulados, incluindo autenticação, tipo real, limite de 10 MB e extensão segura (E1.F1.5 e E1.F1.7, `tests/test_processamento_imagem.py`, 18 testes).
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
- Esses dois endpoints exigem autenticação e validam o arquivo (tipo real, 10 MB, extensão segura) desde a E1.F1.7 (2026-11-08).

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

Supabase Auth emite o JWT; a API **valida** o token e deriva o `user_id` dele. Desde a E9.F1.1, tokens ES256 são validados pelas chaves públicas do projeto (`<SUPABASE_URL>/auth/v1/.well-known/jwks.json`, conferindo `iss`/`aud`/`exp`); tokens HS256 de `scripts/gerar_token_teste.py` só são aceitos com `SUPABASE_JWT_SECRET` preenchido (desenvolvimento; vazio em produção). Com `AMBIENTE=producao` a API não sobe se o segredo estiver preenchido ou o CORS tiver `*`/http/localhost (E9.F3.2, `core/config.py`). Toda rota nova com dados de usuário entra em `tests/test_isolamento.py`. O `user_id` nunca vem do corpo ou da query da requisição. Todo dado é escopado por usuário — peças, looks, preferências e histórico.

### Banco em produção

`docker-compose.yml` é só para desenvolvimento local. Em produção, `DATABASE_URL`/`ALEMBIC_DATABASE_URL` apontam para o Postgres gerenciado do **próprio projeto Supabase** (mesmo provedor do Auth — evita espalhar por múltiplos serviços), que já suporta `pgvector` como extensão habilitável. O código não muda entre ambientes, só o valor das variáveis. Usar a connection string **pooled** do Supabase para `DATABASE_URL` (runtime da API) e a **direta** para `ALEMBIC_DATABASE_URL` (migrações, que nem sempre funcionam bem através do pooler). Migrações em produção rodam como passo explícito do deploy, não automaticamente no boot da API.

### Recomendação

O motor de looks é determinístico o suficiente para ser testável: dado um armário fixo, uma ocasião e um conjunto de preferências, o resultado deve ser reproduzível. A variação ("incentivar peças menos usadas") é um parâmetro explícito de entrada — frequência de uso e recência entram na pontuação —, não aleatoriedade solta no meio do código.

As regras aprovadas (cores/ousadia, estrutura do look, filtros, coringas, ordenação, páginas) estão em [docs/regras-sugestoes.md](docs/regras-sugestoes.md) — fonte única; não duplique as regras em outro lugar. Numeração dos épicos: 5 = sugestões sob demanda (motor de regras, sem IA), 6 = look do dia (reaproveita o motor), 7 = cadastro assistido por IA (Gemma 3 via Ollama), 8 = inspiração por imagem (mural de referências e ligação automática a um look com o Gemma — implementados; análise por embeddings e `pgvector`, futuro). 9 = autenticação real (Supabase Auth, concluído em 2026-11-08); 11 = paginação do armário (implementado). Planejados e ainda não iniciados: 10 = imagens no Supabase Storage (versão futura, fora da V1), 12 = pesquisa sobre o Pinterest (só viabilidade e decisão go/no-go), 14 = avatar pixelado (plano futuro, sem PBIs). Implementado em 2026-11-07: 13 = peças paradas (aviso na abertura do app de peça sem uso há 90 dias, com doar/sugerir look/lembrar depois; coluna `pecas.lembrete_adiado_ate`, migração 0018). Também implementada em 2026-11-07: E3.F6 (pastas de looks: tabela `pastas_looks`, `looks.pasta_id`, migração 0019; chips na aba Looks e "Mover para pasta"). Análise de concorrentes e auditoria das referências do TCC não são épicos: ficam em [docs/checklist-tcc.md](docs/checklist-tcc.md). O PostgreSQL continua fora do Supabase; login social não é requisito.

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
    core/auth/  AuthService (Supabase), estado da conta; core/network/auth_interceptor.dart (token, renovação)
    views/      auth (login/cadastro, esqueci a senha, nova senha), home, wardrobe, upload, looks, suggestions, references, preferences
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

Estado dos testes em 2026-11-08: 437 testes coletados (todos passando com o Postgres do `docker compose` no ar; inclui `tests/test_security.py` e `tests/test_config.py`, sem rede nem banco, `tests/test_processamento_imagem.py`, rotas de imagem com `rembg`/Ollama simulados e sem banco, e `tests/test_isolamento.py`, isolamento entre usuários contra o Postgres) (motor de sugestões, adaptador do Ollama e módulo de inspiração são funções puras, sem banco; `tests/test_referencias.py`, `tests/test_colecoes.py`, `tests/test_pecas_paginacao.py`, `tests/test_pecas_paradas.py` e `tests/test_pastas.py` são testes de rota que usam o Postgres do `docker compose` e são pulados sem ele). Não há linter configurado no backend.

Mobile (dentro de `mobile/`):

```bash
flutter pub get
flutter run
flutter test                      # 428 testes em 2026-11-07 (usam serviços falsos, não o backend nem o Supabase)
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
