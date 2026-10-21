# Guarda-Roupa Virtual: aplicativo móvel com inteligência artificial para organização de roupas e montagem de looks

**Documento da Versão 1 (V1) do projeto**

Autor(a): [SEU NOME]
Curso: [CURSO] — [INSTITUIÇÃO]
Orientador(a): [NOME DO ORIENTADOR(A)]
Data: outubro de 2026

---

## Resumo

Este documento descreve a primeira versão (V1) do Guarda-Roupa Virtual, um aplicativo móvel que ajuda o usuário a organizar as roupas que já possui e a montar looks usando somente essas peças. O usuário fotografa cada peça, o sistema remove o fundo da imagem e o usuário informa categoria, cor, estação e ocasião. Com as peças cadastradas, é possível consultá-las por categoria, filtrá-las e combiná-las em looks salvos. O sistema foi construído com Flutter (aplicativo), FastAPI (servidor) e PostgreSQL (banco de dados). A V1 entrega a base do produto sem depender de inteligência artificial para sugerir combinações. Os recursos de IA (sugestão automática de metadados, recomendação de looks e inspiração por imagem) estão planejados para as próximas versões. Este documento apresenta o problema, os objetivos, os requisitos, a arquitetura, o que foi implementado, as limitações atuais e os próximos passos.

**Palavras-chave:** guarda-roupa digital; aplicativo móvel; Flutter; FastAPI; remoção de fundo; recomendação de looks.

---

## 1 Introdução

### 1.1 Contexto e problema

Muitas pessoas usam apenas uma pequena parte das roupas que possuem. Isso acontece menos por falta de peças e mais por falta de visibilidade sobre o que se tem e de tempo para pensar em combinações. O resultado é dinheiro parado em roupas pouco usadas e tempo perdido, todos os dias, na decisão de "o que vestir".

### 1.2 Proposta

O Guarda-Roupa Virtual é um armário digital. O usuário cadastra suas peças por foto e o aplicativo ajuda a organizá-las e a combiná-las. A regra central do produto é que **o sistema nunca sugere nem exibe uma peça que o usuário não tenha cadastrado**. O aplicativo não recomenda compras, apenas ajuda a aproveitar melhor o que a pessoa já tem.

### 1.3 Objetivos

**Objetivo geral:** desenvolver um aplicativo móvel que permita cadastrar, organizar e combinar as roupas do usuário, usando apenas peças que ele já possui.

**Objetivos específicos:**

- permitir o cadastro de peças por foto, com remoção automática do fundo da imagem;
- permitir o registro de informações da peça (categoria, cor, estação e ocasião);
- exibir o armário organizado por categorias e com filtros;
- permitir a montagem e o salvamento manual de looks;
- construir uma base técnica que comporte, nas próximas versões, recursos de inteligência artificial.

### 1.4 Justificativa

O problema é comum a pessoas de qualquer perfil e não exige conhecimento de moda para ser percebido. A solução também permite aplicar, em um projeto só, conteúdos centrais da formação: desenvolvimento móvel, construção de APIs, modelagem de banco de dados e uso de visão computacional.

### 1.5 Público-alvo

Público geral. Como referência para as decisões de projeto, foi criada a persona *Marina*, 29 anos, que trabalha em horário comercial, tem pouco tempo e sente que "sempre usa as mesmas cinco peças". Ela valoriza rapidez e praticidade e não quer comprar roupas novas apenas para ter o que vestir.

---

## 2 Fundamentação tecnológica

Esta seção resume as tecnologias usadas e o motivo de cada escolha.

| Camada | Tecnologia | Motivo da escolha |
| --- | --- | --- |
| Aplicativo | Flutter (Dart) | Um único código para Android e iOS, com acesso à câmera do celular. |
| Servidor (API) | FastAPI (Python) | Rápido, assíncrono e com validação automática de dados; integra-se bem com bibliotecas de visão computacional. |
| Banco de dados | PostgreSQL com extensão `pgvector` | Banco relacional consolidado; o `pgvector` permitirá, no futuro, buscas por similaridade de imagens sem um segundo banco. |
| Acesso ao banco | SQLAlchemy 2.0 e Alembic | Modelagem tipada e migrações versionadas, sem alterar o banco "na mão". |
| Remoção de fundo | `rembg` | Roda localmente, sem custo por imagem. |
| Extração de metadados (planejada) | Gemini Vision | Modelo de visão capaz de descrever a peça na foto. Ainda não integrado na V1. |
| Autenticação (planejada) | Supabase Auth | Evita construir do zero o controle de senhas e sessões. Na V1 é usado um token de teste. |
| Ambiente local | Docker Compose | Sobe o banco igual para qualquer pessoa que clone o projeto. |

---

## 3 Metodologia

O projeto foi conduzido de forma incremental, com ciclos curtos inspirados em métodos ágeis:

1. **Documentação inicial:** definição de visão, requisitos e arquitetura (arquivos `visao.md`, `requisitos.md` e `arquitetura.md`).
2. **Divisão em itens pequenos:** cada funcionalidade foi quebrada em PBIs (*Product Backlog Items*), com descrição, critérios de aceite e dependências (arquivo `backlog.md`). A numeração segue o padrão `E<épico>.F<feature>.<item>`.
3. **Implementação e verificação:** cada PBI foi implementada e verificada com análise estática (`dart analyze`), testes automatizados (`flutter test`) e, quando possível, execução real da API.
4. **Registro honesto de status:** cada PBI registra o que foi realmente verificado e o que ainda está pendente, diferenciando "implementado" de "validado".

O desenvolvimento começou em agosto de 2026 e esta V1 reflete o estado do projeto em outubro de 2026. O código é versionado em Git.

---

## 4 Requisitos

Os requisitos completos estão em `docs/requisitos.md`. Aqui estão os principais, divididos em épicos. Os três primeiros formam a base do produto e fazem parte da V1.

### 4.1 Requisitos funcionais

| Épico | Descrição | Na V1 |
| --- | --- | --- |
| 1 — Cadastro de roupas | Adicionar peça por foto com remoção de fundo; preencher metadados; editar e excluir. | Implementado (exceto campos opcionais de tamanho, data de compra e frequência de uso) |
| 2 — Organização | Listar o armário por categoria; filtrar por cor, estação e ocasião. | Implementado (filtros por tecido e marca ficaram de fora) |
| 3 — Looks manuais | Montar e salvar looks; listar looks salvos. | Parcial: montar e listar implementados; favoritar, organizar por ocasião e histórico de uso não |
| 4 — Preferências de estilo | Cores favoritas, estilos preferidos, peças que evita. | Não iniciado |
| 5 — Cadastro assistido por IA | Sugestão automática de categoria, cor etc. a partir da foto. | Não iniciado |
| 6 — Sugestão automática de looks | Looks sugeridos por ocasião, clima e preferências. | Não iniciado |
| 7 — Inspiração por imagem | Recriar uma foto de referência com peças do próprio armário. | Não iniciado |

### 4.2 Requisitos não funcionais

- **Privacidade:** todo dado pertence a um usuário. O identificador do usuário vem do token de autenticação e nunca do corpo da requisição, e um usuário não acessa dados de outro.
- **Idioma:** interface em português; código e nomes técnicos em inglês.
- **Resiliência:** uma falha em serviço de IA não pode derrubar o fluxo do usuário. Se a remoção de fundo falhar, o usuário pode seguir com a foto original.
- **Disponibilidade:** sem exigência formal nesta fase de validação.

### 4.3 Fora do escopo

Recomendação de compras, rede social, múltiplos idiomas, aprendizado de estilo avançado e sincronização em tempo real entre dispositivos.

---

## 5 Arquitetura do sistema

O sistema tem três partes principais: o **aplicativo Flutter**, a **API FastAPI** e o **banco PostgreSQL**. Toda a regra de negócio fica na API, nunca no aplicativo.

```
App Flutter  --HTTP + token-->  API FastAPI  -->  PostgreSQL (+ pgvector)
                                    |
                                    +--> rembg (remoção de fundo)
                                    +--> armazenamento de imagens (pasta local na V1)
                                    +--> Gemini Vision (planejado)
```

### 5.1 Organização do servidor

O servidor é dividido em camadas, para que partes que podem mudar (como o serviço de visão ou o armazenamento) sejam trocadas sem alterar o restante:

- **api/v1 (rotas):** recebem as requisições HTTP e validam os dados. Não chamam `rembg` ou IA diretamente.
- **services:** regras de negócio.
- **adapters:** comunicação com `rembg`, armazenamento e (futuramente) Gemini.
- **db (models):** tabelas do banco, em SQLAlchemy.
- **schemas:** formatos de entrada e saída dos dados, em Pydantic.

### 5.2 Organização do aplicativo

O aplicativo é organizado em `core` (tema, constantes e comunicação com a API), `models`, `services` (um por recurso, chamam a API) e `views` (telas e seus controladores de estado, com Riverpod).

### 5.3 Fluxo de cadastro de uma peça

1. O usuário tira uma foto ou escolhe uma da galeria e vê uma pré-visualização.
2. O aplicativo envia a foto para `POST /pecas/processar-imagem`.
3. A API remove o fundo com `rembg`, salva a imagem e devolve a URL.
4. O aplicativo mostra o resultado. Se o processamento falhar, oferece continuar com a foto original (`POST /pecas/upload-original`).
5. O usuário preenche categoria, subcategoria, cor, estação e ocasião (apenas a categoria é obrigatória).
6. O aplicativo envia os dados para `POST /pecas`, e a peça é salva no banco.

### 5.4 Modelo de dados

| Tabela | Principais campos |
| --- | --- |
| `pecas` | id, usuario_id, imagem_url, categoria, subcategoria, cor_principal, estacao, ocasiao, criado_em |
| `looks` | id, usuario_id, nome, criado_em |
| `looks_pecas` | associação N:N entre looks e peças |

As tabelas foram criadas por duas migrações do Alembic (`0001_initial` e `0002_looks`). A primeira também habilita a extensão `pgvector`, que ainda não é usada pela aplicação.

### 5.5 Rotas da API na V1

| Método e rota | Função |
| --- | --- |
| `POST /pecas/processar-imagem` | Remove o fundo da foto e devolve a URL da imagem processada |
| `POST /pecas/upload-original` | Salva a foto original, usada quando o processamento falha |
| `POST /pecas` | Cria uma peça |
| `GET /pecas` | Lista as peças do usuário |
| `PUT /pecas/{id}` | Edita uma peça |
| `DELETE /pecas/{id}` | Exclui uma peça |
| `POST /looks` | Cria um look com peças do próprio usuário |
| `GET /looks` | Lista os looks do usuário, com suas peças |

Todas as rotas exigem token de autenticação e filtram os dados pelo usuário dele. Tentar usar uma peça de outro usuário resulta em erro, sem revelar que a peça existe.

---

## 6 Desenvolvimento e resultados da V1

### 6.1 Funcionalidades entregues

**Cadastro de peças.** O usuário captura ou escolhe uma foto, vê a prévia, envia para processamento (com indicador de carregamento) e confirma o resultado. Em seguida, preenche o formulário de dados da peça. Quando ocorre erro de rede ou falha na remoção de fundo, o aplicativo mostra uma mensagem clara e permite continuar com a foto original.

**Armário.** As peças aparecem agrupadas por categoria, com a quantidade em cada grupo, e há estados específicos para carregando, erro e armário vazio. O usuário pode filtrar por cor, estação e ocasião, combinando os filtros. Ao tocar numa peça, abre-se a tela de detalhe, de onde é possível editar ou excluir (com confirmação).

**Looks.** O usuário escolhe peças do próprio armário, dá um nome ao look e o salva. A listagem de looks mostra o nome e as miniaturas das peças e se atualiza sozinha após um novo salvamento.

**Identidade visual.** O aplicativo foi redesenhado a partir de um protótipo no Figma, com navegação inferior de cinco abas: Casa, Armário, Looks, IA/Sugestões e Referências. As duas últimas ainda são telas provisórias.

### 6.2 Resumo do andamento (backlog)

Foram detalhadas 12 PBIs, das quais 11 estão implementadas e 1 não foi iniciada.

| PBI | Descrição | Situação |
| --- | --- | --- |
| E1.F1.1 | Captura e seleção de foto | Concluída |
| E1.F1.2 | Remoção de fundo (backend) | Concluída, validada com imagem real |
| E1.F1.3 | Envio da foto e exibição do resultado | Concluída |
| E1.F1.4 | Continuar sem remoção de fundo em caso de falha | Concluída |
| E1.F1.5 | Testes automatizados do backend | Não iniciada |
| E1.F2.1 | Formulário de metadados e cadastro da peça | Concluída, com ressalvas nos testes |
| E1.F3.1 | Edição e exclusão de peça | Concluída |
| E2.F1.1 | Listagem do armário por categoria | Concluída |
| E2.F2.1 | Filtro por cor, estação e ocasião | Concluída |
| E3.F1.1 | Modelo e rotas de looks (backend) | Concluída e validada com banco real |
| E3.F1.2 | Tela de montagem de look | Concluída |
| E3.F1.3 | Listagem de looks salvos | Concluída |

### 6.3 Verificação realizada

- A análise estática do aplicativo (`dart analyze`) não aponta problemas.
- A suíte de testes do aplicativo (`flutter test`) tem 39 testes, dos quais 36 passam. As 3 falhas estão em `peca_form_test.dart` e estão ligadas ao comportamento do ambiente de teste (rolagem de tela e tempo de exibição de mensagens), não a um defeito identificado no aplicativo.
- A rota de looks (E3.F1.1) foi executada de verdade, contra um PostgreSQL local, com dois usuários de teste, e todos os critérios de aceite foram observados. Nesse processo foi encontrado e corrigido um erro real de serialização da resposta.
- A rota de remoção de fundo foi validada com imagem real e tratamento de erro.
- Demais rotas do servidor foram verificadas apenas quanto à compilação, porque a máquina de desenvolvimento ainda não tinha o ambiente Python completo na época.

---

## 7 Limitações da V1

Para ser transparente sobre o estado atual:

1. **Sem login real.** A autenticação com Supabase ainda não foi integrada. Os testes usam um token gerado localmente (`DEV_AUTH_TOKEN`), e as telas de login e de preferências são apenas esqueletos.
2. **Sem IA para sugerir.** O Gemini Vision ainda é um esqueleto. Metadados são preenchidos manualmente e não há recomendação automática de looks nem inspiração por imagem.
3. **Validação manual pendente.** O fluxo completo (celular ou navegador com a API real rodando) ainda precisa ser testado de ponta a ponta por uma pessoa.
4. **Testes automatizados incompletos.** O backend não tem suíte de testes (E1.F1.5) e 3 testes do formulário falham por questões do ambiente de teste.
5. **Armazenamento local.** As imagens ficam numa pasta do servidor. Para uso real será preciso migrar para um serviço de nuvem.
6. **Processamento de imagem síncrono.** A remoção de fundo ocorre durante a requisição, o que é aceitável com poucos usuários, mas deverá virar tarefa em segundo plano.
7. **Escopo parcial.** Faltam campos opcionais da peça (tamanho, data de compra, frequência de uso), filtros por tecido e marca, favoritar looks, organizá-los por ocasião e o histórico de uso.

---

## 8 Próximos passos

Seguindo a ordem definida nos requisitos, e a regra de que recursos de IA só entram depois que a base estiver sólida:

1. Validar manualmente o fluxo completo e corrigir o que aparecer.
2. Concluir os testes automatizados do backend (E1.F1.5) e os testes pendentes do formulário.
3. Integrar o login real com Supabase Auth.
4. Completar o Épico 3: favoritar looks, organizar por ocasião e registrar histórico de uso.
5. Implementar as preferências de estilo (Épico 4).
6. Integrar o Gemini Vision para sugerir metadados na hora do cadastro, sempre editáveis pelo usuário (Épico 5).
7. Criar o motor de sugestão de looks, baseado em regras e que valoriza peças pouco usadas (Épico 6).
8. Se o cronograma permitir, implementar a inspiração por imagem (Épico 7), a funcionalidade de maior risco técnico.

---

## 9 Considerações finais

A V1 entrega a base funcional do Guarda-Roupa Virtual: cadastrar peças por foto com remoção de fundo, organizá-las, filtrá-las e combiná-las em looks. A arquitetura em camadas e a regra de usar apenas peças do usuário foram mantidas desde o início, e a divisão em PBIs com status verificado permite acompanhar o que já está pronto e o que falta. As principais pendências são a autenticação real, a validação manual de ponta a ponta e a chegada dos recursos de inteligência artificial, que são o diferencial do projeto e o foco das próximas versões.

---

## Referências

FASTAPI. *FastAPI documentation*. Disponível em: https://fastapi.tiangolo.com. Acesso em: out. 2026.

FLUTTER. *Flutter documentation*. Disponível em: https://docs.flutter.dev. Acesso em: out. 2026.

POSTGRESQL GLOBAL DEVELOPMENT GROUP. *PostgreSQL documentation*. Disponível em: https://www.postgresql.org/docs. Acesso em: out. 2026.

PGVECTOR. *pgvector: open-source vector similarity search for Postgres*. Disponível em: https://github.com/pgvector/pgvector. Acesso em: out. 2026.

SQLALCHEMY. *SQLAlchemy 2.0 documentation*. Disponível em: https://docs.sqlalchemy.org. Acesso em: out. 2026.

ALEMBIC. *Alembic documentation*. Disponível em: https://alembic.sqlalchemy.org. Acesso em: out. 2026.

REMBG. *rembg: tool to remove images background*. Disponível em: https://github.com/danielgatis/rembg. Acesso em: out. 2026.

SUPABASE. *Supabase documentation*. Disponível em: https://supabase.com/docs. Acesso em: out. 2026.

GOOGLE. *Gemini API documentation*. Disponível em: https://ai.google.dev/gemini-api/docs. Acesso em: out. 2026.
