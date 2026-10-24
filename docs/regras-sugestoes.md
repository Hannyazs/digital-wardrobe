# Regras do motor de sugestões

Fonte única das regras do motor de combinação (Épico 5), reaproveitado pelo look do dia (Épico 6). Aprovadas com a usuária em 2026-10-21. Outros documentos apontam para cá em vez de repetir as regras. Ver [requisitos.md](requisitos.md) e [backlog.md](backlog.md).

O motor é determinístico: a mesma entrada (armário, preferências, filtros, página, descartes) gera sempre o mesmo resultado. Nenhum modelo de IA é chamado.

## 1. Cores

**Neutros:** Preto, Branco, Cinza, Bege, Marrom, Azul-marinho.

**Roda de famílias** (as demais cores de `coresFixas`, em `mobile/lib/core/constants/peca_opcoes.dart`):

Vermelho (Vermelho, Vinho, Rosa) → Laranja → Amarelo → Verde → Azul (Azul, Azul-claro) → Roxo → volta ao Vermelho.

**Ousadia de um par de peças:**

| Situação | Ousadia |
| --- | --- |
| Neutro com qualquer cor | 0 |
| Mesma cor | 0 |
| Mesma família, cores diferentes | 1 |
| Famílias vizinhas na roda | 2 |
| Famílias a duas posições | 3 |
| Famílias opostas | 4 |

Tabela resultante entre cores não neutras:

| | Vinho | Rosa | Laranja | Amarelo | Verde | Azul | Azul-claro | Roxo |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Vermelho** | 1 | 1 | 2 | 3 | 4 | 3 | 3 | 2 |
| **Vinho** | | 1 | 2 | 3 | 4 | 3 | 3 | 2 |
| **Rosa** | | | 2 | 3 | 4 | 3 | 3 | 2 |
| **Laranja** | | | | 2 | 3 | 4 | 4 | 3 |
| **Amarelo** | | | | | 2 | 3 | 3 | 4 |
| **Verde** | | | | | | 2 | 2 | 3 |
| **Azul** | | | | | | | 1 | 2 |
| **Azul-claro** | | | | | | | | 2 |

**Tonalidade:**
- Pastel + Pastel ou Escura + Escura: −1 na ousadia do par. Entre cores diferentes, o mínimo é 1.
- Peça de cor não neutra com tonalidade "Neutra" conta como neutra.
- Peça sem tonalidade usa a tonalidade sugerida da cor (`tonalidadeSugeridaPara`).
- Nenhuma outra combinação de tonalidades altera a ousadia.

**Look:**
- Ousadia do look = maior ousadia entre os seus pares (pares favoritos contam como quaisquer outros).
- Ousadia máxima permitida = criatividade − 1 (criatividade 1 a 5).
- No máximo **3 cores não neutras** por look, contadas por nome (cor repetida conta uma vez), em qualquer criatividade.
- **Par de cores favorito** (preferências): **não passa da ousadia máxima** — a régua de criatividade manda (decisão de 2026-10-23; antes o par favorito furava o limite, e em "Neutros + uma cor" ainda saíam looks com duas cores vivas). Entre os looks que cabem no nível, o par favorito só ajuda a ordenar (critério 1) e aparece na explicação. Também não libera o limite de 3 cores, nem peças ou pares evitados.
- Cor fora da lista fixa (texto livre antigo) é tratada como peça sem cor.
- **Peça multicolorida** (cor predominante em `cor_principal` + `cores_secundarias`): conta como uma peça de cada uma das suas cores. O motor avalia cada cor (regras de ousadia, limite de 3 cores e filtro de cor valem para a cor avaliada) e o mesmo look sai uma só vez, com a cor que dá a menor ousadia. Decisão de 2026-10-23.

**Rótulos da criatividade:** 1 Neutros + uma cor · 2 Tom sobre tom · 3 Cores vizinhas · 4 Cores contrastantes · 5 Cores opostas.

## 2. Estrutura do look

- Parte de cima (Camisetas, Camisas, Blusas, Regatas ou Suéteres) + parte de baixo (Calças, Shorts ou Saias) + Sapatos; **ou** Vestido/Macacão + Sapatos.
- Se nenhum sapato é compatível com a base, o look sai sem sapato e com o aviso "falta calçado".
- Casaco (Casacos) entra só com filtro de estação Outono/Inverno ou com alguma sobreposição preferida marcada.
- Acessórios não entram.

## 3. Filtros e restrições

- **Ocasião / estilo:** a peça precisa ter o valor escolhido (ocasiões e estilos aceitam vários valores; basta um bater); sem o campo, entra como coringa.
- **Estação:** a peça pode ter várias estações; basta uma delas ser a escolhida. "Todas as estações" ou nenhuma estação marcada servem para qualquer pedido (estação vazia nunca é penalizada).
- **Cor:** pelo menos uma peça do look tem a cor escolhida.
- **Peças e pares evitados** nunca entram. Única exceção: a **peça-base** escolhida pelo usuário, se estiver evitada, entra com aviso — a exceção não vale para outras peças nem para pares evitados.
- **Peça-base:** está em todos os looks. Se ela tem o campo preenchido com valor diferente de um filtro ativo (ocasião, estilo ou estação), não há looks: a resposta informa o conflito e o app oferece remover o filtro.

## 4. Peças incompletas

- **Incompleta:** sem cor, sem ocasião ou sem estilo. Sempre recebe o aviso "cadastro incompleto", independentemente dos filtros.
- **Coringa:** peça sem cor, ou sem ocasião/estilo quando o filtro correspondente está ativo. **No máximo 1 coringa por look.**
- Peça sem cor não entra no cálculo de ousadia nem no limite de cores.

## 5. Ordenação

Comparação critério a critério; o seguinte só desempata o anterior.

| # | Critério | Medida | Melhor |
| --- | --- | --- | --- |
| 1 | Par de cores favorito | Pares favoritos distintos presentes | Maior |
| 2 | Cadastro completo | Peças incompletas | Menor |
| 3 | Estilos preferidos | Peças com algum estilo preferido | Maior |
| 4 | Coerência de estilo | Estilos distintos entre as peças (1 se todas compartilham um estilo) | Menor |
| 5 | Menor uso | Total de usos das peças (Épico 6: peças esquecidas e uso mais antigo primeiro) | Menor |
| 6 | Ousadia | Distância até a ousadia máxima | Menor |
| — | Desempate final | IDs das peças em ordem | Menor |

**Uso de uma peça** = registros em `looks_usos` de looks que contêm a peça. **Esquecida** (Épico 6) = nunca usada ou sem uso há mais de 30 dias.

## 6. Páginas e descartes

- 3 looks por página; cada peça aparece em no máximo 2 looks da mesma página. Looks pulados por essa regra ficam para as próximas páginas.
- Looks descartados valem só durante a sessão: o app os envia no pedido e eles ficam de fora.
- **Looks já salvos não voltam nas sugestões sob demanda** (E5.F1.3): look com exatamente as mesmas peças de um look salvo do usuário fica de fora, como um descarte permanente. O mesmo look com uma peça a mais (ex.: + casaco) ainda pode aparecer. Não vale para o look do dia, que pode trazer um look salvo (a rotatividade já evita repetição recente) — mas aí o app mostra que ele já está salvo e não deixa salvar de novo (E6.F1.3). Lista vazia só por causa de looks salvos tem mensagem própria.
- O motor avalia no máximo 20.000 looks candidatos por pedido (configurável), descartando combinações inválidas enquanto monta. Para armários do tamanho esperado (dezenas de peças) o limite não é atingido; acima dele, algumas combinações podem não ser avaliadas.

## 7. Fora desta versão

Clima real, acessórios, regra própria para a tonalidade Clara, descarte permanente, otimizações de busca e localização por GPS ficam como melhorias futuras.
