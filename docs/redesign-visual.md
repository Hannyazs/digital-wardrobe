# Redesign visual do front-end (mobile)

Plano de adaptação do app Flutter pra seguir a identidade visual do Figma "VIRTUALASSIST" (tela de montagem de looks, `docs/figma-reference/catalogo_looks_screen.png`), em etapas pequenas e testáveis. Front-end/UI apenas — nenhuma mudança de backend, dados ou lógica de negócio.

**Status**: Etapas 0–6 concluídas. Todas as telas existentes foram adaptadas à identidade visual do Figma; navegação de 5 abas funcionando. Verificado após cada etapa (`dart analyze` limpo, `flutter test` sem regressão — baseline estável em 36/39, mesmas 3 falhas pré-existentes de `peca_form_test.dart`, não relacionadas ao redesign). Validação manual visual no Chrome ainda pendente (não executável nesta sessão).

## Decisões já tomadas

- **Escopo**: só UI (cores, tipografia, componentes, navegação). Modelos, serviços, controllers/providers e o backend não mudam.
- **Navigation bar**: vai de 2 para 5 abas — Casa, Armário, Criação de Looks (central, destaque), IA/Sugestões (placeholder), Referências (placeholder).
- **Looks salvos**: a aba central "Criação de Looks" abre direto em `MontarLookView` (a tela de referência); "Meus looks" (listagem atual, `LooksView`) vira uma aba/toggle secundário dentro dessa mesma área, não uma 6ª aba.
- **Login/Preferências**: `LoginView`/`PreferencesView` continuam como placeholders órfãos (não fazem parte do escopo deste redesign).

## Etapas

| # | O que entra | Status |
|---|---|---|
| 0 | `AppColors` + `AppTextStyles` + `AppTheme` reescrito | ✅ Concluída |
| 1 | Componentes novos: `AppButton`, `ClothingCard`, `CategorySection`, `ScreenHeader`, `FilterButton` | ✅ Concluída (`core/widgets/`) |
| 2 | Restyle de `MontarLookView` (tela de referência) com os componentes da Etapa 1 | ✅ Concluída |
| 3 | Restyle do `WardrobeView` (armário) — carrosséis por categoria em vez de grade | ✅ Concluída |
| 4 | `HomeShell` com 5 abas (Casa, Armário, Looks, IA, Referências) + `HomeView`/`SuggestionsView`/`ReferencesView` novos + "Meus looks" como botão dentro da aba Looks | ✅ Concluída |
| 5 | Restyle de `UploadView`/`PecaFormView`/`PecaDetailView` | ✅ Concluída |
| 6 | ~~Remover `CatalogoLookMockView` e o atalho temporário em `LooksView`~~ | ✅ Concluída (antecipada) |
| 7 | Reorganização: gavetas no armário, looks salvos no Armário, calendário na Casa, filtros múltiplos em painel | ✅ Concluída (validação visual pendente) — ver seção própria abaixo |
| 8 | Revisão de UX e acessibilidade (textos, leitor de tela, contraste, área de toque, formulário, montagem) | ✅ Concluída (validação visual pendente) — ver seção própria abaixo |

**Pendente**: validação manual visual no Chrome/emulador (comparar com o Figma na prática) — não executável nesta sessão, requer interação humana num navegador/dispositivo real.

## O que não mexer

- `models/`, `services/`, `*Controller`/`*Provider` — lógica já implementada e testada (E1.F1 → E3.F1.3).
- Backend (rotas, schemas, migrações).
- `api_client.dart`/autenticação.

## Decisões tomadas durante a implementação

- **FilterButton em `MontarLookView` é só visual** — essa tela não tinha (nem tem) filtro de peças implementado; tocar no botão mostra um aviso "ainda não disponível", em vez de fingir uma funcionalidade que não existe.
- **Filtro do armário continua sempre visível** (não virou um painel escondido atrás do `FilterButton`) — transformar isso num toggle mudaria a interação de uma funcionalidade já pronta e testada (E2.F2.1), o que vai contra "preservar o que já funciona".
- **"Meus looks" é um botão no AppBar de `MontarLookView`** (ícone de favoritos), não uma sub-aba com toggle — mais simples de implementar sem aninhar `Scaffold`s, e reaproveita o mesmo padrão de navegação por `Navigator.push` já usado em todo o app.
- **Bug real corrigido no caminho**: `google_fonts` tentava baixar fontes pela rede durante os testes, causando flakiness entre arquivos quando rodados em paralelo (ex: timers pendentes derrubando `pumpAndSettle` em testes sem relação nenhuma com o redesign). Corrigido com `test/flutter_test_config.dart`, desabilitando `GoogleFonts.config.allowRuntimeFetching` nos testes — fix padrão documentado pelo próprio pacote, não um workaround improvisado.
- **App agora abre na aba "Casa"**, não mais direto no armário — mudança de comportamento intencional pedida pelo usuário ("CASA - tela inicial/Home"). Vários testes que assumiam o armário como tela inicial do `HomeShell` foram ajustados para navegar até a aba Armário explicitamente antes de verificar.
- **Ajustes pós-entrega (pedido do usuário)**: título da Home trocado de "Morning, Mo!" para "Welcome!"; `ScreenHeader` ganhou um parâmetro `acao` opcional (ícone no canto superior direito do próprio degradê) e `MontarLookView` perdeu a `AppBar` separada — "Meus looks" virou essa `acao`, junto com um botão de voltar condicional (`Navigator.canPop`) pra não perder a navegação quando a tela é empurrada a partir da Home. Isso resolveu o degradê sendo empurrado pra baixo por uma barra vazia. `WardrobeView` também passou a usar `ScreenHeader` no lugar da `AppBar` simples, pra herdar a tipografia/degradê que faltava nela.

## Etapa 7 — Reorganização da navegação e dos filtros (2026-10-22)

Pedido do usuário, feito antes das PBIs pendentes dos Épicos 5 e 6 (E5.F3.1, E5.F4.1, E6.F1.2), que não dependem dela nem a bloqueiam. Substitui as decisões acima sobre "Meus looks" dentro da montagem e sobre o filtro do armário sempre visível.

**Navegação**
- **Casa**: atalhos + **calendário de looks usados** (`CalendarioDeLooks`, antes a tela `HistoricoView` aberta pelos looks salvos; `historico_view.dart` → `calendario_de_looks.dart`, mesmas funções). O card "Look do dia" (E6.F1.2) entra no topo, acima dos atalhos.
- **Armário**: seletor **Peças | Looks**. "Looks" é a mesma `LooksView` de antes, sem `AppBar` própria nem atalho de histórico — looks prontos ficam junto das peças.
- **Looks (aba central)**: só a montagem de um look novo; o botão "Meus looks" saiu.

**Gavetas do armário** (decisão do usuário: agrupar as categorias atuais, sem criar novas)
- Partes de cima (Camisetas, Camisas, Blusas, Regatas, Suéteres), Partes de baixo (Calças, Shorts, Saias), Vestidos, Macacões, Casacos, Sapatos, Acessórios, e "Outras" para categoria fora da lista. Mesmos grupos do motor de sugestões (`backend/.../tipos.py`). Definidas em `gavetasDoArmario` (`peca_opcoes.dart`).
- Tela principal: uma seção por gaveta com carrossel; tocar no nome abre `GavetaView`, com um carrossel por categoria ou, na gaveta de uma categoria só, por subcategoria (campo livre do cadastro; sem subcategoria → seção com o nome da categoria).
- Montagem: um carrossel por categoria direto na tela (sem gavetas), na mesma ordem.

**Carrosséis**: `CategorySection` acrescenta cards brancos esmaecidos depois dos itens até passar da largura da tela, para a fileira ter cara de carrossel mesmo com uma ou duas peças.

**Filtros** (decisão do usuário: OU dentro do mesmo critério, E entre critérios; "Todas as estações" aparece em qualquer estação filtrada, como no motor de sugestões)
- Painel por baixo (`abrirPainelDeFiltros`, `core/widgets/painel_de_filtros.dart`) aberto pelo `FilterButton` — agora um ícone de linhas com selo da quantidade marcada. Cada toque aplica na hora; "Limpar tudo"; botão "Ver N peças/looks" fecha.
- Armário e gavetas: cor, estação e ocasião com seleção múltipla (`FiltroPecas`, compartilhado entre armário e gavetas). Opções só com valores que existem nas peças (antes a ocasião listava todas as fixas) — valores marcados sempre aparecem, para poderem ser desmarcados.
- Montagem: mesmo filtro, estado próprio (`filtroMontagemProvider`); peças selecionadas continuam selecionadas mesmo que um filtro as esconda. Antes o botão só mostrava "ainda não disponível". O seletor de ocasião da montagem ganhou o rótulo "Ocasião do look (opcional)" para não ser confundido com filtro.
- Looks salvos: favoritos + ocasiões (já eram múltiplos) foram para o mesmo painel; ocasiões só as que algum look tem.
- Sugestões: filtros continuam de seleção única (dropdowns) — o `POST /sugestoes` aceita um valor por critério; múltiplos exigiriam mudar o backend e o motor, fora do escopo.

**Bugs pré-existentes corrigidos no caminho (montagem como aba)**: salvar chamava `Navigator.pop()` mesmo sem tela por baixo, e nome/seleção não eram limpos depois de salvar. Agora volta só quando aberta por cima de outra tela; como aba, limpa nome, peças, ocasiões e filtros. Com a montagem aberta pela Casa por cima da aba, só a tela visível reage ao salvar (antes a mensagem saía duas vezes).

**Verificação**: `dart analyze` limpo; `flutter test` 189/189 (eram 173; testes de armário, looks, montagem, calendário e cadastro ajustados à navegação nova, mais testes novos de filtros múltiplos, gavetas, espaços do carrossel e salvar pela aba). Validação visual no Chrome pendente.

## Etapa 8 — Revisão de UX e acessibilidade (2026-10-22)

Revisão de UI/UX pedida pelo usuário, sem mudar a identidade visual (paleta, fontes e componentes mantidos); recomendações aprovadas e implementadas em três lotes. Itens numerados conforme a revisão.

**Lote 1 — textos e rótulos**
- (1) Aba central "Looks" → **"Montar"** (os looks salvos são Armário › Looks; dois "Looks" confundiam).
- (2) Títulos em português: Casa "Olá! / Vamos escolher o que vestir.", Sugestões "Suas sugestões / Looks montados só com as suas peças.", Referências "Inspirações / Em breve" (também cobre o item 21).
- (8) Cadastro: "Cor" → **"Cor principal"** com a dica "A cor que mais aparece na peça." — o modelo e o motor têm uma cor só; peças com mais de uma cor seriam uma PBI nova (não feita).
- (11) Resultado sem remoção de fundo: "você pode ajustar isso depois" (promessa falsa — a foto é imutável) → "A peça será salva com o fundo original da foto."
- (13) Aba Sugestões vazia só por looks salvos: mensagem própria (ver E6.F1.3).
- (18) Armário vazio: "Toque em +" → "Toque no botão de câmera…" (o botão mostra uma câmera).
- (19) Título do formulário de cadastro "Detalhes da peça" → "Dados da peça" (quase igual ao "Detalhe da peça" de leitura); "Adicionar Peça" → "Adicionar peça".
- (20) Cabeçalho "Meu Guarda-Roupa" → "Meu Armário" (mesmo nome da aba).

**Lote 2 — acessibilidade**
- (3) `ClothingCard.rotulo`: o leitor de tela anuncia a peça ("Calças, jeans, preto", via `descricaoPeca`) e, na montagem/edição, se está selecionada. `PecasDoLook` vira uma frase só ("Peças: …"). Espaços vazios do carrossel ficam fora da leitura.
- (5) Título da gaveta com área de toque mínima de 48 px (antes ~24) e "Ver tudo" ao lado da seta.
- (6) `AppColors.sageEscuro` (#619385, o mesmo verde mais escuro): borda dos campos 3,5:1 (antes 1,3:1) e foco mais grosso; anel de "hoje" e marcação do calendário também.
- (7) Texto de apoio (`bodySmall`) passa de cursiva (Caveat) para `AppTextStyles.legenda` (fonte de corpo, 12,5, cinza). A cursiva continua nas frases decorativas do cabeçalho.
- (14) `FilterButton` com ícone **e** texto "Filtros" (+ selo); leitor de tela: "Filtros, N marcados".
- (17) Fonte grande do sistema: fileira de ocasiões da montagem sem altura fixa; célula do calendário com altura mínima e número que encolhe dentro do círculo. Testes com texto 2× sem estouro.

**Lote 3 — fluxos**
- (4) Cadastro: tocar "Salvar peça" com erro rola até o campo e mostra "Revise o campo destacado.".
- (9) Cadastro: linha "Cor, ocasião e estilo ajudam nas sugestões de looks." e dicas "Sugerida pela cor; você pode trocar." / "Pode marcar várias.".
- (10) Cadastro: subcategorias já usadas na categoria aparecem como atalhos; na gaveta, "Midi" e "midi" viram uma seção só.
- (12) Montagem: fileira com as miniaturas escolhidas e o motivo do "Salvar look" desabilitado ("Escolha as peças e dê um nome ao look." etc.).
- (15) Detalhe da peça: "Evitar nas sugestões" / "Parar de evitar" virou botão com texto no corpo (antes, ícone na barra).
- (16) Card de look salvo: tocar no card abre o mesmo menu do "⋮".
- `PecasDoLook` rola na horizontal (looks com muitas peças não estouram a largura).

**Não feito:** (22) nome do look depois das peças na montagem — opcional; o campo no rodapé ficaria escondido pelo teclado. Peças com várias cores — exige PBI própria (banco + motor).

**Verificação**: `dart analyze` limpo; `flutter test` **242/242** (14 testes novos em `acessibilidade_e_ux_test.dart`: rótulos do leitor de tela, selecionada/não, botão de filtros, área de toque ≥ 48, subcategorias, texto 2× em Casa/Armário/Montar/Montagem/Looks, formulário, montagem, toque no card, textos). Testes antigos ajustados aos textos novos. Validação visual no Chrome pendente.

## Aviso permanente

Testes existentes que fazem `find.text(...)`/`find.byType(...)` sobre textos ou widgets visuais (ex: `FilterChip`, "Salvar look") podem precisar de ajuste de uma linha quando a etapa correspondente trocar esse texto/widget — não é regressão de funcionalidade, é manutenção esperada de teste. Cada etapa que tocar uma tela com testes existentes vai rodar `flutter test` e reportar o que precisou ajustar.
