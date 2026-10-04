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

## Aviso permanente

Testes existentes que fazem `find.text(...)`/`find.byType(...)` sobre textos ou widgets visuais (ex: `FilterChip`, "Salvar look") podem precisar de ajuste de uma linha quando a etapa correspondente trocar esse texto/widget — não é regressão de funcionalidade, é manutenção esperada de teste. Cada etapa que tocar uma tela com testes existentes vai rodar `flutter test` e reportar o que precisou ajustar.
