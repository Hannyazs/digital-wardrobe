# Documento de Requisitos — Guarda-Roupa Virtual

Épicos, features e histórias de usuário, organizados na ordem de implementação — não na ordem em que as features aparecem no [Documento de Visão](visao.md). A ordem aqui reflete duas coisas: dependência técnica (cada épico assume que os anteriores já existem) e uma decisão de produto — **toda sugestão de IA fica para depois que a base da aplicação (cadastro, organização, looks manuais) já estiver funcionando**. Ver [Documento de Arquitetura](arquitetura.md) para como cada um se encaixa no sistema.

A persona usada nas histórias é a Marina, definida no Documento de Visão — mas nenhuma história pressupõe conhecimento de moda, propositalmente.

Quando uma feature é quebrada em PBIs pra execução do time, essa quebra vive em [backlog.md](backlog.md), não aqui — este documento fica no nível de feature/história, mais estável.

## Requisitos não-funcionais

- **Privacidade**: fotos de peças e preferências são dados pessoais — todo dado é escopado por `usuario_id`, derivado do JWT, nunca do corpo da requisição (ver CLAUDE.md, seção Auth). Nenhuma busca (inclusive por similaridade vetorial) pode vazar dados entre usuários.
- **Privacidade — limitação conhecida (exclusão de conta)**: a exclusão completa da conta e dos dados associados está **fora do escopo atual**. Com a autenticação no Supabase e o PostgreSQL separado (sem chave estrangeira entre eles), excluir um usuário no Supabase não remove suas peças, looks, preferências, referências e imagens. **Precisa ser resolvido antes da disponibilização do aplicativo para terceiros em escala** e deve constar como limitação no TCC. Não há PBI de implementação por ora.
- **Privacidade — vulnerabilidade conhecida e ainda não corrigida (2026-11-05)**: `POST /pecas/processar-imagem` e `POST /pecas/upload-original` **não exigem autenticação**, e as imagens salvas ficam acessíveis em `/uploads` sem autenticação. A correção está prevista na **E10.F2.2** (autenticação, validação do tipo real e do tamanho) e no Épico 10 (bucket privado e URLs assinadas). Até lá, o requisito de isolamento acima **não vale** para esses dois endpoints e para o acesso às imagens.
- **Qualidade — lacuna conhecida de testes (2026-11-05)**: só os endpoints de `referencias` e `colecoes` têm testes de rota; `pecas`, `looks`, `preferencias` e `sugestoes` não têm testes de integração, e não há teste de `processar-imagem` (E1.F1.5). A verificação de isolamento entre usuários nessas rotas foi manual. Previsto na **E9.F3.1**.
- **Idioma**: interface e mensagens em português. Código e nomes técnicos em inglês.
- **Disponibilidade**: sem requisito de SLA formal no MVP — é aceitável indisponibilidade eventual durante a fase de validação.
- **Resiliência de IA**: nenhuma chamada a serviço de IA (Gemma 3 via Ollama) pode derrubar um fluxo do usuário — falha na extração de metadados degrada para preenchimento manual, nunca para erro fatal.

## Base da aplicação (sem IA)

Os três primeiros épicos entregam um produto funcional usando apenas CRUD e regras determinísticas — nenhum depende de modelo de IA generativa ou de qualquer sugestão automática. A remoção de fundo (`rembg`) é uma exceção deliberada: embora use um modelo de visão computacional por baixo, não é uma *sugestão* sujeita ao julgamento do usuário (não há "certo" ou "errado" em remover o fundo de uma foto), por isso permanece no Épico 1 em vez de ser adiada com o resto.

### Épico 1 — Cadastro de roupas (manual)

Base de todo o resto do produto: sem peças cadastradas, nenhuma outra feature tem o que exibir.

**Features:**
- Adicionar peça por foto, com remoção automática de fundo.
- Preenchimento manual dos metadados da peça (categoria, cor, estação, ocasião).
- Edição e exclusão de peças cadastradas.
- Campos opcionais: tamanho, data de compra, frequência de uso. **Situação em 2026-11-05: não implementados e sem PBI planejada** (a peça não tem essas colunas; a recência de uso vem do histórico de looks, `looks_usos`).
- *Implementado depois do planejamento original (PBIs retroativas):* recorte manual da foto antes do envio ([E1.F1.6](PBIs/E1-cadastro-de-roupas/E1-F1-adicionar-foto/E1.F1.6-recorte-manual-da-foto.md)) e campos de classificação ampliados — cores secundárias (peça multicolorida), tonalidade, estações, estilos, modelagem e ocasiões em lista ([E1.F2.2](PBIs/E1-cadastro-de-roupas/E1-F2-metadados-da-peca/E1.F2.2-campos-extras-da-peca.md)).

**Histórias de usuário:**

- Como Marina, quero tirar uma foto de uma peça e ter o fundo removido automaticamente, para que o cadastro fique com aparência organizada sem eu precisar editar a imagem.
  - *Critério de aceite*: ao enviar uma foto, a imagem processada (sem fundo) é exibida antes da confirmação final do cadastro.
- Como Marina, quero preencher categoria, cor, estação e ocasião da peça manualmente, para cadastrar minhas roupas sem depender de nenhuma sugestão automática.
- Como Marina, quero editar ou apagar uma peça cadastrada errada, para manter meu armário digital correto.

### Épico 2 — Organização por categorias

**Features:**
- Listagem do armário agrupada por categoria (camisetas, calças, vestidos, sapatos, acessórios etc.).
- Filtro por cor, tecido, estação, ocasião e marca. **Situação em 2026-11-05:** implementados os filtros por cor, estação e ocasião (seleção múltipla; a cor considera as cores secundárias); **filtro por tecido e marca não existe** (a peça não tem esses campos) e não há PBI planejada.

**Histórias de usuário:**

- Como Marina, quero ver meu armário organizado por categoria, para encontrar rapidamente o tipo de peça que estou procurando.
- Como Marina, quero filtrar minhas peças por estação e ocasião, para achar algo apropriado para um contexto específico sem rolar a lista inteira.

### Épico 3 — Criação manual de looks

**Features:**
- Montar um look manualmente a partir das peças cadastradas.
- Salvar looks favoritos.
- Organizar looks por ocasião (trabalho, faculdade, festa, academia, viagem). *(Exemplos do planejamento original; o app oferece 10 ocasiões: Casual, Trabalho, Faculdade, Festa, Evento formal, Esporte, Academia, Encontro, Praia e Viagem, e um look pode ter várias.)*
- Histórico de looks utilizados.
- Editar e excluir looks salvos (trocar peças; excluir arquiva o look sem apagar o histórico de uso).
- Pastas para organizar os looks salvos (cada look em no máximo uma pasta; *planejado*, Feature 6).

**Histórias de usuário:**

- Como Marina, quero montar um look escolhendo peças do meu armário, para salvar combinações que eu já sei que funcionam.
- Como Marina, quero marcar um look como favorito e associá-lo a uma ocasião, para reencontrá-lo rapidamente quando precisar de algo parecido de novo.
- Como Marina, quero ver o histórico de looks que já usei, para não repetir a mesma combinação toda semana sem perceber.
- *(Planejado)* Como Marina, quero guardar meus looks em pastas que eu mesma crio (ex.: "Trabalho de verão"), para achar o look certo sem rolar a lista inteira.

## Personalização e IA

A partir daqui, cada épico depende da base (Épicos 1–3) já estar implementada e usável. É também o ponto de corte natural caso o prazo de 2 meses aperte (ver Documento de Visão, seção "Estágio e restrição de prazo") — o MVP pode ir a campo só com a base, tratando o restante como fast-follow.

### Épico 4 — Configuração de preferências de estilo

Não usa IA — é um formulário de configurações. Entra neste bloco, e não na base, porque só tem utilidade real a partir do momento em que existe alguma sugestão automática (Épicos 5–8) para consumi-la; não há razão prática para construir essa tela antes disso.

**Features:**
- Cadastro de combinações de cores favoritas.
- Preferência por sobreposições (jaquetas, cardigans, camisas abertas).
- Estilos preferidos (casual, streetwear, elegante, minimalista, esportivo etc.).
- Peças ou combinações que o usuário evita.
- Nível de criatividade desejado nas combinações sugeridas.

**Histórias de usuário:**

- Como Marina, quero informar meus estilos preferidos, para que as sugestões futuras combinem com meu gosto pessoal.
- Como Marina, quero indicar peças ou combinações que evito, para que o app nunca me sugira algo que eu não usaria.

### Épico 5 — Sugestões de looks sob demanda (sem IA)

Depende dos Épicos 1–4: peças para combinar, looks para salvar e preferências/restrições para respeitar. As combinações saem de um **motor de regras** determinístico (estrutura, cores, preferências, restrições) — nenhum modelo de IA é chamado. As regras estão em [regras-sugestoes.md](regras-sugestoes.md).

**Features:**
- Motor de combinação por regras, reaproveitado pelo Épico 6.
- Sugestões sob demanda no app: filtros (estilo, estação, ocasião, cor), três looks por vez com "ver outras", explicação de por que as peças combinam, descarte durante a sessão e salvar como look (`POST /looks`); sugestões a partir de uma peça específica; looks já salvos não voltam como sugestão.
- Renomear looks salvos (looks sugeridos nascem como "Look sugerido – dd/mm").
- Aviso de peça com cadastro incompleto (sem cor, ocasião ou estilo).

**Histórias de usuário:**

- Como Marina, quero pedir sugestões de looks montadas com as minhas roupas, para não perder tempo decidindo sozinha o que vestir.
- Como Marina, quero entender por que as peças de uma sugestão combinam, para confiar na sugestão.
- Como Marina, quero que a sugestão nunca inclua algo que eu não tenho ou que eu disse evitar, para que eu consiga realmente usá-la.
- Como Marina, quero saber quando uma peça está com o cadastro incompleto, para corrigi-la e receber sugestões melhores.

### Épico 6 — Sugestões automáticas de looks

Reaproveita o motor do Épico 5 sem duplicar a lógica de combinação; acrescenta só contexto (ocasião do dia) e rotatividade (histórico de uso).

**Features:**
- Look do dia oferecido automaticamente na tela inicial, com ocasião padrão Casual e a última ocasião escolhida lembrada.
- Variação conforme o histórico de uso, priorizando peças pouco usadas ou esquecidas.
- *Adiado:* clima real via serviço externo de previsão do tempo — depende de confirmar as condições de uso do provedor.

**Histórias de usuário:**

- Como Marina, quero receber um look pronto ao abrir o app, para começar o dia sem precisar pedir.
- Como Marina, quero que as sugestões variem ao longo do tempo, para redescobrir peças que tenho e uso pouco, em vez de sempre ver as mesmas combinações.

### Épico 7 — Cadastro assistido por IA

Enriquece o Épico 1 depois de pronto: a sugestão automática de metadados que inicialmente não existia passa a estar disponível, sempre revisável antes de salvar.

**Features:**
- Sugestão automática de metadados (categoria, cor, estação, ocasião) via Gemma 3 4B (Google), executado localmente pelo Ollama, a partir da foto processada. **Situação em 2026-11-05:** o que está implementado sugere **categoria, subcategoria, cor principal e tonalidade** (sempre com valores das listas fixas); **estação e ocasião não são sugeridas pela IA** (o usuário as preenche).
- Sugestão sempre editável — nunca salva sem revisão do usuário.

**Histórias de usuário:**

- Como Marina, quero que o app sugira a categoria e a cor da peça automaticamente, para não precisar preencher tudo manualmente.
  - *Critério de aceite*: após o processamento da imagem, os campos de categoria/cor/estação/ocasião vêm pré-preenchidos, mas editáveis; se a IA falhar, os campos aparecem vazios em vez de travar o cadastro.
  - *Nota de 2026-11-05 (critério original preservado):* hoje vêm pré-preenchidos categoria, subcategoria, cor e tonalidade; estação e ocasião ficam para o usuário. Esta diferença entre o critério e o comportamento foi registrada, não corrigida; decidir se estação e ocasião devem ser sugeridas pela IA, ou se o critério deve ser reescrito, depende do usuário.

### Épico 8 — Inspiração por imagem (mural de referências)

Dividido em duas etapas. A primeira — o **mural de referências**, inspirado na organização visual do Pinterest — entra na versão inicial (decidido em 2026-10-23): o usuário importa e organiza imagens de referência dentro do app, sem integração com a API do Pinterest, e ele mesmo relaciona a referência às suas peças. A segunda — análise automatizada da referência — é a de maior risco técnico (depende de embeddings e busca vetorial) e fica como evolução futura. Reaproveita o motor de combinação do Épico 5 quando aplicável.

**Features — versão inicial (mural):**
- Importar ou salvar imagens de referência externas (Pinterest, Instagram, TikTok, galeria etc.) dentro do app.
- Organizar e consultar as referências salvas: grade de imagens e coleções criadas pelo usuário (uma por imagem); adicionar só da galeria, sem remoção de fundo.
- Nota opcional por imagem e ligação a um look salvo.
- Etiquetas das peças visíveis sugeridas pela IA (Gemma 3), apenas como texto editável, sem comparar com o armário.
- **Ligação automática (decidido em 2026-10-23):** em "Ligar a um look", além do modo manual, o automático usa as etiquetas para estreitar as peças do armário e o Gemma compara a imagem da referência com as fotos delas; sugere um look salvo que contenha as peças encontradas ou um look novo, sempre só com peças do usuário e com as lacunas explícitas ("sem peça equivalente"). Usa o Gemma local no lugar de embeddings e `pgvector`; nada é salvo ou ligado sem a confirmação do usuário.

**Situação em 2026-11-05:** a versão inicial (mural, coleções, ligação a um look, etiquetas por IA) e a **ligação automática** foram implementadas (E8.F1 a E8.F5). A ligação automática compara a imagem da referência com as fotos das peças do usuário usando o Gemma, sem embeddings. O que continua futuro, e **não existe**, é a análise automatizada por embeddings e busca vetorial (`pgvector`) descrita abaixo; a "montagem de um look semelhante" e a "exposição de lacunas" já são feitas, por outro caminho, pela ligação automática (as histórias marcadas como "Futuro" abaixo foram preservadas como estão).

**Features — evolução futura (análise automatizada):**
- Identificação de estilo, cores e composição da imagem de referência.
- Montagem de um look semelhante usando somente peças cadastradas no app.
- Exposição explícita de lacunas quando não existir peça equivalente a algum item da referência.

**Histórias de usuário:**

- Como Marina, quero guardar no app as imagens de looks que me inspiram, para consultá-las na hora de montar um look com as minhas roupas.
- *(Futuro)* Como Marina, quero enviar uma foto que salvei como inspiração, para ver um look parecido montado com roupas que eu realmente tenho.
- *(Futuro)* Como Marina, quero saber quando o app não encontrou nada parecido com uma peça da foto de referência, para entender que aquele item eu não tenho, em vez de receber uma sugestão genérica que não bate com a inspiração.

## Produção e pesquisa (Épicos 9 a 12) e novos planos (Épicos 13 e 14)

Planejados em 2026-11-05, depois dos Épicos 1–8. Os Épicos 9–11 levam o produto de "protótipo com token de desenvolvimento e imagens em disco" para um aplicativo com contas reais e imagens privadas; o Épico 12 é pesquisa, sem desenvolvimento de funcionalidade. O PostgreSQL **continua fora do Supabase**: só Auth e Storage migram. Login social não é requisito. A quebra em PBIs está em [backlog.md](backlog.md).

### Épico 9 — Autenticação e gerenciamento de usuários (Supabase Auth)

Substitui o `DEV_AUTH_TOKEN` por contas reais, mantendo a regra de que o `usuario_id` vem sempre do token validado pela API.

**Features:**
- Validação do JWT por chaves públicas (JWKS) e plano de migração dos dados existentes (backup, `--dry-run`, validação e reversão; a execução exige autorização explícita e só existe se os dados atuais precisarem ser preservados).
- Cadastro, login, logout, renovação de sessão, tratamento de sessão expirada e, se viável, recuperação de senha.
- Testes de isolamento entre usuários em todos os routers e endurecimento de configuração.

**Histórias de usuário:**
- Como Marina, quero criar uma conta e entrar no app, para que meu armário seja só meu.
- Como Marina, quero continuar logada ao reabrir o app e ser avisada quando a sessão expirar, para não perder o que estava fazendo.

**Decisões pendentes:** confirmação de e-mail (decidida na configuração do Supabase); dados existentes de teste ou a preservar.

### Épico 10 — Armazenamento de imagens no Supabase Storage

Tira as imagens do disco do servidor e do acesso público. Bucket privado, chaves por usuário e URLs assinadas.

**Features:**
- Bucket privado, convenção de chaves `{usuario_id}/...` e adaptador do Supabase com a mesma interface do adaptador local.
- Assinatura centralizada nas respostas da API, upload autenticado com validação do tipo real e do tamanho, e leitura das imagens pelo Gemma a partir do storage.
- Exibição e cache no app (por identidade do usuário, limpos no logout; estratégia definida após medir o egress), exclusão de imagens e tratamento de falhas.
- Plano e script de migração das imagens locais; o desligamento do acesso público a `/uploads` só ocorre depois de verificar que nada mais depende das imagens locais.

**Segurança dos uploads:** todos os endpoints de upload e processamento exigem autenticação; o tipo real do arquivo e o tamanho máximo são validados; um usuário não envia, acessa, substitui nem exclui imagens de outro; a chave de serviço do Supabase fica exclusivamente no backend.

**Riscos:** limites do plano gratuito (1 GB de armazenamento, 5 GB de egress, 50 MB por arquivo, pausa após 1 semana sem uso — a conferir na configuração); consumo de egress por URLs assinadas que mudam.

### Épico 11 — Paginação do armário

Carregamento gradual das peças, sem perder nenhuma funcionalidade atual.

**Features:**
- `GET /pecas` com `limite` e `deslocamento` (offset), ordem estável e filtros no servidor com a mesma semântica do app; contagem em `X-Total-Count` se não trouxer complexidade desnecessária.
- Armário (carrosséis por gaveta) e visão de gaveta com carregamento gradual e deduplicação por `id`.
- Adaptação das telas que consultam peças: montar e editar look, escolher par de peças evitadas e subcategorias já usadas do formulário (endpoint novo só se a paginação prejudicar as sugestões).

**Limitação do offset:** se uma peça for criada ou excluída em outro aparelho durante a rolagem, um item pode se repetir ou ser pulado; a V1 aceita o risco e o mitiga com deduplicação por `id` e puxar para atualizar.

### Épico 12 — Pesquisa: integração com o Pinterest

Apenas investigação de viabilidade e decisão go/no-go. Não presume que a API permita importar qualquer imagem; não propõe scraping nem contornar restrições. **Nenhuma PBI de implementação antes do go confirmado.**

### Épico 13 — Peças paradas

*Planejado em 2026-11-06.* Avisa, ao abrir o app, quando uma peça está sem uso há muito tempo (**90 dias**; peça nunca usada conta a partir do cadastro), para a Marina aproveitar melhor o que já tem. O pop-up mostra a peça e oferece três escolhas: **doar a peça** (neste momento, exclui a peça do app, de forma definitiva e com confirmação), **sugerir look com ela** (reaproveita as sugestões a partir de uma peça) e **lembrar depois** (adia o aviso em **30 dias**).

**Features:**
- Peças paradas e lembrete adiado no servidor (E13.F1.1).
- Pop-up na abertura do app, um por sessão, que nunca bloqueia o uso (E13.F1.2).
- Ações de doar e de sugerir um look (E13.F1.3).

**Histórias de usuário:**
- Como Marina, quero ser lembrada das peças que não uso há meses, para decidir se volto a usá-las ou se as doo.
- Como Marina, quero poder adiar o aviso, para não ser incomodada por uma peça de outra estação.

**Decisões pendentes (não são requisitos):** prazos configuráveis nas preferências; um estado "doada" que preserve o histórico em vez de excluir; tratamento de roupa sazonal.

## Planos futuros

### Épico 14 — Avatar pixelado das roupas

*Ideia registrada em 2026-11-06; sem PBIs, sem estimativa e sem prazo. Fora do escopo do MVP.* A Marina teria um avatar em pixel art, no estilo de videogame, vestindo as peças dos looks dela. Respeita a regra central do produto: o avatar só veste peças que ela já possui.

**Perguntas em aberto** (a responder antes de detalhar qualquer PBI): como gerar o sprite de cada peça a partir da foto já recortada (redução de resolução e paleta fixa, ou um modelo de imagem); se o avatar é um corpo-base fixo ou personalizável (cabelo, pele, tamanho); onde guardar os sprites (depende do Épico 10); o quanto as peças pouco comuns (sapatos, acessórios) perdem na redução. Deve vir depois dos Épicos 9 e 10.

### Fora dos épicos — análise de concorrentes e referências do TCC

Não são épicos nem PBIs: são tarefas de pesquisa e escrita do TCC, mantidas como lista simples em [checklist-tcc.md](checklist-tcc.md). Nenhuma funcionalidade de concorrente vira requisito automaticamente.

## Roadmap sugerido (referência para o MVP de 2 meses)

| Fase | Épicos | Observação |
| --- | --- | --- |
| 1 | Épico 1 + Épico 2 | Sem armário navegável, nenhuma outra tela tem o que mostrar. Cadastro 100% manual — sem dependência de IA generativa. |
| 2 | Épico 3 | Fecha a base: com looks manuais prontos, o produto já é minimamente utilizável sem nenhuma IA. |
| 3 | Épico 4 | Entrada da personalização (preferências e restrições). |
| 4 | Épico 5 + Épico 6 | Sugestões por motor de regras, não modelo generativo (ver Documento de Arquitetura): primeiro sob demanda, depois o look do dia. |
| 5 | Épico 7 | Primeira assistência de IA generativa (sugestão de metadados com Gemma 3 via Ollama). |
| 6 | Épico 8 | Mural de referências entra na versão inicial; a análise automatizada da referência fica como evolução futura. |
| 7 | Épicos 9, 10 e 11 | Contas reais, imagens privadas e paginação, nessa ordem (o 11 é independente e pode vir antes do 10). Planejados, nenhuma PBI iniciada. |
| 8 | Épico 12 | Pesquisa sobre o Pinterest, em paralelo ao desenvolvimento. A análise de concorrentes e as referências do TCC seguem o [checklist-tcc.md](checklist-tcc.md). |
| 9 | Épico 3 (Feature 6) e Épico 13 | Pastas de looks e aviso de peça parada: independentes dos Épicos 9 e 10, podem entrar a qualquer momento depois do Épico 11. O Épico 14 (avatar) fica depois do Épico 10. |
