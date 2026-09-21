# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado atual

Scaffold criado (backend FastAPI + mobile Flutter, ver "Estrutura de diretórios"). Endpoints e telas são esqueletos/placeholders — a lógica de negócio real (regras de recomendação, telas funcionais, chamada real ao Gemini) ainda não foi implementada. Atualize este arquivo quando decisões reais divergirem do plano.

Este arquivo é o resumo **operacional** — o que basta saber para trabalhar no código. Os documentos completos, com o racional por trás das decisões, estão em `docs/`: [visão](docs/visao.md) (objetivo, público-alvo, persona, não-objetivos), [arquitetura](docs/arquitetura.md) (diagrama, stack com justificativa, trade-offs) e [requisitos](docs/requisitos.md) (épicos, features, histórias de usuário, ordem de implementação). Quando este arquivo e os documentos completos divergirem sobre o "porquê" de uma decisão, os documentos em `docs/` são a fonte de verdade — atualize ambos juntos quando possível.

## O produto

Guarda-roupa digital com IA. O usuário fotografa suas peças, o app extrai metadados automaticamente e sugere looks montados **exclusivamente com roupas que o usuário já possui**.

Essa restrição é a regra central do produto: **nenhuma feature de IA pode sugerir, recomendar ou exibir uma peça que não esteja cadastrada no armário do usuário.** Vale inclusive para a inspiração por imagem — a foto de referência define estilo, paleta e composição, mas o look devolvido é sempre um mapeamento para itens reais do banco. Se não houver peça equivalente, a resposta é uma lacuna explícita ("nenhum item compatível para a camada X"), nunca uma sugestão genérica.

### Funcionalidades

- **Cadastro** — peça por foto; categorias (camisetas, calças, vestidos, sapatos, acessórios); filtros por cor, tecido, estação, ocasião, marca; campos opcionais de tamanho, data de compra e frequência de uso.
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
| Visão computacional | `rembg` (remoção de fundo) + Gemini Vision (extração de metadados) |
| Storage | S3 ou Supabase Storage |
| Dev local | Docker Compose (Postgres com `pgvector`) |

## Arquitetura

### Fluxo de cadastro de peça

O caminho crítico do produto, e o que mais exige cuidado ao alterar:

1. App captura/seleciona foto → upload para a API.
2. API envia a imagem para `rembg` → PNG com fundo transparente.
3. Imagem processada vai para o Cloud Storage; a URL pública é persistida.
4. Gemini Vision analisa a imagem recortada e retorna metadados estruturados (categoria, cores dominantes, tecido aparente, estação, formalidade).
5. Um embedding de estilo da peça é gravado em coluna `vector` do `pgvector`.
6. Usuário revisa e corrige os metadados antes de salvar — **a extração da IA é sempre sugestão, nunca verdade final.**

Os passos 2–5 são lentos e devem rodar fora do request HTTP (background task / fila), com a peça criada em estado `processing` e atualizada quando terminar. O app precisa lidar com esse estado intermediário.

### Papel do pgvector

`pgvector` é o que torna a inspiração por imagem viável: a foto de referência vira um embedding, e a busca por similaridade acontece **restrita ao `user_id`**. Toda query vetorial precisa filtrar por usuário — sem isso o app sugere roupa de outra pessoa. Guarde os embeddings junto das peças, não em um índice separado, para que o filtro por usuário seja natural.

### Camadas do backend

Mantenha a orquestração de IA isolada das rotas. Regra prática: um router FastAPI não chama `rembg` nem Gemini diretamente — chama um serviço, que chama os adaptadores. Isso mantém trocáveis o provedor de visão e o de storage, que são as peças mais propensas a mudar.

```
routers/   → HTTP, validação Pydantic, dependência de auth
services/  → regras de negócio (montagem de look, rotação de peças, matching de inspiração)
adapters/  → rembg, Gemini, storage, clima — cada um atrás de uma interface
models/    → SQLAlchemy 2.0 (mapped_column, tipagem explícita)
schemas/   → Pydantic, separados dos models
```

### Auth

Supabase Auth emite o JWT; a API **valida** o token e deriva o `user_id` dele. O `user_id` nunca vem do corpo ou da query da requisição. Todo dado é escopado por usuário — peças, looks, preferências e histórico.

### Banco em produção

`docker-compose.yml` é só para desenvolvimento local. Em produção, `DATABASE_URL`/`ALEMBIC_DATABASE_URL` apontam para o Postgres gerenciado do **próprio projeto Supabase** (mesmo provedor do Auth — evita espalhar por múltiplos serviços), que já suporta `pgvector` como extensão habilitável. O código não muda entre ambientes, só o valor das variáveis. Usar a connection string **pooled** do Supabase para `DATABASE_URL` (runtime da API) e a **direta** para `ALEMBIC_DATABASE_URL` (migrações, que nem sempre funcionam bem através do pooler). Migrações em produção rodam como passo explícito do deploy, não automaticamente no boot da API.

### Recomendação

O motor de looks é determinístico o suficiente para ser testável: dado um armário fixo, uma ocasião e um conjunto de preferências, o resultado deve ser reproduzível. A variação ("incentivar peças menos usadas") é um parâmetro explícito de entrada — frequência de uso e recência entram na pontuação —, não aleatoriedade solta no meio do código.

## Estrutura de diretórios

```
backend/
  app/
    core/       config.py (pydantic-settings), security.py (validação JWT Supabase)
    db/         session.py (engine/SessionLocal/Base), models.py
    schemas/    Pydantic, separados dos models
    services/   orquestra os adapters (ex: image_service.py)
    adapters/   rembg_adapter, storage_adapter (local por ora), gemini_adapter (stub)
    api/v1/     router.py + um módulo por recurso (ex: pecas.py)
  alembic/      migrações — a 0001 já habilita a extensão pgvector
  uploads/      imagens salvas localmente em dev (gitignored, exceto .gitkeep)
mobile/
  lib/
    core/       constants, theme, network (api_client.dart)
    models/     espelham os schemas Pydantic do backend
    services/   um service por recurso, chama o api_client
    views/      auth, wardrobe, upload, looks, preferences — hoje são placeholders
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

Ainda não há suíte de testes nem linter configurados — ao adicionar (pytest, ruff), documentar aqui como rodar um teste único.

Mobile (dentro de `mobile/`):

```bash
flutter pub get
flutter run
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
- Nada de chamada de IA sem timeout e fallback: se o Gemini falhar, a peça é salva com os metadados que o usuário informar manualmente.
- Migrações sempre via Alembic — nunca alterar o esquema direto no banco, nem confiar em `create_all`.
