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
| Visão computacional | `rembg` (remoção de fundo) + Gemma 3 via Ollama local (metadados) |

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

**Rodando no Chrome (`flutter run -d chrome`)**: use sempre a porta fixa `8080`, já liberada em `CORS_ORIGINS` no backend:

```bash
flutter run -d chrome --web-port=8080
```

Sem o `--web-port`, o Flutter sobe em uma porta aleatória a cada execução, que não está na whitelist de CORS da API — a chamada é bloqueada no preflight e o app mostra "Sem conexão com o servidor".

## Verificando que está tudo funcionando

- **API no ar**: `http://localhost:8000/` deve responder `{"status": "ok"}`.
- **Docs interativas**: `http://localhost:8000/docs` (Swagger gerado automaticamente pelo FastAPI).
- **Tabelas criadas**: `docker exec -it guarda-roupa-db psql -U guarda_roupa -d guarda_roupa -c "\dt"` deve listar a tabela `pecas`.
- **Extensão pgvector habilitada**: mesmo comando com `-c "\dx"` deve listar `vector` entre as extensões instaladas.

## Trabalhando com o banco no dia a dia

`alembic upgrade head` não é um passo único do setup inicial — é algo que roda **de novo, sempre que houver uma migração nova**. O Alembic guarda, dentro do próprio banco (tabela `alembic_version`), quais migrações já foram aplicadas, então rodar o comando sem nada pendente não faz nada — é seguro rodar mais de uma vez.

Regra prática pro time:

- **Depois de um `git pull`**: olhe se apareceu algum arquivo novo em `backend/alembic/versions/`. Se sim, rode `alembic upgrade head` antes de subir a API — sem isso, o código pode esperar uma coluna/tabela que ainda não existe no seu banco local.
- **Mudou só lógica** (rota, service, adapter, regra de negócio) — não precisa de migração, só reiniciar a API. Rodando com `--reload` (como no passo 3 acima), isso acontece sozinho a cada salvamento de arquivo `.py`.
- **Mudou um model** (`app/db/models.py`) — sempre gera uma migração nova, nunca altera o banco na mão:
  ```bash
  alembic revision --autogenerate -m "descrição da mudança"
  ```
  Revise o arquivo gerado em `alembic/versions/`, rode `alembic upgrade head` pra aplicar localmente, e comite o model **junto** com o arquivo de migração — sem os dois juntos, quem puxar seu código fica com o model sem a tabela correspondente.

## Login e endpoints autenticados

Quase todos os endpoints exigem um JWT válido (ver [CLAUDE.md](CLAUDE.md), seção Auth) — o `usuario_id` sempre vem do token, nunca do corpo da requisição. A API aceita dois tipos de token (E9.F1.1): o **token real do Supabase** (ES256, validado pelas chaves públicas do projeto em `SUPABASE_URL`) e o **token de teste** abaixo (HS256, só enquanto `SUPABASE_JWT_SECRET` estiver preenchido; em produção ele fica vazio). `POST /pecas/processar-imagem` e `POST /pecas/upload-original` também exigem o token desde a E1.F1.7 (2026-11-08): validam o formato real (JPEG, PNG ou WebP), recusam arquivo acima de 10 MB e gravam com a extensão do formato detectado. **Limitação que continua:** as imagens ficam em `backend/uploads/`, servidas em `/uploads` sem autenticação; a migração para o Supabase Storage, com armazenamento privado e isolamento dos arquivos, é o Épico 10, **planejado para versão futura e fora da V1** (ver [docs/backlog.md](docs/backlog.md)).

### Login no app (E9.F2.1–E9.F2.3)

O app abre na tela de login quando não há sessão; cada conta vê só os próprios dados. Cadastro, login e "Esqueci minha senha" usam o Supabase Auth do projeto de desenvolvimento, configurado em [mobile/lib/core/auth/auth_config.dart](mobile/lib/core/auth/auth_config.dart). A URL e a chave **pública** (publishable) já vêm como padrão; para outro projeto, use `--dart-define=SUPABASE_URL=...` e `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`. A chave secreta do Supabase nunca vai no app.

```bash
cd mobile
flutter run -d chrome --web-port=8080
```

O app manda o token da sessão em toda chamada à API, renova quando vence e, se não der para renovar, volta ao login com o aviso "Sua sessão expirou" (E9.F2.2). O backend precisa estar com `SUPABASE_URL` no `.env` (reinicie o `uvicorn` depois de mudar o `.env`).

No Supabase (Authentication → URL Configuration), deixe `http://localhost:8080` como **Site URL** e na lista de **Redirect URLs**: é para lá que voltam os links de e-mail. A confirmação de e-mail está **desligada** no projeto de desenvolvimento; se for ligada, o app mostra "Confirme seu e-mail" depois do cadastro.

**Recuperação de senha (E9.F2.3):** "Esqueci minha senha" na tela de login envia um link por e-mail; ao abrir o link, o app pede a senha nova. Limitações:
- Abra o link **no mesmo navegador** em que pediu a redefinição (o Supabase usa o fluxo PKCE, que guarda um código no navegador do pedido). Em outro navegador, o app mostra o aviso e oferece pedir outro link.
- Sem SMTP próprio configurado no Supabase, o envio padrão de e-mail tem limite baixo por hora e, em projetos novos, só entrega para e-mails da equipe do projeto. Para testar com qualquer e-mail, configure um SMTP em Authentication → Emails.
- No celular (Android/iOS) ainda não há link profundo configurado: o link abre o "Site URL" no navegador. Só o Chrome foi validado.

### Token de teste (só desenvolvimento, sem o app)

Para chamar a API direto (Swagger, curl, testes manuais), gere um token de teste localmente, assinado com o mesmo `SUPABASE_JWT_SECRET` do seu `.env`:

```bash
cd backend
python scripts/gerar_token_teste.py
```

Use o token impresso no header `Authorization: Bearer <token>`, ou cole ele no botão **"Authorize"** do Swagger (`/docs`). Por padrão vale 30 dias e usa um `usuario_id` aleatório — dá pra fixar um usuário específico com `--usuario-id <uuid>` (útil pra sempre testar como "o mesmo usuário") ou ajustar a validade com `--dias`.

É só uma ferramenta de desenvolvimento: o app não usa mais esse token (desde a E9.F2.2 ele envia o token do login real).

## Visualizando o banco (opcional)

Não é obrigatório, mas ajuda ter uma interface visual em vez de só `psql`. Opção recomendada: **pgAdmin** ([pgadmin.org/download](https://www.pgadmin.org/download/)) — cliente oficial do Postgres, gratuito.

Depois de instalado: botão direito em "Servers" → **Register → Server**, e na aba **Connection** use os dados do `docker-compose.yml`:

| Campo | Valor |
| --- | --- |
| Host name/address | `localhost` |
| Port | `5432` |
| Maintenance database | `guarda_roupa` |
| Username | `guarda_roupa` |
| Password | `guarda_roupa` |

Alternativas equivalentes: [DBeaver](https://dbeaver.io/) (gratuito, suporta vários bancos) ou a extensão "PostgreSQL"/"SQLTools" do VS Code, se preferir não sair do editor.

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
| Rodar os testes do backend | `pytest` (dentro de `backend/`, venv ativada; os testes de rota, incluindo o de isolamento entre usuários, precisam do Postgres no ar e são pulados sem ele) |
| Rodar os testes do app | `flutter test` (dentro de `mobile/`) |

## Variáveis de ambiente (`backend/.env`)

| Variável | Para quê serve |
| --- | --- |
| `AMBIENTE` | `desenvolvimento` (padrão) ou `producao`. Em produção a API não sobe com configuração de desenvolvimento (ver "Desenvolvimento x produção" abaixo) |
| `DATABASE_URL` | Conexão da aplicação com o Postgres (driver assíncrono `asyncpg`) |
| `ALEMBIC_DATABASE_URL` | Conexão do Alembic com o Postgres (driver síncrono `psycopg2`, exigido pelas migrações) |
| `SUPABASE_URL` | URL da API do projeto Supabase (`https://<ref>.supabase.co`, não a do painel). A API busca as chaves públicas em `<SUPABASE_URL>/auth/v1/.well-known/jwks.json` para validar o login real |
| `SUPABASE_JWT_SECRET` | **Só desenvolvimento:** segredo dos tokens de teste (`scripts/gerar_token_teste.py`). Vazio desliga os tokens de teste — é o valor de produção |
| `SUPABASE_SERVICE_KEY` | Chave de serviço do Supabase (storage, Épico 10). Só no backend, nunca no app |
| `OLLAMA_URL` / `OLLAMA_MODELO` / `OLLAMA_TIMEOUT_S` | Ollama local (padrão `http://localhost:11434`, `gemma3:4b`, 30 s) — sugestão de metadados da peça; sem ele a sugestão vem vazia |
| `UPLOAD_DIR` | Pasta local onde as imagens são salvas e de onde `/uploads` as serve, **sem autenticação** (MVP; a troca por bucket privado do Supabase Storage está planejada no Épico 10, versão futura fora da V1, não iniciado) |
| `CORS_ORIGINS` | Origens permitidas a chamar a API, separadas por vírgula |

O `.env` **não é versionado** (está no `.gitignore`) — cada pessoa cria o seu localmente a partir do `.env.example`, que sim é versionado com valores padrão de desenvolvimento.

### Desenvolvimento x produção (E9.F3.2)

| | Desenvolvimento | Produção |
| --- | --- | --- |
| `AMBIENTE` | `desenvolvimento` | `producao` |
| `SUPABASE_URL` | URL do projeto de desenvolvimento | URL `https://` do projeto de produção (obrigatória) |
| `SUPABASE_JWT_SECRET` | qualquer valor (habilita o `gerar_token_teste.py`) | **vazio** (tokens de teste desligados) |
| `CORS_ORIGINS` | `http://localhost:8080` | só as URLs `https://` do app publicado; sem `*`, sem `localhost` |
| `SUPABASE_SERVICE_KEY` | vazio por enquanto | só no servidor da API (variável de ambiente do provedor), nunca no app nem no repositório |
| `scripts/gerar_token_teste.py` | disponível | recusa rodar |

Com `AMBIENTE=producao`, a API **falha ao subir** e lista o que está errado se alguma linha da coluna "Produção" não for cumprida. Assim, um deploy esquecido com a configuração de desenvolvimento não chega ao ar.

**Checklist antes de publicar:**
- [ ] Variáveis de produção definidas no provedor (não em arquivo versionado) e `AMBIENTE=producao`.
- [ ] No Supabase de produção: "Site URL" e "Redirect URLs" com a URL `https://` do app (não `localhost`).
- [ ] `--dart-define=SUPABASE_URL=...` e `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` do projeto de produção no build do app; a chave **secreta** nunca vai no app.
- [ ] `alembic upgrade head` rodado como passo do deploy.
- [ ] Limitações ainda abertas: `/uploads` público e sem autenticação (Épico 10, versão futura fora da V1: E10.F2.2 e E10.F4.2) e exclusão de conta fora do escopo. (Os dois endpoints de imagem já exigem login desde a E1.F1.7.)

O app manda o token no cabeçalho `Authorization` (não usa cookie), por isso o CORS não libera credenciais de navegador (`allow_credentials=False`).

## Solução de problemas comuns

- **`alembic upgrade head` falha com erro de conexão** — confira se `docker compose up -d` rodou com sucesso e se a porta `5432` não está sendo usada por outro Postgres na máquina (`docker compose ps`, `docker compose logs db`).
- **Porta 5432 já em uso** — provavelmente há outro Postgres local rodando. Pare-o ou troque a porta mapeada no `docker-compose.yml` (ex: `"5433:5432"`) e ajuste `DATABASE_URL`/`ALEMBIC_DATABASE_URL` de acordo.
- **Emulador Android não conecta na API** — troque `localhost` por `10.0.2.2` em `app_constants.dart`.
- **Erro de CORS no Chrome (`Access-Control-Allow-Origin`)** — rode `flutter run -d chrome --web-port=8080` em vez de `flutter run` puro. Sem o `--web-port`, cada execução usa uma porta aleatória que não está em `CORS_ORIGINS`.
- **Docker Desktop diz "Virtualization support not detected" mesmo com a BIOS habilitada** — no Windows, verifique também se o hypervisor não foi desligado por software (comum depois de configurar algum jogo com anti-cheat, que às vezes pede pra desabilitar isso). Abra um PowerShell **como Administrador** e rode `bcdedit /enum {current}`, procurando a linha `hypervisorlaunchtype`. Se estiver `Off`, corrija com `bcdedit /set hypervisorlaunchtype auto` e reinicie o PC. (Pra jogar de novo depois, o mesmo comando com `off` no lugar de `auto`.)
