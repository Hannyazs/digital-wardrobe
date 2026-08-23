# Guarda-Roupa Virtual

App de guarda-roupa digital com IA: o usuário cadastra as peças que já tem e o app sugere looks montados **somente com essas peças** — por ocasião, clima, preferências de estilo ou a partir de uma foto de inspiração.

Arquitetura, decisões de stack e convenções detalhadas estão em [CLAUDE.md](CLAUDE.md).

## Stack

| Camada | Tecnologia |
| --- | --- |
| Mobile | Flutter (Dart) |
| Backend | FastAPI (Python 3.11+), assíncrono |
| Banco | PostgreSQL + extensão `pgvector` |
| ORM / migrações | SQLAlchemy 2.0 + Alembic |
| Auth | Supabase Auth (JWT) |
| Visão computacional | `rembg` (remoção de fundo) + Gemini Vision (metadados) |

## Estrutura

```
backend/    API FastAPI — cadastro de peças, looks e IA
mobile/     App Flutter (iOS/Android)
docs/       Documentação e protótipos
docker-compose.yml   Postgres + pgvector para desenvolvimento local
```

## Pré-requisitos

Instale antes de começar:

- **Git**
- **Docker Desktop** (com o daemon rodando) — sobe o Postgres, não precisa instalar Postgres na máquina
- **Python 3.11+** — para o backend
- **Flutter SDK** — só necessário se for mexer no app mobile ([guia de instalação](https://docs.flutter.dev/get-started/install))

Não é obrigatório, mas ajuda ter um cliente para visualizar o banco (extensão "PostgreSQL" do VS Code, [DBeaver](https://dbeaver.io/) ou pgAdmin). Sem isso também dá pra inspecionar via `psql` dentro do próprio container (ver seção "Verificando o banco").

## Primeiros passos após clonar

### 1. Clonar e entrar na pasta

```bash
git clone https://github.com/GuilhermeVA/Projeto-Guarda-Roupa-Digital.git
cd Projeto-Guarda-Roupa-Digital
```

### 2. Subir o banco de dados (Postgres + pgvector)

Rodar **na raiz do repositório** (onde está o `docker-compose.yml`):

```bash
docker compose up -d
```

Isso baixa a imagem `pgvector/pgvector:pg16` (só na primeira vez) e sobe um container Postgres em `localhost:5432`, com usuário/senha/banco `guarda_roupa` (definidos no próprio `docker-compose.yml`). Os dados ficam salvos em um volume Docker, então persistem entre reinícios do container.

A extensão **pgvector** já vem instalada nessa imagem, mas precisa ser *habilitada* dentro do banco — isso é feito automaticamente pela primeira migração do Alembic (`CREATE EXTENSION IF NOT EXISTS vector`, em `backend/alembic/versions/0001_initial.py`), executada no próximo passo. Não é preciso configurar nada manualmente.

Para conferir que o container subiu: `docker compose ps`. Para ver os logs: `docker compose logs -f db`.

### 3. Configurar e rodar o backend

```bash
cd backend

# cria e ativa um ambiente virtual
python -m venv .venv
.venv\Scripts\Activate.ps1        # Windows PowerShell
# .venv\Scripts\activate.bat      # Windows CMD
# source .venv/bin/activate       # Mac/Linux

# instala as dependências (rembg/onnxruntime são pesados, pode demorar alguns minutos)
pip install -r requirements.txt

# variáveis de ambiente — o .env.example já vem com os defaults do docker-compose acima
copy .env.example .env            # Windows
# cp .env.example .env            # Mac/Linux

# aplica as migrações (cria as tabelas e habilita o pgvector no banco)
alembic upgrade head

# sobe a API com reload automático
uvicorn app.main:app --reload
```

Se o `Activate.ps1` for bloqueado por política de execução do PowerShell, rode uma vez: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

### 4. Configurar e rodar o app mobile

```bash
cd mobile
flutter pub get
flutter run
```

Por padrão o app aponta para `http://localhost:8000/api/v1` ([lib/core/constants/app_constants.dart](mobile/lib/core/constants/app_constants.dart)). Rodando em emulador Android, troque `localhost` por `10.0.2.2` — o emulador não enxerga `localhost` da máquina host diretamente.

## Verificando que está tudo funcionando

- **API no ar**: `http://localhost:8000/` deve responder `{"status": "ok"}`.
- **Docs interativas**: `http://localhost:8000/docs` (Swagger gerado automaticamente pelo FastAPI).
- **Tabelas criadas**: `docker exec -it guarda-roupa-db psql -U guarda_roupa -d guarda_roupa -c "\dt"` deve listar a tabela `pecas`.
- **Extensão pgvector habilitada**: mesmo comando com `-c "\dx"` deve listar `vector` entre as extensões instaladas.

## Comandos principais (cheat sheet)

| Ação | Comando |
| --- | --- |
| Subir o banco | `docker compose up -d` (raiz do projeto) |
| Parar o banco (mantém dados) | `docker compose down` |
| Apagar o banco e os dados | `docker compose down -v` ⚠️ |
| Acessar o banco via psql | `docker exec -it guarda-roupa-db psql -U guarda_roupa -d guarda_roupa` |
| Aplicar migrações pendentes | `alembic upgrade head` (dentro de `backend/`, venv ativada) |
| Criar uma nova migração | `alembic revision -m "descrição da mudança"` |
| Reverter a última migração | `alembic downgrade -1` |
| Ver histórico de migrações | `alembic history` |
| Rodar a API | `uvicorn app.main:app --reload` |
| Rodar o app Flutter | `flutter run` (dentro de `mobile/`) |
| Atualizar dependências Flutter | `flutter pub get` |

## Variáveis de ambiente (`backend/.env`)

| Variável | Para quê serve |
| --- | --- |
| `DATABASE_URL` | Conexão da aplicação com o Postgres (driver assíncrono `asyncpg`) |
| `ALEMBIC_DATABASE_URL` | Conexão do Alembic com o Postgres (driver síncrono `psycopg2`, exigido pelas migrações) |
| `SUPABASE_JWT_SECRET` | Valida o token JWT emitido pelo Supabase Auth |
| `SUPABASE_URL` / `SUPABASE_SERVICE_KEY` | Credenciais do projeto Supabase (auth/storage) — preencher quando o projeto Supabase for criado |
| `GEMINI_API_KEY` | Chave da API do Gemini Vision — preencher quando a extração de metadados por IA for implementada |
| `UPLOAD_DIR` | Pasta local onde as imagens processadas são salvas (MVP; será trocado por S3/Supabase Storage) |
| `CORS_ORIGINS` | Origens permitidas a chamar a API, separadas por vírgula |

O `.env` **não é versionado** (está no `.gitignore`) — cada pessoa cria o seu localmente a partir do `.env.example`, que sim é versionado com valores padrão de desenvolvimento.

## Solução de problemas comuns

- **`alembic upgrade head` falha com erro de conexão** — confira se `docker compose up -d` rodou com sucesso e se a porta `5432` não está sendo usada por outro Postgres na máquina (`docker compose ps`, `docker compose logs db`).
- **Porta 5432 já em uso** — provavelmente há outro Postgres local rodando. Pare-o ou troque a porta mapeada no `docker-compose.yml` (ex: `"5433:5432"`) e ajuste `DATABASE_URL`/`ALEMBIC_DATABASE_URL` de acordo.
- **Emulador Android não conecta na API** — troque `localhost` por `10.0.2.2` em `app_constants.dart`.
