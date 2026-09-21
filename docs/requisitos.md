# Documento de Requisitos — Guarda-Roupa Virtual

Épicos, features e histórias de usuário, organizados na ordem de implementação — não na ordem em que as features aparecem no [Documento de Visão](visao.md). A ordem aqui reflete duas coisas: dependência técnica (cada épico assume que os anteriores já existem) e uma decisão de produto — **toda sugestão de IA fica para depois que a base da aplicação (cadastro, organização, looks manuais) já estiver funcionando**. Ver [Documento de Arquitetura](arquitetura.md) para como cada um se encaixa no sistema.

A persona usada nas histórias é a Marina, definida no Documento de Visão — mas nenhuma história pressupõe conhecimento de moda, propositalmente.

Quando uma feature é quebrada em PBIs pra execução do time, essa quebra vive em [backlog.md](backlog.md), não aqui — este documento fica no nível de feature/história, mais estável.

## Requisitos não-funcionais

- **Privacidade**: fotos de peças e preferências são dados pessoais — todo dado é escopado por `usuario_id`, derivado do JWT, nunca do corpo da requisição (ver CLAUDE.md, seção Auth). Nenhuma busca (inclusive por similaridade vetorial) pode vazar dados entre usuários.
- **Idioma**: interface e mensagens em português. Código e nomes técnicos em inglês.
- **Disponibilidade**: sem requisito de SLA formal no MVP — é aceitável indisponibilidade eventual durante a fase de validação.
- **Resiliência de IA**: nenhuma chamada a serviço de IA (Gemini) pode derrubar um fluxo do usuário — falha na extração de metadados degrada para preenchimento manual, nunca para erro fatal.

## Base da aplicação (sem IA)

Os três primeiros épicos entregam um produto funcional usando apenas CRUD e regras determinísticas — nenhum depende de Gemini ou de qualquer sugestão automática. A remoção de fundo (`rembg`) é uma exceção deliberada: embora use um modelo de visão computacional por baixo, não é uma *sugestão* sujeita ao julgamento do usuário (não há "certo" ou "errado" em remover o fundo de uma foto), por isso permanece no Épico 1 em vez de ser adiada com o resto.

### Épico 1 — Cadastro de roupas (manual)

Base de todo o resto do produto: sem peças cadastradas, nenhuma outra feature tem o que exibir.

**Features:**
- Adicionar peça por foto, com remoção automática de fundo.
- Preenchimento manual dos metadados da peça (categoria, cor, estação, ocasião).
- Edição e exclusão de peças cadastradas.
- Campos opcionais: tamanho, data de compra, frequência de uso.

**Histórias de usuário:**

- Como Marina, quero tirar uma foto de uma peça e ter o fundo removido automaticamente, para que o cadastro fique com aparência organizada sem eu precisar editar a imagem.
  - *Critério de aceite*: ao enviar uma foto, a imagem processada (sem fundo) é exibida antes da confirmação final do cadastro.
- Como Marina, quero preencher categoria, cor, estação e ocasião da peça manualmente, para cadastrar minhas roupas sem depender de nenhuma sugestão automática.
- Como Marina, quero editar ou apagar uma peça cadastrada errada, para manter meu armário digital correto.

### Épico 2 — Organização por categorias

**Features:**
- Listagem do armário agrupada por categoria (camisetas, calças, vestidos, sapatos, acessórios etc.).
- Filtro por cor, tecido, estação, ocasião e marca.

**Histórias de usuário:**

- Como Marina, quero ver meu armário organizado por categoria, para encontrar rapidamente o tipo de peça que estou procurando.
- Como Marina, quero filtrar minhas peças por estação e ocasião, para achar algo apropriado para um contexto específico sem rolar a lista inteira.

### Épico 3 — Criação manual de looks

**Features:**
- Montar um look manualmente a partir das peças cadastradas.
- Salvar looks favoritos.
- Organizar looks por ocasião (trabalho, faculdade, festa, academia, viagem).
- Histórico de looks utilizados.

**Histórias de usuário:**

- Como Marina, quero montar um look escolhendo peças do meu armário, para salvar combinações que eu já sei que funcionam.
- Como Marina, quero marcar um look como favorito e associá-lo a uma ocasião, para reencontrá-lo rapidamente quando precisar de algo parecido de novo.
- Como Marina, quero ver o histórico de looks que já usei, para não repetir a mesma combinação toda semana sem perceber.

## Personalização e IA

A partir daqui, cada épico depende da base (Épicos 1–3) já estar implementada e usável. É também o ponto de corte natural caso o prazo de 2 meses aperte (ver Documento de Visão, seção "Estágio e restrição de prazo") — o MVP pode ir a campo só com a base, tratando o restante como fast-follow.

### Épico 4 — Configuração de preferências de estilo

Não usa IA — é um formulário de configurações. Entra neste bloco, e não na base, porque só tem utilidade real a partir do momento em que existe alguma sugestão automática (Épicos 5–7) para consumi-la; não há razão prática para construir essa tela antes disso.

**Features:**
- Cadastro de combinações de cores favoritas.
- Preferência por sobreposições (jaquetas, cardigans, camisas abertas).
- Estilos preferidos (casual, streetwear, elegante, minimalista, esportivo etc.).
- Peças ou combinações que o usuário evita.
- Nível de criatividade desejado nas combinações sugeridas.

**Histórias de usuário:**

- Como Marina, quero informar meus estilos preferidos, para que as sugestões futuras combinem com meu gosto pessoal.
- Como Marina, quero indicar peças ou combinações que evito, para que o app nunca me sugira algo que eu não usaria.

### Épico 5 — Cadastro assistido por IA

Enriquece o Épico 1 depois de pronto: a sugestão automática de metadados que inicialmente não existia passa a estar disponível, sempre revisável antes de salvar.

**Features:**
- Sugestão automática de metadados (categoria, cor, estação, ocasião) via Gemini Vision, a partir da foto processada.
- Sugestão sempre editável — nunca salva sem revisão do usuário.

**Histórias de usuário:**

- Como Marina, quero que o app sugira a categoria e a cor da peça automaticamente, para não precisar preencher tudo manualmente.
  - *Critério de aceite*: após o processamento da imagem, os campos de categoria/cor/estação/ocasião vêm pré-preenchidos, mas editáveis; se a IA falhar, os campos aparecem vazios em vez de travar o cadastro.

### Épico 6 — Sugestões automáticas de looks

Depende do Épico 4 (preferências) já existir para gerar sugestões personalizadas, e dos Épicos 1–2 (peças, categorias) para ter o que sugerir.

**Features:**
- Sugestão automática de looks usando somente peças cadastradas.
- Sugestão considera ocasião, clima e preferências de estilo.
- Variação das sugestões para incentivar o uso de peças menos usadas.

**Histórias de usuário:**

- Como Marina, quero receber uma sugestão de look pronta para uma ocasião que eu escolher, para não perder tempo decidindo sozinha o que vestir.
- Como Marina, quero que as sugestões variem ao longo do tempo, para redescobrir peças que tenho e uso pouco, em vez de sempre ver as mesmas combinações.
- Como Marina, quero que a sugestão nunca inclua algo que eu não tenho, para que eu consiga realmente usar o que foi sugerido sem precisar comprar nada.

### Épico 7 — Inspiração por imagem

O de maior risco técnico (depende de embeddings e busca vetorial) e o último da fila — o primeiro a ser simplificado ou adiado se o prazo apertar.

**Features:**
- Upload de uma imagem de referência externa (Pinterest, Instagram, TikTok, etc.).
- Identificação de estilo, cores e composição da imagem de referência.
- Montagem de um look semelhante usando somente peças cadastradas no app.
- Exposição explícita de lacunas quando não existir peça equivalente a algum item da referência.

**Histórias de usuário:**

- Como Marina, quero enviar uma foto que salvei como inspiração, para ver um look parecido montado com roupas que eu realmente tenho.
- Como Marina, quero saber quando o app não encontrou nada parecido com uma peça da foto de referência, para entender que aquele item eu não tenho, em vez de receber uma sugestão genérica que não bate com a inspiração.

## Roadmap sugerido (referência para o MVP de 2 meses)

| Fase | Épicos | Observação |
| --- | --- | --- |
| 1 | Épico 1 + Épico 2 | Sem armário navegável, nenhuma outra tela tem o que mostrar. Cadastro 100% manual — sem dependência de Gemini. |
| 2 | Épico 3 | Fecha a base: com looks manuais prontos, o produto já é minimamente utilizável sem nenhuma IA. |
| 3 | Épico 4 + Épico 5 | Entrada da personalização e da primeira assistência de IA (sugestão de metadados). |
| 4 | Épico 6 | Primeira entrega de valor de "IA" de fato — motor de regras, não modelo generativo (ver Documento de Arquitetura). |
| 5 | Épico 7 | Só se o cronograma permitir; é aceitável entregar o MVP sem essa feature e tratá-la como fast-follow. |
