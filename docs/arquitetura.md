# Documento de Arquitetura — Guarda-Roupa Virtual

Este documento é a referência completa de arquitetura, com o racional por trás das decisões. O [CLAUDE.md](../CLAUDE.md) na raiz do repositório é o resumo operacional — direcionado a quem (ou ao Claude Code) está escrevendo código no dia a dia — e assume tudo que está aqui como pano de fundo. Quando os dois divergirem, este documento é a fonte de verdade sobre o "porquê"; o CLAUDE.md sobre o "como, agora".

## Visão geral

```mermaid
flowchart LR
    Mobile[App Flutter] -->|HTTPS + JWT| API[API FastAPI]
    API --> DB[(Postgres + pgvector)]
    API --> Storage[(Storage de imagens)]
    API --> Rembg[rembg\nremoção de fundo]
    API --> Gemma[Gemma 3 4B via Ollama\nextração de metadados]
    Mobile -->|login| Auth[Supabase Auth]
    API -->|valida JWT| Auth
```

Três peças se comunicam: o **app Flutter** (cliente), a **API FastAPI** (toda a regra de negócio e orquestração de IA vive aqui, nunca no cliente) e o **Postgres com pgvector** (dados relacionais + busca por similaridade de estilo). Autenticação é delegada ao Supabase Auth — a API nunca gerencia senha, só valida o token que o Supabase emitiu.

## Stack e racional de cada escolha

| Camada | Tecnologia | Por que essa e não outra |
| --- | --- | --- |
| Mobile | Flutter (Dart) | Um único código-fonte para iOS e Android, acesso nativo à câmera (essencial pro cadastro de peças). |
| Backend | FastAPI (Python 3.11+) | Assíncrono nativo (importante porque a API orquestra chamadas de IA que são naturalmente I/O-bound), tipagem via Pydantic reduz bugs de contrato entre mobile e API, e é o ecossistema mais direto pra integrar bibliotecas de visão computacional (rembg, clientes de modelos de IA). |
| Banco | PostgreSQL + `pgvector` | Postgres é relacional maduro e já resolve 90% do domínio (peças, looks, preferências). `pgvector` evita introduzir um banco vetorial separado (Pinecone, Weaviate) só para a feature de inspiração por imagem — um banco a menos para operar. |
| ORM / migrações | SQLAlchemy 2.0 + Alembic | Tipagem explícita (`Mapped`/`mapped_column`) e migrações versionadas — mudança de schema nunca é feita à mão no banco. |
| Auth | Supabase Auth | Gerenciar senha, recuperação de conta e sessão é um domínio inteiro por si só; terceirizar isso deixa a equipe focada no produto. Ver "Banco em produção" abaixo — o mesmo projeto Supabase também hospeda o Postgres de produção. |
| Visão computacional | `rembg` + Gemma 3 4B via Ollama | `rembg` remove fundo localmente, sem custo de API por imagem. O Gemma 3 4B, executado localmente pelo Ollama (decisão de 2026-10-23, depois de descartar o Gemini e o Llama — o Llama 4 Scout não cabe na memória do notebook de desenvolvimento), faz o trabalho mais caro (entender a peça e sugerir metadados), mas a sugestão é sempre revisável pelo usuário antes de salvar — nunca é verdade final. |
| Storage de imagens | Local (MVP) → S3/Supabase Storage (produção) | Ver seção "Storage" abaixo. |
| Ambiente local | Docker Compose | Sobe Postgres com `pgvector` idêntico ao que existe em produção, sem exigir instalação nativa do Postgres na máquina de cada dev. |

## Arquitetura em camadas do backend

```
routers/   (app/api/v1/)  → HTTP, validação Pydantic, dependência de auth
services/                 → regras de negócio (orquestra os adapters)
adapters/                 → rembg, Ollama (Gemma 3), storage — cada um atrás de uma interface própria
models/    (app/db/)      → SQLAlchemy 2.0
schemas/                  → Pydantic, separados dos models
```

Regra estrita: **um router nunca chama `rembg` ou o modelo de IA diretamente** — sempre chama um service, que por sua vez chama os adapters. Isso existe porque os adapters são as peças com maior chance de troca (ex: sair do storage local para S3, trocar o modelo de visão por outro) e a troca não deve exigir tocar em nenhuma rota.

## Fluxos principais

### Cadastro de peça

0. No app, o usuário pode recortar a foto antes do envio (recorte manual; E1.F1.6, documentada retroativamente).
1. App envia a foto para `POST /pecas/processar-imagem`.
2. API chama `rembg` para remover o fundo.
3. Imagem processada é salva no storage; a URL é devolvida.
4. O Gemma 3 4B (via Ollama) analisa a imagem e sugere metadados. **Implementado hoje:** categoria, subcategoria, cor principal e tonalidade, sempre com valores das listas fixas; estação, ocasião e demais campos não são sugeridos (o texto original deste passo dizia "categoria, cor, estação, ocasião").
5. Usuário revisa/corrige a sugestão no app e confirma com `POST /pecas` — a sugestão da IA nunca é salva sem revisão humana.

O passo 4 é entregue depois dos demais, de propósito: por decisão de produto, o cadastro nasce puramente manual (Épico 1 do [Documento de Requisitos](requisitos.md)) e só ganha a sugestão automática mais adiante (Épico 7), depois que a base do app já estiver funcionando sem depender de nenhuma IA.

Os passos 2–4 são lentos (chamadas de IA) e devem rodar fora do ciclo de request síncrono conforme o volume de usuários crescer — no MVP local, ainda são síncronos por simplicidade (dentro do request, com o trabalho de CPU em `run_in_threadpool`; não há estado `processing` nem fila).

**Limitação conhecida (2026-11-05):** `POST /pecas/processar-imagem` e `POST /pecas/upload-original` **não exigem autenticação**, ao contrário dos demais endpoints. Correção prevista na PBI E10.F2.2 e ainda não feita.

### Recomendação automática de looks

Motor de regras (não um modelo generativo) que monta looks só com peças do usuário, aplica filtros, restrições (peças e pares evitados), regras de cores e preferências de estilo, e ordena de forma determinística. As regras estão em [regras-sugestoes.md](regras-sugestoes.md).

- **Épico 5 (sob demanda):** `services/sugestoes/` guarda o motor como funções puras (sem banco nem HTTP), testadas com `pytest`; o router `POST /sugestoes` só carrega os dados do usuário e chama o serviço.
- **Épico 6 (look do dia):** reaproveita o mesmo motor, trocando o critério de uso por recência/peças esquecidas a partir de `looks_usos`. Clima real fica para uma etapa posterior.

### Inspiração por imagem

**Estado real (2026-11-05):** o Épico 8 foi implementado sem embeddings. O mural guarda imagens da galeria (sem `rembg`); o Gemma 3 sugere etiquetas de texto das peças visíveis; em "Ligar a um look", o modo automático estreita as peças do armário por etiqueta (`services/inspiracao/candidatos.py`) e o Gemma compara a imagem da referência com as fotos das candidatas (`POST /referencias/{id}/sugestao-de-look`), sempre só com peças do usuário e com as lacunas explícitas. Isso substituiu, para essa parte, o plano com `pgvector` descrito abaixo (decisão de 2026-10-23). O plano original está preservado a seguir como histórico e como evolução futura; **não está implementado**.

1. Usuário envia uma foto de referência externa.
2. Um modelo de visão gera um embedding de estilo dessa imagem.
3. `pgvector` busca, **entre as peças daquele usuário** (filtro por `usuario_id` é obrigatório — nunca uma busca global), as peças com embedding mais próximo.
4. Monta um look combinando essas peças; se não houver equivalente para alguma camada do look de referência, a resposta expõe a lacuna explicitamente em vez de inventar uma sugestão genérica.

## Modelo de dados

| Entidade | Status | Campos principais |
| --- | --- | --- |
| `Peca` | Implementada | `id`, `usuario_id`, `imagem_url`, `categoria`, `subcategoria`, `cor_principal`, `cores_secundarias` (lista), `tonalidade_cor`, `estacoes` (lista), `estilos` (lista), `modelagem`, `ocasioes` (lista), `criado_em`. *(Eram `estacao`, `estilo` e `ocasiao` em texto único até as migrações `0004`, `0012` e `0013`; ver E1.F2.2.)* Não existem tamanho, data de compra, frequência de uso, marca nem tecido |
| `Look` | Implementada | `id`, `usuario_id`, `nome`, `ocasioes` (lista), `favorito`, `arquivado`, `criado_em` + tabela associativa N:N `looks_pecas` com `Peca`. Excluir um look o **arquiva** (os usos continuam no histórico) |
| `LookUso` | Implementada (E3.F4.1) | `id`, `look_id`, `usuario_id`, `usado_em`, `criado_em` — um registro por uso |
| `Referencia`, `Colecao` | Implementadas (Épico 8) | Referência: `imagem_url`, `nota`, `colecao_id`, `look_id`, `etiquetas`; coleção: nome único por usuário (sem diferenciar caixa) |
| `Preferencia` | Implementada (E4.F1.1; evitadas: E4.F4.1) | `usuario_id` (chave única), `estilos`, `sobreposicoes`, `combinacoes_cores` (pares de cores), `criatividade` (1–5), `ocasiao_look_do_dia` (opcional, E6.F1.1; vazio = "Casual"). Peças e pares de peças evitados ficam em tabelas próprias, `pecas_evitadas` e `combinacoes_evitadas` (E4.F4.1), com FK para `pecas` e `ON DELETE CASCADE` |

A coluna de embedding (`vector`, via `pgvector`) entra em `Peca` só quando a feature de inspiração por imagem for implementada — decisão deliberada de não adicionar coluna não utilizada antes da hora.

## Ambiente de desenvolvimento vs produção

| | Desenvolvimento | Produção |
| --- | --- | --- |
| Banco | Postgres local via Docker Compose | Postgres gerenciado do mesmo projeto Supabase usado para Auth |
| Migrações | `alembic upgrade head` manual | Passo explícito do deploy, não automático no boot da API |
| Connection string | Direta (`localhost:5432`) | `DATABASE_URL` usa a conexão *pooled* do Supabase; `ALEMBIC_DATABASE_URL` usa a conexão direta (migrações nem sempre funcionam bem através do pooler) |
| Storage de imagens | Disco local (`backend/uploads/`) | S3 ou Supabase Storage |

O código da aplicação não muda entre os dois ambientes — só o valor das variáveis de ambiente (`DATABASE_URL`, etc.). Ver [README.md](../README.md) para os comandos de setup local.

## Decisões e trade-offs

- **Supabase para Auth *e* banco de produção, não dois provedores separados** — reduz a superfície operacional (um único projeto/dashboard cuidando de autenticação, banco e storage) às custas de um vendor lock-in leve, mitigado pelo fato de ser Postgres puro por baixo (dá pra migrar o banco pra outro provedor sem reescrever nada). *Atualização de 2026-11-05 (planejamento dos Épicos 9 a 11):* a intenção inicial passou a ser usar o Supabase **apenas para Auth e Storage**, mantendo o PostgreSQL atual; migrar o banco para o Supabase não faz parte do planejamento. Consequência registrada: como o banco é separado e os `usuario_id` não têm chave estrangeira para o Auth, excluir um usuário no Supabase não remove seus dados — limitação de privacidade a resolver antes de abrir o app a terceiros em escala.
- **`pgvector` em vez de um banco vetorial dedicado** — suficiente para o volume de dados esperado no MVP; revisitar só se a escala de busca por similaridade justificar um banco especializado.
- **Storage local no MVP** — evita configurar credenciais de nuvem antes de precisar; a interface de `adapters/storage_adapter.py` já isola essa troca para quando for necessária. *Estado atual:* as imagens ficam em `backend/uploads/` e são servidas **publicamente e sem autenticação** em `/uploads`. *Planejado (Épico 10, não iniciado):* bucket privado do Supabase Storage com chave `{usuario_id}/...` e URLs assinadas; a leitura de imagens pelo Gemma (hoje só em `sugerir_para_referencia`) passará a baixar do bucket.
- **Autenticação hoje:** o backend valida um JWT com HS256 e segredo estático (`security.py`); o app usa `DEV_AUTH_TOKEN`. Login real, validação por chaves públicas (JWKS) e sessão estão no Épico 9 (não iniciado).
- **Motor de recomendação baseado em regras, não em modelo generativo** — mais previsível, testável e barato que gerar sugestões via LLM a cada requisição; deixa a "inteligência" mais cara (Gemma 3 via Ollama) reservada para os pontos onde ela é indispensável (extração de metadados, entendimento da imagem de inspiração).
