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

## Épico 3, Feature 2 — Salvar looks favoritos

Feature completa = usuário marca e desmarca looks como favoritos e consegue listar só os favoritos. Backend primeiro (campo + rota que altera um look existente, que ainda não existe), depois o app — mesma separação da Feature 1. Introduz o `PATCH /looks/{id}` que a Feature 3 reaproveita para `ocasiao`.

### E3.F2.1 — Campo favorito e `PATCH /looks/{id}` (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F2-looks-favoritos/E3.F2.1-campo-favorito-e-patch-de-look.md](PBIs/E3-F2-looks-favoritos/E3.F2.1-campo-favorito-e-patch-de-look.md).

**Descrição**: coluna `favorito` em `looks` (migração `0003`), exposta em `LookRead`, e `PATCH /looks/{id}` com atualização parcial escopada por `usuario_id`.

**Critérios de aceite:**
- `PATCH /looks/{id}` com `{"favorito": true}` atualiza o look; `GET /looks` reflete.
- Look novo nasce com `favorito: false`; looks anteriores à migração também.
- Look inexistente ou de outro usuário → 404, sem alterar nada.

**Status**: **concluída e validada** — coluna `favorito` (migração `0003`, upgrade/downgrade testados), `LookUpdate` e `PATCH /looks/{id}` implementados. Critérios de aceite verificados por execução real (API `uvicorn` + Postgres local + `curl`, dois usuários), não só `compileall`. Encontrado e tratado no caminho: `{"favorito": null}` virava erro de banco, agora é 422 — ver log de implementação no arquivo detalhado.
**Estimativa**: P.
**Dependências**: E3.F1.1.

### E3.F2.2 — Favoritar looks e filtrar favoritos no app

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F2-looks-favoritos/E3.F2.2-favoritar-e-filtrar-no-app.md](PBIs/E3-F2-looks-favoritos/E3.F2.2-favoritar-e-filtrar-no-app.md).

**Descrição**: coração em cada card da `LooksView` que alterna o favorito via `PATCH`, e filtro "Favoritos" client-side (mesmo padrão da E2.F2.1).

**Critérios de aceite:**
- Tocar no coração favorita/desfavorita o look e o estado persiste ao reabrir o app.
- O filtro "Favoritos" restringe a lista; sem favoritos, mostra vazio-por-filtro com "Limpar filtro".
- Falha no `PATCH` mostra mensagem clara e mantém o estado anterior.

**Status**: concluída (validação manual no Chrome pendente).
**Estimativa**: M.
**Dependências**: E3.F2.1, E3.F1.3.

---

## Épico 3, Feature 3 — Organizar looks por ocasião

Feature completa = look guarda uma ocasião (trabalho, faculdade, festa, academia, viagem), escolhida ao montar ou alterada depois, e a lista pode ser filtrada por ela. Mesmo vocabulário de `ocasioesFixas` já usado nas peças; no banco continua texto livre, sem enum.

### E3.F3.1 — Campo ocasião no look (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F3-looks-por-ocasiao/E3.F3.1-campo-ocasiao-no-look.md](PBIs/E3-F3-looks-por-ocasiao/E3.F3.1-campo-ocasiao-no-look.md).

**Descrição**: coluna `ocasiao` (nullable) em `looks` (migração `0005`), aceita em `POST /looks` e no `PATCH /looks/{id}` da E3.F2.1, e exposta em `LookRead`.

**Critérios de aceite:**
- `POST /looks` com `ocasiao` grava e devolve o valor; sem `ocasiao`, fica `null`.
- `PATCH` com `{"ocasiao": "Festa"}` troca; com `null` ou texto vazio limpa; sem a chave, preserva.
- Look de outro usuário → 404.

**Status**: **concluída e validada** — coluna `ocasiao` (migração `0005`, upgrade/downgrade testados), aceita em `POST /looks` e `PATCH /looks/{id}`, exposta em `LookRead`; texto vazio ou só com espaços vira `null`. Critérios de aceite verificados por execução real (API + Postgres local + `curl`, dois usuários), sem suíte `pytest` ainda. **Atualizado em 2026-10-20 (a pedido do usuário):** o look passou a ter várias ocasiões — `ocasiao` virou `ocasioes` (lista; migração `0008`, que preserva as ocasiões já salvas); limpar = `[]`, `null` dá 422. Verificado por execução real (migração com dados reais, upgrade/downgrade, API com `curl`).
**Estimativa**: P.
**Dependências**: E3.F2.1.

### E3.F3.2 — Ocasião na montagem, no card e na edição do look (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F3-looks-por-ocasiao/E3.F3.2-ocasiao-na-montagem-e-no-card.md](PBIs/E3-F3-looks-por-ocasiao/E3.F3.2-ocasiao-na-montagem-e-no-card.md).

**Descrição**: seletor opcional de ocasião em `MontarLookView`, chip de ocasião no card e menu do card com "Alterar ocasião" (bottom sheet com "Sem ocasião"). O menu do card nasce aqui; a E3.F4.2 acrescenta itens.

**Critérios de aceite:**
- Ocasião escolhida ao montar aparece como chip no card; sem escolha, salvar funciona e o card não mostra chip.
- "Alterar ocasião" troca ou remove a ocasião de um look já salvo.
- Falha no envio mostra mensagem clara e preserva os dados da montagem.

**Status**: **concluída (validação manual visual no Chrome pendente)** — `Look.ocasiao`, `criarLook` com `ocasiao` opcional, seletor de `ChoiceChip`s na montagem, `Chip` no card e menu "Alterar ocasião" (bottom sheet com "Sem ocasião") implementados. `dart analyze` limpo; `flutter test` 62/62, com 6 testes novos desta PBI. **Atualizado em 2026-10-20:** seletor de ocasiões na montagem e menu "Alterar ocasião" passaram a seleção múltipla (chips marcáveis; sheet com caixas de marcação, "Sem ocasião" e "Salvar"); o card mostra um chip por ocasião.
**Estimativa**: M.
**Dependências**: E3.F3.1, E3.F2.2.

### E3.F3.3 — Filtro de looks por ocasião (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F3-looks-por-ocasiao/E3.F3.3-filtro-de-looks-por-ocasiao.md](PBIs/E3-F3-looks-por-ocasiao/E3.F3.3-filtro-de-looks-por-ocasiao.md).

**Descrição**: chips de ocasião na `LooksView` (seleção única), combinados por E lógico com "Favoritos", estendendo o `FiltroLooks` da E3.F2.2.

**Critérios de aceite:**
- Selecionar uma ocasião restringe a lista; selecionar de novo desativa.
- Combina com "Favoritos" (E lógico); sem resultado, vazio-por-filtro com "Limpar filtros".
- Look sem ocasião só aparece quando nenhuma ocasião está selecionada.

**Status**: **concluída (validação manual visual no Chrome pendente)** — `FiltroLooks.ocasiao` (seleção única, E lógico com Favoritos), `ChoiceChip`s de ocasião num `Wrap` ao lado de "Favoritos" e vazio-por-filtro genérico com "Limpar filtros". `dart analyze` limpo; `flutter test` 66/66, com 4 testes novos desta PBI. Atenção de UX: Favoritos + 10 ocasiões ocupam várias linhas em tela de celular — ver log. **Atualizado em 2026-10-20:** o filtro aceita várias ocasiões (OU entre elas; E lógico com "Favoritos"); `FiltroLooks.ocasioes` é um conjunto. `flutter test` 118/118.
**Estimativa**: P.
**Dependências**: E3.F3.2, E3.F2.2.

---

## Épico 3, Feature 4 — Histórico de looks utilizados

Feature completa = usuário registra que usou um look em certa data, vê o histórico e é avisado quando está prestes a repetir uma combinação usada há pouco. Guarda um registro por uso (não um contador), porque a história pede saber **quando**, e o Épico 6 vai precisar de recência e frequência. **Não inclui** atualizar a "frequência de uso" das peças (campo ainda inexistente em `Peca`) nem estatísticas.

### E3.F4.1 — Registro de uso e histórico de looks (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F4-historico-de-looks/E3.F4.1-registro-de-uso-e-historico-de-looks.md](PBIs/E3-F4-historico-de-looks/E3.F4.1-registro-de-uso-e-historico-de-looks.md).

**Descrição**: tabela `looks_usos` (migração `0006`), `POST /looks/{id}/usos`, `GET /looks/historico` (usos do usuário com o look e as peças embutidos) e `DELETE /looks/usos/{id}`.

**Critérios de aceite:**
- `POST` registra um uso na data informada; data futura → 422; look de outro usuário ou inexistente → 404.
- `GET /looks/historico` devolve só os usos do usuário, mais recentes primeiro, com as peças de cada look.
- O mesmo look pode ter vários usos, inclusive no mesmo dia.
- `DELETE` remove um uso próprio (204); de outro usuário → 404.

**Status**: **concluída e validada** — tabela `looks_usos` (migração `0006`), `POST /looks/{id}/usos`, `GET /looks/historico` (com `de`/`ate` opcionais, acrescentados a pedido do calendário da E3.F4.3) e `DELETE /looks/usos/{id}`. Verificado por execução real (API + Postgres local + `curl`, dois usuários), sem suíte `pytest` ainda.
**Estimativa**: M.
**Dependências**: E3.F1.1.

### E3.F4.2 — Registrar uso de um look no app (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F4-historico-de-looks/E3.F4.2-registrar-uso-do-look-no-app.md](PBIs/E3-F4-historico-de-looks/E3.F4.2-registrar-uso-do-look-no-app.md).

**Descrição**: o menu do card ganha "Usei hoje" (um toque) e "Usei em outra data…" (seletor de data sem datas futuras), chamando `POST /looks/{id}/usos` com a data local do dispositivo.

**Critérios de aceite:**
- "Usei hoje" registra o uso com a data de hoje e confirma na tela.
- "Usei em outra data…" não permite datas futuras; cancelar não envia nada.
- Falha no envio mostra mensagem clara sem travar a tela.

**Status**: **concluída (validação manual end-to-end pendente)** — `LookService.registrarUso` e dois itens novos no menu do card ("Usei hoje", "Usei em outra data…" com `showDatePicker` sem datas futuras), com confirmação por `SnackBar` e mensagens de erro por status. `dart analyze` limpo; `flutter test` 74/74, com 8 testes novos desta PBI. Gravação real em `looks_usos` a partir do app ainda não conferida.
**Estimativa**: P.
**Dependências**: E3.F4.1, E3.F3.2.

### E3.F4.3 — Tela de histórico de looks utilizados (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F4-historico-de-looks/E3.F4.3-tela-de-historico-de-looks.md](PBIs/E3-F4-historico-de-looks/E3.F4.3-tela-de-historico-de-looks.md).

**Descrição**: `HistoricoView`, aberta por um ícone na `AppBar` de `LooksView`, lista os usos do mais recente ao mais antigo, agrupados por dia, com miniaturas das peças e remoção de registro com confirmação. Define o `historicoProvider`.

**Critérios de aceite:**
- Usos aparecem do mais recente ao mais antigo, com data, nome do look e miniaturas, agrupados por dia.
- Sem usos, mostra orientação; falha mostra mensagem com "Tentar novamente".
- Remover um uso (com confirmação) o tira da lista; um uso recém-registrado já aparece.

**Status**: **concluída (validação manual end-to-end pendente)** — histórico em formato de calendário mensal (grade com marcação nos dias de uso + lista do dia, remoção com confirmação), buscando só o mês visível; ícone na `AppBar` de Looks. `dart analyze` limpo; `flutter test` 90/90. Mudança de escopo em relação ao detalhamento original (lista agrupada → calendário) registrada no arquivo detalhado. Fluxo no Chrome com backend real ainda não conferido.
**Estimativa**: M.
**Dependências**: E3.F4.1, E3.F4.2.

### E3.F4.4 — Aviso de repetição recente nos looks (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F4-historico-de-looks/E3.F4.4-aviso-de-repeticao-recente.md](PBIs/E3-F4-historico-de-looks/E3.F4.4-aviso-de-repeticao-recente.md).

**Descrição**: cada card mostra "Usado hoje / ontem / há N dias" a partir do `historicoProvider`, em destaque quando o último uso foi há 7 dias ou menos. É o que atende "não repetir a mesma combinação sem perceber" no ponto de decisão.

**Critérios de aceite:**
- O rótulo reflete o uso mais recente do look; look nunca usado não mostra rótulo.
- Último uso há 7 dias ou menos aparece em destaque.
- Falha ao carregar o histórico não afeta a lista de looks.

**Status**: **concluída (validação manual end-to-end pendente)** — cada card mostra "Usado hoje" / "Usado ontem" / "Usado há N dias" (último uso do histórico), em cor de aviso quando o último uso foi há 7 dias ou menos; look nunca usado e histórico indisponível não mostram rótulo. `dart analyze` limpo; `flutter test` 101/101, com 11 testes novos desta PBI. Fluxo no Chrome com backend real ainda não conferido.
**Estimativa**: P.
**Dependências**: E3.F4.3.

## Épico 3, Feature 5 — Edição e exclusão de looks salvos

Feature completa = o usuário consegue tirar um look de Armário › Looks e trocar as peças de um look salvo, sem perder o histórico de uso. Pedida pelo usuário depois da reorganização da interface (2026-10-22). Excluir = **arquivar** (decisão do usuário): o look some da lista, mas os usos continuam no calendário e na rotação de peças.

### E3.F5.1 — Excluir (arquivar) look salvo (backend + mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F5-edicao-exclusao-looks/E3.F5.1-excluir-look.md](PBIs/E3-F5-edicao-exclusao-looks/E3.F5.1-excluir-look.md).

**Descrição**: migração `0011` (`looks.arquivado`), `DELETE /looks/{id}` arquiva; looks arquivados somem de `GET /looks` e das ações, mas os usos continuam no histórico. Item "Excluir" com confirmação no menu do card.

**Critérios de aceite:**
- `DELETE` → 204 e o look some da lista; outro usuário ou já arquivado → 404.
- Usos de look arquivado continuam no calendário; `PATCH`/usos nele → 404.
- No app, confirmação antes de excluir; cancelar não chama a API.

**Status**: **concluída (validação manual no Chrome pendente)** — migração `0011` aplicada; `DELETE /looks/{id}` arquiva (usos continuam no calendário e na rotação); item "Excluir" com confirmação. Verificado com a API real e dois usuários de teste (14/14); `pytest` 87; `flutter test` 219/219, com 5 testes novos.
**Estimativa**: M.
**Dependências**: E3.F1.3, E3.F4.1.

### E3.F5.2 — Trocar as peças de um look salvo (backend + mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E3-F5-edicao-exclusao-looks/E3.F5.2-trocar-pecas-do-look.md](PBIs/E3-F5-edicao-exclusao-looks/E3.F5.2-trocar-pecas-do-look.md).

**Descrição**: `PATCH /looks/{id}` aceita `peca_ids`; "Editar peças" no menu do card abre uma tela com carrosséis e as peças do look marcadas.

**Critérios de aceite:**
- `PATCH` com `peca_ids` troca as peças; lista vazia, `null` ou peça de outro usuário → 422; look de outro usuário → 404.
- No app, salvar atualiza o card; voltar sem salvar não chama a API.

**Status**: **concluída (validação manual no Chrome pendente)** — `PATCH /looks/{id}` aceita `peca_ids` (validados como no `POST`); tela "Editar peças" com carrosséis, filtros e as peças do look marcadas. Verificado com a API real e dois usuários de teste (9/9); `pytest` 91; `flutter test` 225/225, com 6 testes novos.
**Estimativa**: M.
**Dependências**: E3.F5.1, E5.F3.1.

## Épico 4, Feature 1 — Combinações de cores favoritas

Feature completa = usuário abre a tela de preferências (hoje só um `TODO` sem caminho até ela) e cadastra pares de cores que gosta de ver juntos. Esta feature também entrega a **base de todo o Épico 4**: a tabela `preferencias` (uma linha por usuário, já prevista em [arquitetura.md](arquitetura.md)) com todos os campos simples (cores, sobreposições, estilos, criatividade), para as features seguintes serem só telas. **Não inclui** peças/combinações evitadas (Feature 4, tabelas próprias) nem o uso das preferências nas sugestões (Épicos 5 e 6).

### E4.F1.1 — Modelo de preferências e endpoints `GET`/`PATCH` (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E4-F1-cores-favoritas/E4.F1.1-modelo-e-endpoints-de-preferencias.md](PBIs/E4-F1-cores-favoritas/E4.F1.1-modelo-e-endpoints-de-preferencias.md).

**Descrição**: tabela `preferencias` (migração `0007`) com `estilos`, `sobreposicoes`, `combinacoes_cores` e `criatividade`; `GET /preferencias` devolve os padrões quando nada foi salvo, e `PATCH /preferencias` atualiza só os campos enviados (upsert).

**Critérios de aceite:**
- Sem preferências salvas, `GET` devolve listas vazias e `criatividade: 3`, sem criar linha.
- `PATCH` normaliza listas (sem vazios nem repetidos) e preserva os campos não enviados.
- `criatividade` fora de 1–5, `null` em qualquer campo e par com a mesma cor nos dois lados dão 422.
- Cada usuário só vê e altera as próprias preferências.

**Status**: **concluída e validada** — tabela `preferencias` (migração `0007`, upgrade/downgrade testados), `GET /preferencias` (padrões sem gravar) e `PATCH /preferencias` (upsert atômico, parcial). Critérios de aceite verificados por execução real (API + Postgres local + `curl`, dois usuários, mais 5 primeiras chamadas simultâneas), sem suíte `pytest` ainda.
**Estimativa**: M.
**Dependências**: nenhuma.

### E4.F1.2 — Tela de preferências e combinações de cores favoritas (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E4-F1-cores-favoritas/E4.F1.2-tela-de-preferencias-e-cores-favoritas.md](PBIs/E4-F1-cores-favoritas/E4.F1.2-tela-de-preferencias-e-cores-favoritas.md).

**Descrição**: botão "Preferências de estilo" na Home abre a `PreferencesView` (hoje placeholder), que carrega as preferências e traz a seção de pares de cores, com salvamento imediato (atualização otimista com reversão em falha).

**Critérios de aceite:**
- A Home leva à tela de preferências.
- Adicionar um par de cores diferentes o mostra na lista e persiste; mesma cor nos dois lados ou par repetido (em qualquer ordem) é bloqueado.
- Remover um par persiste; falha no `PATCH` desfaz a mudança com mensagem clara.

**Status**: **concluída (validação manual end-to-end pendente)** — botão "Preferências de estilo" na Home, `PreferencesView` real (carregamento, erro com "Tentar novamente"), seção "Cores que combinam" com bottom sheet de duas cores e salvamento imediato com atualização otimista, reversão em falha e fila de gravações. `dart analyze` limpo; `flutter test` 114/114, com 13 testes novos. Fluxo no Chrome com backend real ainda não conferido.
**Estimativa**: M.
**Dependências**: E4.F1.1.

---

## Épico 4, Feature 2 — Preferência por sobreposições

Feature completa = usuário marca os tipos de sobreposição que gosta (jaqueta, cardigan, camisa aberta etc.). Nenhuma marcação significa "sem preferência". **Não inclui** efeito nas sugestões (Épicos 5 e 6).

### E4.F2.1 — Sobreposições preferidas na tela de preferências (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E4-F2-sobreposicoes/E4.F2.1-sobreposicoes-preferidas-na-tela.md](PBIs/E4-F2-sobreposicoes/E4.F2.1-sobreposicoes-preferidas-na-tela.md).

**Descrição**: seção "Sobreposições" com um chip por tipo (Jaqueta, Cardigan, Camisa aberta, Blazer, Colete), salva na hora; cria o widget genérico `SecaoDeChips` que a E4.F3.1 reaproveita.

**Critérios de aceite:**
- Marcar e desmarcar tipos persiste ao reabrir a tela.
- Nenhum tipo marcado é válido (sem preferência).
- Valor salvo fora da lista fixa continua aparecendo marcado.
- Falha no `PATCH` desfaz a marcação com mensagem clara.

**Status**: **concluída (validação manual end-to-end pendente)** — seção "Sobreposições" com `FilterChip`s de `sobreposicoesFixas`, salvamento imediato pelo `PreferenciasController`, valores fora da lista preservados; widget genérico `SecaoDeChips` pronto para a E4.F3.1. `dart analyze` limpo; `flutter test` 125/125, com 7 testes novos. Fluxo no Chrome com backend real ainda não conferido.
**Estimativa**: P.
**Dependências**: E4.F1.1, E4.F1.2.

---

## Épico 4, Feature 3 — Estilos preferidos

Feature completa = usuário escolhe os estilos que prefere (casual, streetwear, elegante, minimalista, esportivo etc.), usando a mesma lista do formulário de peça. **Não inclui** cruzamento com o `estilo` das peças (Épicos 5 e 6).

### E4.F3.1 — Estilos preferidos na tela de preferências (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E4-F3-estilos-preferidos/E4.F3.1-estilos-preferidos-na-tela.md](PBIs/E4-F3-estilos-preferidos/E4.F3.1-estilos-preferidos-na-tela.md).

**Descrição**: seção "Estilos preferidos" com um chip por item de `estilosFixos` (seleção múltipla, salva na hora), reaproveitando `SecaoDeChips`.

**Critérios de aceite:**
- Marcar vários estilos persiste ao reabrir a tela; desmarcar remove.
- Estilo salvo fora da lista fixa continua aparecendo marcado.
- Falha no `PATCH` desfaz a marcação com mensagem clara.

**Status**: **concluída (validação manual end-to-end pendente)** — seção "Estilos preferidos" (primeira da tela) com os seis `estilosFixos`, reaproveitando `SecaoDeChips` e `alternarNaLista`; o método de alternância da tela foi generalizado e serve estilos e sobreposições. `dart analyze` limpo; `flutter test` 130/130, com 5 testes novos. Fluxo no Chrome com backend real ainda não conferido.
**Estimativa**: P.
**Dependências**: E4.F1.1, E4.F2.1.

---

## Épico 4, Feature 4 — Peças ou combinações que o usuário evita

Feature completa = usuário marca peças que não quer ver sugeridas e pares de peças que não quer ver juntas. Diferente dos outros campos do épico, as sugestões (Épicos 5 e 6) devem tratar isto como **restrição**, não como peso ("nunca me sugira algo que eu não usaria"). Usa tabelas próprias com chave estrangeira para `pecas` (`ON DELETE CASCADE`, porque `excluir_peca` apaga fisicamente). **Não inclui** efeito em looks montados manualmente nem a aplicação da restrição nas sugestões.

### E4.F4.1 — Peças e combinações evitadas (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E4-F4-pecas-e-combinacoes-evitadas/E4.F4.1-pecas-e-combinacoes-evitadas-no-backend.md](PBIs/E4-F4-pecas-e-combinacoes-evitadas/E4.F4.1-pecas-e-combinacoes-evitadas-no-backend.md).

**Descrição**: tabelas `pecas_evitadas` e `combinacoes_evitadas` (migração `0009`, par ordenado por UUID) e endpoints para listar, marcar e desmarcar peças e pares, escopados por usuário.

**Critérios de aceite:**
- Marcar uma peça é idempotente (201 na primeira vez, 200 depois) e ela aparece em `GET /preferencias/evitadas`.
- O par `(A, B)` e o par `(B, A)` são o mesmo registro; par com a mesma peça nos dois lados dá 422.
- Peça inexistente ou de outro usuário dá 404.
- Excluir uma peça evitada (`DELETE /pecas/{id}`) remove também a peça e os pares dela da lista, sem erro.

**Status**: **concluída e validada** — tabelas `pecas_evitadas` e `combinacoes_evitadas` (migração `0009`, upgrade/downgrade testados, FKs com `ON DELETE CASCADE`) e os cinco endpoints em `/preferencias`. Critérios de aceite verificados por execução real (API + Postgres local + `curl`, dois usuários), incluindo excluir pelo armário uma peça evitada e em par. Sem suíte `pytest` ainda.
**Estimativa**: M.
**Dependências**: E4.F1.1.

### E4.F4.2 — Marcar peça como evitada no app (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E4-F4-pecas-e-combinacoes-evitadas/E4.F4.2-marcar-peca-evitada-no-app.md](PBIs/E4-F4-pecas-e-combinacoes-evitadas/E4.F4.2-marcar-peca-evitada-no-app.md).

**Descrição**: ação "Evitar nas sugestões" / "Parar de evitar" no detalhe da peça e seção "Peças que evito" na tela de preferências, com `evitadasProvider` e `Evitadas` já prontos para as combinações.

**Critérios de aceite:**
- Alternar no detalhe da peça marca e desmarca, com indicação visível.
- A tela de preferências lista as peças evitadas e permite remover.
- Falha de rede, 401 ou 404 mostra mensagem clara e mantém o estado anterior.
- Peça evitada excluída pelo armário some da seção.

**Status**: **concluída (validação manual end-to-end pendente)** — ação "Evitar nas sugestões" / "Parar de evitar" no detalhe da peça (com aviso "Evitada nas sugestões") e seção "Peças que evito" na tela de preferências (remoção com confirmação), com `evitadasProvider` e o modelo `Evitadas` já prontos para as combinações. `dart analyze` limpo; `flutter test` 141/141, com 11 testes novos. Fluxo no Chrome com backend real ainda não conferido.
**Estimativa**: M.
**Dependências**: E4.F4.1, E4.F1.2.

### E4.F4.3 — Combinações de peças evitadas no app (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E4-F4-pecas-e-combinacoes-evitadas/E4.F4.3-combinacoes-evitadas-no-app.md](PBIs/E4-F4-pecas-e-combinacoes-evitadas/E4.F4.3-combinacoes-evitadas-no-app.md).

**Descrição**: seção "Combinações que evito" com os pares salvos e `EscolherParView`, uma grade do armário onde se seleciona exatamente duas peças.

**Critérios de aceite:**
- O botão de confirmar só habilita com exatamente 2 peças selecionadas.
- O par salvo aparece com as duas miniaturas; o mesmo par em ordem inversa não duplica.
- Remover um par (com confirmação) o tira da lista.
- Armário com menos de 2 peças mostra orientação em vez da grade.

**Status**: **concluída (validação manual end-to-end pendente)** — seção "Combinações que evito" na tela de preferências (pares com as duas miniaturas, remoção com confirmação, 404 tratado como "já não existe") e `EscolherParView` (grade do armário, seleção local de exatamente duas peças, terceira bloqueada com aviso, par repetido avisado sem duplicar). `dart analyze` limpo; `flutter test` 152/152, com 11 testes novos. Fluxo no Chrome com backend real ainda não conferido. Com ela, a Feature 4 do Épico 4 está completa.
**Estimativa**: M.
**Dependências**: E4.F4.1, E4.F4.2.

---

## Épico 4, Feature 5 — Nível de criatividade desejado

Feature completa = usuário define, de 1 a 5, o quanto aceita sair do óbvio nas combinações sugeridas. O campo já existe na API (E4.F1.1); aqui é só o controle. **Não inclui** o efeito real nas sugestões (Épicos 5 e 6).

### E4.F5.1 — Nível de criatividade na tela de preferências (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E4-F5-nivel-de-criatividade/E4.F5.1-nivel-de-criatividade-na-tela.md](PBIs/E4-F5-nivel-de-criatividade/E4.F5.1-nivel-de-criatividade-na-tela.md).

**Descrição**: seção "Criatividade das combinações" com um `Slider` de 5 posições e rótulo por nível, salvo ao soltar (padrão 3).

**Critérios de aceite:**
- Sem preferência salva, o controle aparece no nível 3.
- Arrastar atualiza o rótulo sem chamar o servidor; soltar salva e persiste ao reabrir.
- Falha no `PATCH` devolve o controle ao nível anterior com mensagem clara.

**Status**: **concluída (validação manual end-to-end pendente)** — seção "Criatividade das combinações" com `Slider` de 5 níveis (rótulos em `niveisDeCriatividade`), valor local durante o arrasto e gravação só ao soltar; em falha volta ao nível anterior. `dart analyze` limpo; `flutter test` 159/159, com 7 testes novos — um deles pegou um bug real de reversão, corrigido. Fluxo no Chrome com backend real ainda não conferido. Com ela, todas as PBIs do Épico 4 estão implementadas.
**Estimativa**: P.
**Dependências**: E4.F1.1, E4.F1.2.

---

## Épicos 5 e 6 — Sugestões de looks

Escopo essencial aprovado em 2026-10-21. Regras do motor em [regras-sugestoes.md](regras-sugestoes.md) (fonte única). **Ordem de execução:** E5.F1.1 → E5.F1.2 → E6.F1.1 → E5.F2.1 → E6.F1.2 → E5.F2.2 / E5.F3.1 / E5.F4.1 — as PBIs independentes ficam por último para não atrasar o Épico 6. **Melhorias futuras (não autorizadas nesta etapa):** clima real (Open-Meteo, após confirmar condições de uso), acessórios, regra da tonalidade Clara, descarte permanente, otimizações de busca, GPS.

## Épico 5, Feature 1 — Motor de combinação por regras

Feature completa = backend gera, ordena e pagina looks válidos com as peças do usuário, respeitando filtros, restrições, cores e preferências, e expõe isso em `POST /sugestoes`. Sem IA.

### E5.F1.1 — Motor de combinação: regras (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E5-F1-motor-de-combinacao/E5.F1.1-regras-do-motor.md](PBIs/E5-F1-motor-de-combinacao/E5.F1.1-regras-do-motor.md).

**Descrição**: funções puras em `services/sugestoes/` para cores/ousadia, estrutura do look, filtros, restrições, coringas e peça-base; primeira suíte `pytest`.

**Critérios de aceite:**
- Ousadia e ajustes de tonalidade conforme a tabela de `regras-sugestoes.md`; exemplos revisados viram testes.
- Nenhum candidato com peça ou par evitado (exceto a peça-base), acima da ousadia máxima (exceto pares favoritos) ou com mais de 3 cores.
- Estrutura, coringa (máx. 1) e conflito da peça-base conforme as regras.

**Status**: **concluída** — pacote `app/services/sugestoes/` (cores, montagem) e primeira suíte `pytest` do projeto: 52 testes passando, incluindo os exemplos de cores revisados com a usuária.
**Estimativa**: M.
**Dependências**: nenhuma.

### E5.F1.2 — Ordenação, páginas e `POST /sugestoes` (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E5-F1-motor-de-combinacao/E5.F1.2-ordenacao-paginas-e-endpoint.md](PBIs/E5-F1-motor-de-combinacao/E5.F1.2-ordenacao-paginas-e-endpoint.md).

**Descrição**: ordenação determinística (critérios 1–6), páginas de 3 com cada peça em no máximo 2 looks, descartes da sessão, explicações e avisos; endpoint escopado pelo usuário.

**Critérios de aceite:**
- Mesma entrada, mesma resposta; páginas de até 3 looks com a regra de diversidade.
- 401 sem token, 404 para peça-base de outro usuário, 422 para página/descartes inválidos; lista vazia com motivo quando não há looks.
- Armário de ~100 peças responde em até 2 s.

**Status**: **concluída e validada** — ordenação, páginas, explicações/avisos e `POST /api/v1/sugestoes`. `pytest` 71/71 (100 peças em 0,62 s) e 19/19 verificações com API + Postgres reais, dois usuários.
**Estimativa**: M.
**Dependências**: E5.F1.1.

### E5.F1.3 — Não sugerir looks já salvos (backend + mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E5-F1-motor-de-combinacao/E5.F1.3-nao-sugerir-looks-salvos.md](PBIs/E5-F1-motor-de-combinacao/E5.F1.3-nao-sugerir-looks-salvos.md).

**Descrição**: `POST /sugestoes` deixa de devolver looks com o mesmo conjunto de peças de um look salvo; na aba Sugestões, salvar tira o card da lista e completa a página. O Look do dia não muda (decisão do usuário).

**Critérios de aceite:**
- Look salvo A+B nunca volta na aba Sugestões; A+B+casaco ainda pode aparecer.
- Salvar tira o card e ele não volta em "Ver outras" nem em nova busca; Look do dia inalterado.

**Status**: **concluída (validação manual no Chrome pendente)** — looks salvos entram como descartes em `POST /sugestoes`; salvar recarrega a página. Verificado com a API real (o look salvo do caso relatado não volta); `pytest` 87; `flutter test` 214/214.
**Estimativa**: P.
**Dependências**: E5.F1.2, E5.F2.1.

## Épico 5, Feature 2 — Sugestões sob demanda no app

### E5.F2.1 — Tela de sugestões (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E5-F2-sugestoes-no-app/E5.F2.1-tela-de-sugestoes.md](PBIs/E5-F2-sugestoes-no-app/E5.F2.1-tela-de-sugestoes.md).

**Descrição**: aba "IA" renomeada para "Sugestões"; filtros, 3 looks com explicação e avisos, "Ver outras", descartar (sessão) e salvar como "Look sugerido – dd/mm"; rótulos de criatividade atualizados.

**Critérios de aceite:**
- Sugerir, ver outras, descartar e salvar funcionam; look salvo aparece em "Meus looks".
- Erro mostra "Tentar novamente"; lista vazia mostra o motivo.

**Status**: **concluída (validação manual no Chrome pendente)** — aba "Sugestões" com filtros, 3 looks por vez, "Ver outras", descartar (sessão) e salvar; rótulos de criatividade novos. `dart analyze` limpo; `flutter test` 168/168, com 9 testes novos.
**Estimativa**: M.
**Dependências**: E5.F1.2.

### E5.F2.2 — Sugestões a partir de uma peça (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E5-F2-sugestoes-no-app/E5.F2.2-sugestoes-a-partir-de-uma-peca.md](PBIs/E5-F2-sugestoes-no-app/E5.F2.2-sugestoes-a-partir-de-uma-peca.md).

**Descrição**: "Montar looks com esta peça" no detalhe da peça; aviso de peça evitada; conflito com filtro mostrado com "Remover filtro".

**Critérios de aceite:**
- Todos os looks contêm a peça; peça evitada mostra aviso; conflito oferece remover o filtro.

**Status**: **concluída (validação manual no Chrome pendente)** — botão no detalhe da peça (oculto para acessórios) abre a tela de sugestões empilhada com a peça fixa e estado próprio; conflitos com "Remover filtro"; aviso de peça evitada. `dart analyze` limpo; `flutter test` 173/173, com 5 testes novos.
**Estimativa**: P.
**Dependências**: E5.F2.1.

## Épico 5, Feature 3 — Renomear looks salvos

### E5.F3.1 — Renomear look (backend + mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E5-F3-renomear-look/E5.F3.1-renomear-look.md](PBIs/E5-F3-renomear-look/E5.F3.1-renomear-look.md).

**Descrição**: `PATCH /looks/{id}` aceita `nome`; item "Renomear" no menu do card.

**Critérios de aceite:**
- Renomear persiste; nome vazio ou `null` → 422; look de outro usuário → 404.

**Status**: **concluída (validação manual do diálogo no Chrome pendente)** — `LookUpdate.nome` (vazio/só espaços/`null` → 422) e item "Renomear" no menu do card em Armário › Looks. Endpoint verificado com a API real e dois usuários (200/422/404); `pytest` 84 passed; `dart analyze` limpo; `flutter test` 194/194, com 5 testes novos.
**Estimativa**: P.
**Dependências**: nenhuma.

## Épico 5, Feature 4 — Aviso de peça com cadastro incompleto

### E5.F4.1 — Aviso de cadastro incompleto no armário (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E5-F4-cadastro-incompleto/E5.F4.1-aviso-de-cadastro-incompleto.md](PBIs/E5-F4-cadastro-incompleto/E5.F4.1-aviso-de-cadastro-incompleto.md).

**Descrição**: selo na miniatura e faixa no detalhe da peça sem cor, ocasião ou estilo, com atalho para editar.

**Critérios de aceite:**
- Peça incompleta mostra selo e faixa; peça só sem estação não; corrigir faz o aviso sumir.

**Status**: **concluída (validação visual no Chrome pendente)** — selo nas miniaturas do armário (tela principal e gavetas) e faixa "Cadastro incompleto: sem …" com "Editar" no detalhe; cor fora da lista fixa conta como sem cor, igual ao motor. `dart analyze` limpo; `flutter test` 203/203, com 9 testes novos.
**Estimativa**: P.
**Dependências**: nenhuma.

## Épico 6, Feature 1 — Look do dia com rotatividade de peças

Feature completa = a tela inicial mostra um look do dia sem o usuário pedir, para a ocasião lembrada (padrão Casual), priorizando peças pouco usadas ou esquecidas. Reaproveita o motor do Épico 5. **Não inclui** clima (adiado).

### E6.F1.1 — Look do dia e rotatividade (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E6-F1-look-do-dia/E6.F1.1-look-do-dia-e-rotatividade.md](PBIs/E6-F1-look-do-dia/E6.F1.1-look-do-dia-e-rotatividade.md).

**Descrição**: critério 5 em modo rotatividade (esquecidas, uso mais antigo, menor total); `POST /sugestoes/look-do-dia`; coluna `ocasiao_look_do_dia` em `preferencias` (migração `0010`).

**Critérios de aceite:**
- Peça esquecida vem antes; mesmo dia e ocasião = mesmo look; sem ocasião salva usa Casual.
- Migração reversível; `GET /preferencias` devolve o campo.

**Status**: **concluída e validada** — modo rotatividade no critério 5, `POST /api/v1/sugestoes/look-do-dia` e migração `0010`. `pytest` 78/78 e 18/18 verificações com API + Postgres reais, dois usuários.
**Estimativa**: M.
**Dependências**: E5.F1.2.

### E6.F1.2 — Card "Look do dia" na tela inicial (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E6-F1-look-do-dia/E6.F1.2-card-look-do-dia.md](PBIs/E6-F1-look-do-dia/E6.F1.2-card-look-do-dia.md).

**Descrição**: card na aba Casa com seletor de ocasião lembrado e ações "Salvar", "Usei hoje" (reaproveita `POST /looks` e `POST /looks/{id}/usos`) e "Outra sugestão".

**Critérios de aceite:**
- Look aparece ao abrir; ocasião lembrada entre sessões; "Usei hoje" registra no histórico sem duplicar o look.

**Status**: **concluída (validação manual no Chrome pendente)** — card no topo da Casa com seletor de ocasião (gravada nas preferências), "Outra sugestão", "Salvar" e "Usei hoje" (salva uma vez só e registra o uso; o calendário logo abaixo marca o dia). Contrato conferido com o backend real; `dart analyze` limpo; `flutter test` 214/214, com 11 testes novos.
**Estimativa**: M.
**Dependências**: E6.F1.1, E5.F2.1.

### E6.F1.3 — Look do dia que já é um look salvo (backend + mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E6-F1-look-do-dia/E6.F1.3-look-do-dia-ja-salvo.md](PBIs/E6-F1-look-do-dia/E6.F1.3-look-do-dia-ja-salvo.md).

**Descrição**: o look do dia continua podendo trazer um look salvo, mas o card mostra "Já salvo" (sem salvar de novo) e "Usei hoje" registra o uso no look existente. Pedido do usuário depois de salvar o mesmo look duas vezes.

**Critérios de aceite:**
- Look do dia igual a um salvo: "Já salvo" desabilitado e aviso; "Usei hoje" usa o look existente, sem criar outro.

**Status**: **concluída (validação manual no Chrome pendente)** — `look_salvo_id` em `POST /sugestoes/look-do-dia`; card com "Já salvo". Conferido com a API real; `pytest` 93; `flutter test` 242/242.
**Estimativa**: P.
**Dependências**: E6.F1.2, E5.F1.3, E3.F5.1.

---

## Épico 7, Feature 1 — Sugestão automática de metadados por IA (Gemma 3 via Ollama)

Primeira assistência de IA do cadastro: o Gemma 3 4B, rodando localmente via Ollama, olha a foto já sem fundo e sugere atributos; o usuário sempre revisa antes de salvar. Substitui os planos anteriores com Gemini e Llama (decisão de 2026-10-23; o Llama 4 Scout não cabe na memória do notebook).

### E7.F1.1 — Adaptador do Ollama (Gemma 3) e sugestão no processamento da foto (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E7-F1-metadados-por-ia/E7.F1.1-adaptador-ollama-backend.md](PBIs/E7-F1-metadados-por-ia/E7.F1.1-adaptador-ollama-backend.md).

**Descrição**: trocar o `gemini_adapter` (stub) por um `ollama_adapter` que chama o Gemma 3 no Ollama local e devolve categoria, subcategoria, cor e tonalidade sugeridas em `POST /pecas/processar-imagem`, com tempo limite e sugestão vazia em qualquer falha.

**Critérios de aceite:**
- Com o Ollama rodando, a resposta traz `sugestao` preenchida só com valores das listas fixas.
- Com o Ollama parado, lento ou respondendo lixo, a resposta continua 200, com `sugestao` vazia.

**Status**: **concluída (rota ponta a ponta ainda não exercitada)** — `ollama_adapter` no lugar do stub do Gemini; sugestão vazia em qualquer falha. `pytest` 104; testado com o Ollama real (7–13 s por foto).
**Estimativa**: M.
**Dependências**: E1.F1.2.

### E7.F1.2 — Formulário pré-preenchido com a sugestão da IA (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E7-F1-metadados-por-ia/E7.F1.2-formulario-pre-preenchido.md](PBIs/E7-F1-metadados-por-ia/E7.F1.2-formulario-pre-preenchido.md).

**Descrição**: levar a `sugestao` do processamento até o `PecaFormView`, pré-preencher os campos e avisar que foram sugeridos pela IA e devem ser revisados.

**Critérios de aceite:**
- Com sugestão, os campos vêm preenchidos e editáveis, com aviso "Sugerido pela IA — revise antes de salvar".
- Sem sugestão (IA falhou ou fallback sem remoção de fundo), o formulário abre vazio como hoje, sem aviso.

**Status**: **concluída (validação manual no Chrome pendente)** — `sugestao` levada até o `PecaFormView`, que pré-preenche os campos e mostra o aviso da IA. `flutter test` 247; `flutter analyze` limpo.
**Estimativa**: P.
**Dependências**: E7.F1.1, E1.F2.1.

---

## Épico 8 — Mural de referências (primeira etapa)

Decisões de 2026-10-23: o mural guarda imagens da galeria (sem `rembg`), mostradas numa grade e separáveis em coleções criadas pelo usuário; cada imagem tem nota opcional e pode ser ligada a um look salvo; o Gemma 3 (Ollama) sugere etiquetas das peças visíveis, só como texto. Sem link de origem. A comparação automática com o armário continua como evolução futura.

### Épico 8, Feature 1 — Mural básico

### E8.F1.1 — Referências do mural: tabela, upload e rotas (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F1-mural-basico/E8.F1.1-referencias-backend.md](PBIs/E8-F1-mural-basico/E8.F1.1-referencias-backend.md).

**Descrição**: tabela `referencias` por usuário e rotas para enviar a imagem da galeria, listar, editar a nota e excluir (apagando o arquivo).

**Critérios de aceite:**
- Imagem válida enviada aparece na listagem; arquivo inválido ou acima de 10 MB responde 422.
- Cada usuário vê, edita e exclui só as suas referências.

**Status**: **concluída** — tabela `referencias` (migração `0014`) e rotas `POST/GET/PATCH/DELETE /referencias`; `pytest` 120; testada com a API real.
**Estimativa**: M.
**Dependências**: Auth JWT e `storage_adapter` existentes.

### E8.F1.2 — Grade do mural e adicionar da galeria (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F1-mural-basico/E8.F1.2-grade-e-adicionar-da-galeria.md](PBIs/E8-F1-mural-basico/E8.F1.2-grade-e-adicionar-da-galeria.md).

**Descrição**: a aba Referências vira uma grade em duas colunas, com botão para adicionar da galeria (nota opcional) e visualização grande.

**Critérios de aceite:**
- Foto escolhida da galeria aparece no topo da grade.
- Mural vazio mostra mensagem e o botão Adicionar.

**Status**: **concluída (validação manual no Chrome pendente)** — aba Referências virou o mural: grade em duas colunas, adicionar da galeria com nota opcional e visualização com zoom. `flutter test` 259; `flutter analyze` limpo.
**Estimativa**: M.
**Dependências**: E8.F1.1.

### E8.F1.3 — Nota e exclusão da referência (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F1-mural-basico/E8.F1.3-nota-e-exclusao.md](PBIs/E8-F1-mural-basico/E8.F1.3-nota-e-exclusao.md).

**Descrição**: editar a nota e excluir a referência (com confirmação) na visualização.

**Critérios de aceite:**
- Nota editada persiste ao reabrir.
- Exclusão confirmada remove a imagem da grade.

**Status**: **concluída (validação manual no Chrome pendente)** — detalhe da referência com nota editável e exclusão com confirmação. `flutter test` 266; `flutter analyze` limpo.
**Estimativa**: P.
**Dependências**: E8.F1.1, E8.F1.2.

### Épico 8, Feature 2 — Coleções

### E8.F2.1 — Coleções de referências (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F2-colecoes/E8.F2.1-colecoes-backend.md](PBIs/E8-F2-colecoes/E8.F2.1-colecoes-backend.md).

**Descrição**: tabela `colecoes` com CRUD; cada referência em no máximo uma coleção; filtro por coleção na listagem.

**Critérios de aceite:**
- Nome repetido (sem diferenciar caixa) responde 409.
- Excluir a coleção mantém as referências, sem coleção.

**Status**: **concluída** — tabela `colecoes` (migração `0015`), rotas `/colecoes`, filtro por coleção em `GET /referencias` e mover pelo `PATCH`; `pytest` 137; testada com a API real.
**Estimativa**: M.
**Dependências**: E8.F1.1.

### E8.F2.2 — Aba de coleções no mural (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F2-colecoes/E8.F2.2-colecoes-no-mural.md](PBIs/E8-F2-colecoes/E8.F2.2-colecoes-no-mural.md).

**Descrição**: abas Todas/Coleções no mural, criar/renomear/excluir coleção, escolher a coleção ao adicionar e mover imagens.

**Critérios de aceite:**
- Imagem adicionada numa coleção aparece na grade dela e em Todas.
- Excluir a coleção não apaga as imagens.

**Status**: **concluída (validação manual no Chrome pendente)** — abas Todas/Coleções no mural, criar/renomear/excluir coleção, escolher a coleção ao adicionar e mover pelo detalhe. `flutter test` 275; `flutter analyze` limpo.
**Estimativa**: M.
**Dependências**: E8.F2.1, E8.F1.3.

### Épico 8, Feature 3 — Ligação a um look

### E8.F3.1 — Ligar a referência a um look salvo (backend + mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F3-ligar-a-look/E8.F3.1-ligar-referencia-a-look.md](PBIs/E8-F3-ligar-a-look/E8.F3.1-ligar-referencia-a-look.md).

**Descrição**: uma referência pode ser ligada a um look salvo; a visualização mostra o look e a grade um selo.

**Critérios de aceite:**
- Referência ligada mostra nome e peças do look.
- Look arquivado não aparece como ligado.

**Status**: **concluída (validação manual no Chrome pendente)** — `referencias.look_id` (migração `0016`), `PATCH` liga/desliga, detalhe mostra o look ligado (nome e peças) e a grade um selo. `pytest` 144; `flutter test` 283; `flutter analyze` limpo.
**Estimativa**: M.
**Dependências**: E8.F1.3, E3.F1.1.

### Épico 8, Feature 4 — Etiquetas por IA

### E8.F4.1 — Etiquetas das peças da referência por IA (backend + mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F4-etiquetas-por-ia/E8.F4.1-etiquetas-das-pecas-por-ia.md](PBIs/E8-F4-etiquetas-por-ia/E8.F4.1-etiquetas-das-pecas-por-ia.md).

**Descrição**: o Gemma 3 lista as peças visíveis na referência como etiquetas de texto editáveis, sem casar com o armário.

**Critérios de aceite:**
- Com o Ollama rodando, a referência nasce com etiquetas editáveis.
- Com o Ollama parado, a referência é salva sem etiquetas.

**Status**: **concluída (validação manual no Chrome pendente)** — o Gemma 3 sugere etiquetas das peças ao enviar a referência (`referencias.etiquetas`, migração `0017`); chips editáveis no detalhe. `pytest` 156; `flutter test` 292; `flutter analyze` limpo; testado com o Ollama real (5–12 s).
**Estimativa**: M.
**Dependências**: E8.F1.3, E7.F1.1.

---

### Épico 8, Feature 5 — Ligação automática: sugerir o look a partir da referência

Pedido de 2026-10-23: "Ligar a um look" ganha duas formas, manual e automática. No automático, as etiquetas da referência estreitam as peças candidatas do armário e o Gemma compara a imagem da referência com as fotos das peças, uma etiqueta por vez. O resultado reaproveita um look salvo, se algum contém as peças encontradas, ou propõe um look novo, sempre só com peças do usuário e com as lacunas explícitas. Substitui, para esta parte, o plano de embeddings e `pgvector` da segunda etapa do Épico 8.

### E8.F5.1 — Estreitar candidatos do armário a partir das etiquetas (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F5-ligacao-automatica/E8.F5.1-estreitar-candidatos-por-etiqueta.md](PBIs/E8-F5-ligacao-automatica/E8.F5.1-estreitar-candidatos-por-etiqueta.md).

**Descrição**: funções puras que, para cada etiqueta, descobrem categoria e cores e escolhem até 4 peças candidatas do armário (sem as evitadas); etiqueta sem equivalente vira lacuna.

**Critérios de aceite:**
- "calça jeans azul" traz as calças do armário, a azul de jeans primeiro; camiseta não entra.
- Sem peça da categoria, ou etiqueta não entendida, é lacuna explícita; peça evitada nunca aparece.

**Status**: **concluída** — `services/inspiracao/` com vocabulário e `estreitar`: categoria, cores e palavras da etiqueta viram até 4 candidatas do armário (sem as evitadas) ou uma lacuna explícita. `pytest` 213 (54 novos).
**Estimativa**: M.
**Dependências**: E8.F4.1, E4.F4.2.

### E8.F5.2 — Sugerir o look da referência comparando com o Gemma (backend)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F5-ligacao-automatica/E8.F5.2-sugerir-look-com-gemma.md](PBIs/E8-F5-ligacao-automatica/E8.F5.2-sugerir-look-com-gemma.md).

**Descrição**: `POST /referencias/{id}/sugestao-de-look`: o Gemma compara a imagem da referência com as candidatas de cada etiqueta; devolve look salvo que contém as peças, ou look novo, mais as lacunas.

**Critérios de aceite:**
- Só peças do usuário; etiqueta sem equivalente aparece em `lacunas`.
- Com o Ollama parado, 200 com `sem_pecas`; sem etiquetas, 422.

**Status**: **concluída** — `POST /referencias/{id}/sugestao-de-look`: o Gemma compara a referência com as candidatas de cada etiqueta e a rota devolve look salvo, look novo ou sem peças, mais as lacunas. `pytest` 251; testada com o Ollama real (35 s para 5 etiquetas, precisão média).
**Estimativa**: G.
**Dependências**: E8.F5.1, E8.F4.1, E8.F3.1.

### E8.F5.3 — "Ligar a um look": manual ou automático (mobile)

Detalhamento completo (descrição estendida, decisões técnicas, definição de pronto): [PBIs/E8-F5-ligacao-automatica/E8.F5.3-ligar-a-look-manual-ou-automatico.md](PBIs/E8-F5-ligacao-automatica/E8.F5.3-ligar-a-look-manual-ou-automatico.md).

**Descrição**: o botão "Ligar a um look" oferece Manual e Automático (IA); o automático mostra o look sugerido (salvo ou novo) com as lacunas e só liga ou salva depois do toque do usuário.

**Critérios de aceite:**
- Automático desabilitado sem etiquetas; look salvo vira "Ligar a este look"; look novo vira "Salvar como look e ligar".
- Lacunas sempre visíveis; nenhuma peça fora do armário.

**Status**: **concluída (validação manual no Chrome pendente)** — "Ligar a um look" oferece Manual e Automático (IA); o automático mostra o look sugerido (salvo ou novo) com as lacunas e só liga ou salva depois do toque. `flutter test` 340; `flutter analyze` limpo; contrato lido com a resposta real do backend.
**Estimativa**: M.
**Dependências**: E8.F5.2, E8.F3.1, E3.F1.1.

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
| E3.F2.1 | Campo favorito e `PATCH /looks/{id}` (backend) | Concluída e validada (execução real contra Postgres local) |
| E3.F2.2 | Favoritar looks e filtrar favoritos (mobile) | Concluída (validação manual visual no Chrome pendente) |
| E3.F3.1 | Campo ocasião no look (backend) | Concluída e validada (execução real contra Postgres local) |
| E3.F3.2 | Ocasião na montagem, no card e na edição (mobile) | Concluída (validação manual visual no Chrome pendente) |
| E3.F3.3 | Filtro de looks por ocasião (mobile) | Concluída (validação manual visual no Chrome pendente) |
| E3.F4.1 | Registro de uso e histórico de looks (backend) | Concluída e validada (execução real contra Postgres local) |
| E3.F4.2 | Registrar uso de um look (mobile) | Concluída (validação manual end-to-end pendente) |
| E3.F4.3 | Tela de histórico de looks utilizados (mobile) | Concluída (validação manual end-to-end pendente) |
| E3.F4.4 | Aviso de repetição recente nos looks (mobile) | Concluída (validação manual end-to-end pendente) |
| E3.F5.1 | Excluir (arquivar) look salvo (backend + mobile) | Concluída (validação manual no Chrome pendente) |
| E3.F5.2 | Trocar as peças de um look salvo (backend + mobile) | Concluída (validação manual no Chrome pendente) |
| E4.F1.1 | Modelo de preferências e endpoints `GET`/`PATCH` (backend) | Concluída e validada (execução real contra Postgres local) |
| E4.F1.2 | Tela de preferências e combinações de cores favoritas (mobile) | Concluída (validação manual end-to-end pendente) |
| E4.F2.1 | Sobreposições preferidas na tela de preferências (mobile) | Concluída (validação manual end-to-end pendente) |
| E4.F3.1 | Estilos preferidos na tela de preferências (mobile) | Concluída (validação manual end-to-end pendente) |
| E4.F4.1 | Peças e combinações evitadas (backend) | Concluída e validada (execução real contra Postgres local) |
| E4.F4.2 | Marcar peça como evitada no app (mobile) | Concluída (validação manual end-to-end pendente) |
| E4.F4.3 | Combinações de peças evitadas no app (mobile) | Concluída (validação manual end-to-end pendente) |
| E4.F5.1 | Nível de criatividade na tela de preferências (mobile) | Concluída (validação manual end-to-end pendente) |
| E5.F1.1 | Motor de combinação: regras (backend) | Concluída (`pytest`, 52 testes) |
| E5.F1.2 | Ordenação, páginas e `POST /sugestoes` (backend) | Concluída e validada (`pytest` + execução real contra Postgres local) |
| E5.F1.3 | Não sugerir looks já salvos (backend + mobile) | Concluída (validação manual no Chrome pendente) |
| E5.F2.1 | Tela de sugestões (mobile) | Concluída (validação manual no Chrome pendente) |
| E5.F2.2 | Sugestões a partir de uma peça (mobile) | Concluída (validação manual no Chrome pendente) |
| E5.F3.1 | Renomear look (backend + mobile) | Concluída (validação manual do diálogo no Chrome pendente) |
| E5.F4.1 | Aviso de cadastro incompleto no armário (mobile) | Concluída (validação visual no Chrome pendente) |
| E6.F1.1 | Look do dia e rotatividade (backend) | Concluída e validada (`pytest` + execução real contra Postgres local) |
| E6.F1.2 | Card "Look do dia" na tela inicial (mobile) | Concluída (validação manual no Chrome pendente) |
| E6.F1.3 | Look do dia que já é um look salvo (backend + mobile) | Concluída (validação manual no Chrome pendente) |
| E7.F1.1 | Adaptador do Ollama (Gemma 3) e sugestão no processamento da foto (backend) | Concluída (rota ponta a ponta não exercitada) |
| E7.F1.2 | Formulário pré-preenchido com a sugestão da IA (mobile) | Concluída (validação manual pendente) |
| E8.F1.1 | Referências do mural: tabela, upload e rotas (backend) | Concluída (`pytest` + API real) |
| E8.F1.2 | Grade do mural e adicionar da galeria (mobile) | Concluída (validação manual no Chrome pendente) |
| E8.F1.3 | Nota e exclusão da referência (mobile) | Concluída (validação manual no Chrome pendente) |
| E8.F2.1 | Coleções de referências (backend) | Concluída (`pytest` + API real) |
| E8.F2.2 | Aba de coleções no mural (mobile) | Concluída (validação manual no Chrome pendente) |
| E8.F3.1 | Ligar a referência a um look salvo (backend + mobile) | Concluída (validação manual no Chrome pendente) |
| E8.F4.1 | Etiquetas das peças da referência por IA (backend + mobile) | Concluída (validação manual no Chrome pendente) |
| E8.F5.1 | Estreitar candidatos do armário a partir das etiquetas (backend) | Concluída (`pytest`) |
| E8.F5.2 | Sugerir o look da referência comparando com o Gemma (backend) | Concluída (`pytest` + Ollama real; precisão média) |
| E8.F5.3 | "Ligar a um look": manual ou automático (mobile) | Concluída (validação manual no Chrome pendente) |

E1.F1.1 a E1.F3.1 têm o código escrito, testado (onde há suíte automatizada) e revisado — falta a validação manual visual/end-to-end (Chrome + backend real rodando juntos, incluindo `rembg` de verdade), que exige interação humana e um ambiente Python completo, nenhum dos dois disponível nesta sessão. O trabalho restante é a E1.F1.5 (testes automatizados do backend) e a validação manual acumulada de todo o fluxo (cadastro → armário → edição/exclusão).
