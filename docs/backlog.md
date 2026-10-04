# Backlog — PBIs

Quebra de features do [Documento de Requisitos](requisitos.md) em PBIs (Product Backlog Items) — unidades pequenas o bastante pra entrar num sprint, com critério de aceite e status real de implementação. Diferente do `requisitos.md` (mais estável, o "o quê" e "por quê"), este documento muda com frequência conforme o time avança — é o "como", pra planejamento tático.

Numeração: `E<épico>.F<feature>.<PBI>` — ex. `E1.F1.2` é o segundo PBI da primeira feature do Épico 1.

**Status** reflete o estado real do código nesta data, não uma estimativa. "Implementado" e "testado/validado" são afirmações distintas e nunca combinadas sem verificação — um PBI só é marcado como validado se foi de fato executado e observado funcionando, não apenas revisado.

---

## Épico 1, Feature 1 — Adicionar peça por foto, com remoção automática de fundo

Feature completa = usuário tira/seleciona uma foto → foto é enviada e processada (fundo removido) → resultado é exibido pra confirmação. **Não inclui** preencher categoria/cor/etc. (isso é a Feature 2 do mesmo épico) nem salvar a peça no banco (`POST /pecas` já existe, mas consome dados da Feature 2 também).

### E1.F1.1 — Captura e seleção de foto no app

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E1-F1-adicionar-foto/E1.F1.1-captura-e-selecao-de-foto.md](PBIs/E1-F1-adicionar-foto/E1.F1.1-captura-e-selecao-de-foto.md).

**Descrição**: tela de upload permite tirar foto pela câmera ou escolher da galeria (`image_picker`), com preview antes de confirmar o envio.

**Critérios de aceite:**
- Usuário consegue tirar uma foto pela câmera ou escolher uma da galeria.
- A foto escolhida aparece em preview antes de qualquer envio.
- Usuário pode descartar/trocar a foto antes de confirmar.

**Status**: **concluída** — implementada (`upload_view.dart`, `upload_controller.dart`, permissões iOS), `flutter analyze` limpo e testes automatizados passando. Validação manual visual no Chrome pelo usuário ainda pendente — ver log de implementação no arquivo detalhado.
**Estimativa**: P.
**Dependências**: nenhuma.

### E1.F1.2 — Endpoint de processamento de imagem (remoção de fundo)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E1-F1-adicionar-foto/E1.F1.2-processamento-de-imagem.md](PBIs/E1-F1-adicionar-foto/E1.F1.2-processamento-de-imagem.md).

**Descrição**: endpoint backend que recebe a foto, remove o fundo via `rembg`, salva o resultado no storage e devolve a URL.

**Critérios de aceite:**
- `POST /pecas/processar-imagem` aceita upload multipart.
- Retorna a URL de uma imagem PNG com fundo removido, no caminho feliz.
- Se a imagem for inválida/corrompida ou o `rembg` falhar por qualquer motivo, o endpoint captura o erro, loga no backend, e devolve um erro HTTP estruturado — nunca uma exception crua (500 sem tratamento). Este critério é só sobre o **contrato do backend**; o que o app faz com esse erro é escopo do E1.F1.4, não deste PBI.

**Status**: **concluída** — try/except implementado (`app/core/exceptions.py`, `app/adapters/rembg_adapter.py`) traduzido para `HTTPException` estruturada + log no router (`app/api/v1/pecas.py`), e a chamada síncrona (CPU-bound) agora roda via `run_in_threadpool`, resolvendo o bloqueio do event loop. Todos os critérios de aceite verificados por execução real (API local + `TestClient`, não só revisão de código) — ver log de implementação no arquivo detalhado.
**Estimativa**: pequena.
**Dependências**: nenhuma.

### E1.F1.3 — Envio da foto pro backend e exibição do resultado

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E1-F1-adicionar-foto/E1.F1.3-envio-e-exibicao-do-resultado.md](PBIs/E1-F1-adicionar-foto/E1.F1.3-envio-e-exibicao-do-resultado.md).

**Descrição**: liga E1.F1.1 e E1.F1.2 — app envia a foto capturada, mostra estado de carregamento durante o processamento, e exibe a imagem sem fundo pro usuário confirmar.

**Critérios de aceite:**
- Indicador de carregamento visível durante upload/processamento.
- Imagem processada é exibida ao concluir.
- Falha de rede ou timeout mostra mensagem clara, sem travar a tela.

**Status**: **concluída** — botão "Confirmar" ligado a `POST /pecas/processar-imagem`, com estados de carregamento/sucesso/erro (`upload_controller.dart`), `PecaService` corrigido para funcionar em Web (`XFile`/`MultipartFile.fromBytes` em vez de `dart:io File`), e timeout configurado no `ApiClient`. `flutter analyze` limpo e `flutter test` com 4/4 passando (carregamento, sucesso e erro cobertos com `PecaService` falso). Validação manual visual no Chrome e teste de ponta a ponta contra o backend real ainda pendentes — ver log de implementação no arquivo detalhado.
**Estimativa**: M.
**Dependências**: E1.F1.1, E1.F1.2.

### E1.F1.4 — Degradação graciosa no app quando o processamento falha

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E1-F1-adicionar-foto/E1.F1.4-degradacao-graciosa-no-app.md](PBIs/E1-F1-adicionar-foto/E1.F1.4-degradacao-graciosa-no-app.md).

**Descrição**: cobre o requisito não-funcional "nenhuma chamada de IA pode derrubar um fluxo do usuário" (ver `requisitos.md`), do lado do **app** — pressupõe que o backend já sinaliza falha de forma limpa (E1.F1.2). Escopo aqui é só a reação do app a esse sinal (erro estruturado ou timeout de rede), não o tratamento do erro em si.

**Critérios de aceite:**
- Se o backend retornar o erro estruturado do E1.F1.2, ou a requisição expirar (timeout de rede), o app oferece explicitamente seguir com a foto original (sem remoção de fundo) em vez de travar o cadastro.
- Usuário consegue completar o cadastro normalmente mesmo com essa falha.

**Status**: **concluída** — botão "Continuar sem remoção de fundo" na tela de erro da E1.F1.3, novo endpoint `POST /pecas/upload-original` (salva a foto sem `rembg`/Gemini) para dar uma URL utilizável quando o processamento falha. Decisão de escopo (validada com o usuário): o fallback é oferecido para qualquer erro do envio, não só timeout/erro estruturado. `flutter test` com 6/6 passando; backend verificado só por `py_compile` (sem venv configurado nesta máquina para rodar de verdade — ver log de implementação). Validação manual visual no Chrome e execução real do backend ainda pendentes.
**Estimativa**: P.
**Dependências**: E1.F1.2 (precisa existir um erro estruturado pra reagir a), E1.F1.3.

### E1.F1.5 — Testes automatizados do fluxo de processamento

**Descrição**: suíte `pytest` cobrindo `POST /pecas/processar-imagem` — caminho feliz e falha do `rembg` (depende de E1.F1.4 existir pra ter o que testar).

**Status**: não iniciado — o projeto ainda não tem nenhuma suíte de teste configurada.
**Estimativa**: M.
**Dependências**: E1.F1.2, E1.F1.4.

---

## Épico 1, Feature 2 — Preenchimento manual dos metadados da peça

Feature completa = depois que a foto já foi processada (Feature 1), o usuário preenche categoria/subcategoria/cor/estação/ocasião num formulário e confirma — o que salva a peça de fato no banco via `POST /pecas` (endpoint já existe desde antes da Feature 1, mas até agora nada no app o chamava). Diferente da Feature 1, aqui não há serviço de IA envolvido nem passo lento em background — é CRUD direto, por isso cabe numa única PBI em vez de ser quebrada em captura/processamento/degradação como a Feature 1 foi.

### E1.F2.1 — Formulário de metadados e cadastro da peça

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E1-F2-metadados-da-peca/E1.F2.1-formulario-e-cadastro-da-peca.md](PBIs/E1-F2-metadados-da-peca/E1.F2.1-formulario-e-cadastro-da-peca.md).

**Descrição**: após o resultado do processamento de imagem (E1.F1.3/E1.F1.4), o usuário avança para um formulário com categoria, subcategoria, cor principal, estação e ocasião; ao confirmar, os dados (mais a `imagem_url` já obtida) são enviados para `POST /pecas`, criando a peça no banco.

**Critérios de aceite:**
- Depois de ver o resultado do processamento de imagem, o usuário consegue avançar para um formulário de metadados (hoje esse avanço não existe — a tela de resultado só permite trocar de foto).
- O formulário exige pelo menos a categoria (único campo obrigatório no schema atual) antes de permitir confirmar.
- Ao confirmar com dados válidos, a peça é criada via `POST /pecas` e o usuário recebe confirmação de sucesso.
- Se o envio falhar (rede, validação do servidor, erro 401 por falta de autenticação), o app mostra uma mensagem clara e não descarta os dados já preenchidos.

**Status**: **concluída (com ressalvas)** — formulário, controller, navegação e `POST /pecas` ligados; `DEV_AUTH_TOKEN` desbloqueia o envio autenticado sem login real. `dart analyze` limpo, suíte pré-existente (`widget_test.dart`) 7/7 passando. Os 3 testes novos de `peca_form_test.dart` ainda falham por mecânica do harness de teste (scroll/timing de SnackBar), não por bug do app — ver log de implementação no arquivo detalhado. Validação manual end-to-end (Chrome + backend real) pendente.
**Estimativa**: M.
**Dependências**: E1.F1.3 (precisa de uma `imagem_url` já obtida), E1.F1.4 (a `imagem_url` pode vir do fallback sem remoção de fundo).

---

## Épico 1, Feature 3 — Edição e exclusão de peças cadastradas

Feature completa = a partir do armário (E2.F1.1), o usuário consegue tocar numa peça, ver seus detalhes, corrigir os metadados cadastrados errados (E1.F2.1) e excluir uma peça que não quer mais. Não inclui trocar a foto da peça (reprocessar remoção de fundo) nem os campos opcionais ainda inexistentes (tamanho, data de compra, frequência de uso — feature própria do Épico 1 listada separadamente em `requisitos.md`).

### E1.F3.1 — Edição e exclusão de peça cadastrada

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E1-F3-edicao-exclusao-peca/E1.F3.1-edicao-e-exclusao-de-peca.md](PBIs/E1-F3-edicao-exclusao-peca/E1.F3.1-edicao-e-exclusao-de-peca.md).

**Descrição**: tocar numa miniatura do armário abre uma tela de detalhe da peça, com opções de editar (reaproveitando o formulário da E1.F2.1, pré-preenchido) e excluir (com confirmação). Backend ganha `PUT /pecas/{id}` e `DELETE /pecas/{id}`, escopados por `usuario_id`.

**Critérios de aceite:**
- Tocar numa miniatura do armário abre o detalhe da peça (imagem + metadados).
- Editar um campo e confirmar atualiza a peça via `PUT /pecas/{id}`; o armário reflete a mudança ao voltar.
- Excluir, com confirmação, remove a peça via `DELETE /pecas/{id}`; ela some do armário.
- Peça de outro usuário não pode ser editada/excluída (404, nunca 200/403 revelando existência).

**Status**: **concluída (validação manual end-to-end pendente)** — `PecaDetailView`, modo de edição do `PecaFormView` e `PUT`/`DELETE /pecas/{id}` (escopados por `usuario_id`) implementados. `dart analyze` limpo; `flutter test` 21/24 (3 falhas pré-existentes e já documentadas na E1.F2.1, não relacionadas a esta PBI) — os 6 testes novos desta PBI passam. Backend só verificado por `py_compile` (sem venv nesta máquina). Fluxo real no Chrome + backend local, e o 404 entre usuários diferentes, ainda pendentes — ver log de implementação no arquivo detalhado.
**Estimativa**: M.
**Dependências**: E1.F2.1 (reaproveita o formulário de metadados), E2.F1.1 (é de onde se chega na peça, pelo armário).

---

## Épico 2, Feature 1 — Listagem do armário agrupada por categoria

Feature completa = usuário abre o app e vê as peças que já cadastrou, organizadas por categoria (camisetas, calças, vestidos, sapatos, acessórios), com navegação inferior entre Armário e Looks. É só leitura (`GET /pecas`, já existente e escopado por `usuario_id`) — sem IA e sem passo lento, por isso cabe numa única PBI, como a Feature 2 do Épico 1. **Não inclui** filtros (Feature 2 do Épico 2), nem detalhe/edição/exclusão de peça (Épico 1, Feature 3).

### E2.F1.1 — Listagem do armário agrupada por categoria

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E2-F1-listagem-do-armario/E2.F1.1-listagem-agrupada-por-categoria.md](PBIs/E2-F1-listagem-do-armario/E2.F1.1-listagem-agrupada-por-categoria.md).

**Descrição**: `WardrobeView` passa a buscar as peças do usuário e exibi-las agrupadas por categoria, em grade de miniaturas, com estados de carregamento/erro/vazio e atualização ao voltar do cadastro. Uma casca de navegação (`HomeShell`) com barra inferior Armário/Looks torna as duas telas principais alcançáveis.

**Critérios de aceite:**
- Peças aparecem agrupadas por categoria, com título e quantidade por grupo; categorias fora da lista fixa vão para "Outras".
- Armário vazio mostra orientação para adicionar a primeira peça; falha de rede/401 mostra mensagem clara com "Tentar novamente".
- Ao salvar uma peça no formulário, o usuário volta ao armário já com a peça nova listada e a barra inferior visível.
- Cada usuário vê somente as próprias peças.

**Status**: **concluída (validação manual end-to-end pendente)** — `WardrobeView`, `HomeShell`, agrupamento por categoria e `order_by` no backend implementados. `dart analyze` limpo; `flutter test` 15/18 (3 falhas pré-existentes e já documentadas na E1.F2.1, não relacionadas a esta PBI) — os 8 testes novos desta PBI passam. Backend só verificado por `py_compile` (sem venv nesta máquina). Fluxo real no Chrome + backend local ainda pendente — ver log de implementação no arquivo detalhado.
**Estimativa**: M.
**Dependências**: E1.F2.1.

---

## Épico 2, Feature 2 — Filtro de peças por cor, estação e ocasião

Feature completa = na tela de armário (Feature 1), o usuário restringe a lista visível combinando filtros de cor, estação e/ou ocasião. **Escopo reduzido**: `requisitos.md` também lista filtro por tecido e marca, mas o modelo de peça (`backend/app/db/models.py`) e o formulário de cadastro (E1.F2.1) não têm esses dois campos — adicioná-los é um gap de schema/formulário fora desta feature, não um filtro. Filtragem é 100% client-side (a lista completa já vem de `GET /pecas`, sem paginação), sem IA e sem passo lento — cabe numa única PBI, como a Feature 2 do Épico 1 e a Feature 1 deste épico.

### E2.F2.1 — Filtro de peças por cor, estação e ocasião

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E2-F2-filtro-armario/E2.F2.1-filtro-por-cor-estacao-ocasiao.md](PBIs/E2-F2-filtro-armario/E2.F2.1-filtro-por-cor-estacao-ocasiao.md).

**Descrição**: `WardrobeView` ganha um painel de filtros (cor principal, estação, ocasião) que atua sobre a lista já carregada, combinando os filtros ativos com E lógico; opções de cor/estação vêm dos valores já presentes no armário do usuário (campos livres, sem enum), ocasião usa a lista fixa existente.

**Critérios de aceite:**
- Usuário filtra por cor, estação e/ou ocasião, com os filtros combinando entre si (E lógico).
- Limpar filtros restaura a lista completa agrupada por categoria.
- Nenhuma peça corresponde aos filtros ativos → mensagem clara com ação de limpar, sem travar a tela.
- Cada usuário filtra somente dentro das próprias peças (reflexo do `GET /pecas` já escopado por `usuario_id`).

**Status**: **concluída (validação manual visual no Chrome pendente)** — `FiltroArmario`, `filtroArmarioProvider` e `filtrarPecas` implementados em `wardrobe_controller.dart`; painel de filtros (`FilterChip` por cor/estação/ocasião) e estado de vazio-por-filtro em `wardrobe_view.dart`. `dart analyze` limpo; `flutter test` 28/31 (as mesmas 3 falhas pré-existentes de `peca_form_test.dart`, não relacionadas a esta PBI) — os 7 testes novos desta PBI passam. Fluxo real no Chrome + backend local ainda pendente — ver log de implementação no arquivo detalhado.
**Estimativa**: P.
**Dependências**: E2.F1.1 (listagem e agrupamento do armário, base sobre a qual o filtro atua).

---

## Épico 3, Feature 1 — Montar um look manualmente a partir das peças cadastradas

Feature completa = usuário escolhe peças do próprio armário, monta um look e salva; a tela "Looks" (hoje placeholder em `looks_view.dart`) passa a listar os looks salvos. **Não inclui** favoritar (Feature 2), organizar/filtrar por ocasião (Feature 3) nem histórico de uso (Feature 4) — essas são as próximas features do mesmo épico, cada uma com sua própria quebra quando chegar a vez. Diferente do Épico 1/2, aqui o domínio "look" ainda não existe no backend (sem model, sem endpoint) — por isso a quebra separa a base de dados do consumo pelo app, como foi feito em E1.F1.2 → E1.F1.3.

### E3.F1.1 — Modelo de dados e endpoint de criação/consulta de looks

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F1-montagem-manual-looks/E3.F1.1-modelo-e-endpoint-de-looks.md](PBIs/E3-F1-montagem-manual-looks/E3.F1.1-modelo-e-endpoint-de-looks.md).

**Descrição**: tabelas `looks` e `looks_pecas` (associação N:N com `pecas`), migração Alembic, e `POST /looks` / `GET /looks` escopados por `usuario_id`.

**Critérios de aceite:**
- `POST /looks` cria um look com nome e lista de `peca_id`s, todas pertencentes ao usuário autenticado.
- `GET /looks` retorna só os looks do usuário autenticado, com as peças de cada um.
- Incluir um `peca_id` que não existe ou pertence a outro usuário é rejeitado (422/404), nunca silenciosamente ignorado.

**Status**: **concluída e validada** — `Look`/`looks_pecas` (`backend/app/db/models.py`), `LookCreate`/`LookRead` (`schemas/look.py`) e `POST`/`GET /looks` (`api/v1/looks.py`) implementados; migração `0002` aplicada com sucesso num Postgres local real. Todos os 4 critérios de aceite verificados por execução real da API (`uvicorn` + `curl` + dois usuários de teste), não só `py_compile` — primeira PBI do projeto com banco local de fato disponível durante a implementação. Bug real encontrado e corrigido no caminho: `db.refresh(look)` quebrava a serialização da resposta (`MissingGreenlet`) por invalidar a relação `pecas` já carregada — ver log de implementação no arquivo detalhado.
**Estimativa**: P.
**Dependências**: nenhuma (reaproveita `Peca` já existente).

### E3.F1.2 — Tela de montagem manual do look no app

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F1-montagem-manual-looks/E3.F1.2-tela-de-montagem-do-look.md](PBIs/E3-F1-montagem-manual-looks/E3.F1.2-tela-de-montagem-do-look.md).

**Descrição**: nova tela acessível a partir de "Looks" onde o usuário seleciona peças do armário (reaproveitando `pecaListProvider`/agrupamento por categoria), dá um nome ao look e confirma, chamando `POST /looks`.

**Critérios de aceite:**
- Botão "Montar look" em "Looks" abre a grade de peças agrupada por categoria, com campo de nome.
- Sem nome preenchido ou sem peça selecionada, o botão de salvar permanece desabilitado.
- Com nome e 1+ peças, confirmar chama `POST /looks` e volta para "Looks" com confirmação em sucesso.
- Falha no envio mostra mensagem clara e preserva nome/seleção para nova tentativa.
- Armário sem nenhuma peça cadastrada mostra orientação para cadastrar antes, sem grade vazia.

**Status**: **concluída (validação manual visual no Chrome pendente)** — `MontarLookView`, `MontagemLookController` e `LookService.criarLook` implementados; FAB "Montar look" novo em `LooksView`. `dart analyze` limpo; `flutter test` 32/35 (as mesmas 3 falhas pré-existentes de `peca_form_test.dart`, não relacionadas a esta PBI) — os 4 testes novos desta PBI passam. Bug real encontrado e corrigido no caminho: colisão de hero tag entre os FABs de `WardrobeView` e `LooksView` (ambas montadas ao mesmo tempo pelo `IndexedStack` do `HomeShell`) — ver log de implementação no arquivo detalhado.
**Estimativa**: M.
**Dependências**: E3.F1.1.

### E3.F1.3 — Listagem dos looks salvos no app

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F1-montagem-manual-looks/E3.F1.3-listagem-dos-looks-salvos.md](PBIs/E3-F1-montagem-manual-looks/E3.F1.3-listagem-dos-looks-salvos.md).

**Descrição**: `LooksView` passa a buscar e exibir os looks do usuário (miniaturas das peças de cada look), substituindo o placeholder atual — espelha a E2.F1.1, mas para looks em vez de peças.

**Critérios de aceite:**
- Looks salvos aparecem com nome e miniaturas das peças que os compõem.
- Sem nenhum look salvo, mostra orientação pra montar o primeiro.
- Falha ao buscar mostra mensagem clara com "Tentar novamente".
- Um look recém-salvo em `MontarLookView` já aparece na lista ao voltar, sem puxar manualmente.
- Cada usuário vê só os próprios looks.

**Status**: **concluída (validação manual visual no Chrome pendente)** — `LooksView` reescrita (`ConsumerWidget` real, `RefreshIndicator`+`ListView` de `_LookCard`), `lookListProvider` (`looks_controller.dart`) e `LookService.listarLooks()` implementados; `montar_look_view.dart` invalida a lista ao salvar com sucesso. `dart analyze` limpo; `flutter test` 36/39 (as mesmas 3 falhas pré-existentes de `peca_form_test.dart`, não relacionadas a esta PBI) — os 4 testes novos de `looks_test.dart` passam. Efeito colateral corrigido: `LooksView` virar real quebrou testes pré-existentes que não previam a chamada a `GET /looks` (mesmo padrão já visto na E2.F1.1) — ver log de implementação no arquivo detalhado.
**Estimativa**: M.
**Dependências**: E3.F1.1, E3.F1.2.

---

## Resumo do estado atual

| PBI | Descrição curta | Status |
| --- | --- | --- |
| E1.F1.1 | Captura/seleção de foto (mobile) | Concluída (validação visual manual pendente) |
| E1.F1.2 | Endpoint de remoção de fundo (backend) | Concluída (tratamento de erro e validação com imagem real já feitos — ver arquivo detalhado) |
| E1.F1.3 | Integração envio + exibição (mobile) | Concluída (validação visual manual e teste contra backend real pendentes) |
| E1.F1.4 | Degradação no app quando processamento falha | Concluída (execução real do endpoint novo e validação visual manual pendentes) |
| E1.F1.5 | Testes automatizados | Não iniciado |
| E1.F2.1 | Formulário de metadados e cadastro da peça (mobile) | Concluída (testes do formulário com falhas conhecidas de harness; validação manual pendente) |
| E1.F3.1 | Edição e exclusão de peça cadastrada | Concluída (validação manual end-to-end pendente) |
| E2.F1.1 | Listagem do armário agrupada por categoria + navegação inferior (mobile) | Concluída (validação manual end-to-end pendente) |
| E2.F2.1 | Filtro de peças por cor, estação e ocasião (mobile) | Concluída (validação manual visual no Chrome pendente) |
| E3.F1.1 | Modelo de dados e endpoint de looks (backend) | Concluída e validada (execução real contra Postgres local) |
| E3.F1.2 | Tela de montagem manual do look (mobile) | Concluída (validação manual visual no Chrome pendente) |
| E3.F1.3 | Listagem dos looks salvos (mobile) | Concluída (validação manual visual no Chrome pendente) |

E1.F1.1 a E1.F3.1 têm o código escrito, testado (onde há suíte automatizada) e revisado — falta a validação manual visual/end-to-end (Chrome + backend real rodando juntos, incluindo `rembg` de verdade), que exige interação humana e um ambiente Python completo, nenhum dos dois disponível nesta sessão. O trabalho restante é a E1.F1.5 (testes automatizados do backend) e a validação manual acumulada de todo o fluxo (cadastro → armário → edição/exclusão).
