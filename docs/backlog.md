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

## Resumo do estado atual

| PBI | Descrição curta | Status |
| --- | --- | --- |
| E1.F1.1 | Captura/seleção de foto (mobile) | Concluída (validação visual manual pendente) |
| E1.F1.2 | Endpoint de remoção de fundo (backend) | Concluída (tratamento de erro e validação com imagem real já feitos — ver arquivo detalhado) |
| E1.F1.3 | Integração envio + exibição (mobile) | Concluída (validação visual manual e teste contra backend real pendentes) |
| E1.F1.4 | Degradação no app quando processamento falha | Concluída (execução real do endpoint novo e validação visual manual pendentes) |
| E1.F1.5 | Testes automatizados | Não iniciado |

E1.F1.1 a E1.F1.4 têm o código escrito, testado (onde há suíte automatizada) e revisado — falta a validação manual visual/end-to-end (Chrome + backend real rodando juntos, incluindo `rembg` de verdade), que exige interação humana e um ambiente Python completo, nenhum dos dois disponível nesta sessão. O trabalho restante é a E1.F1.5 (testes automatizados do backend) e a validação manual acumulada de toda a feature.
