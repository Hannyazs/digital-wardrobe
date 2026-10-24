# Akkyeo — resumo do projeto e esboço da apresentação

Documento de apoio para a defesa do Projeto de Graduação (Engenharia de Computação — Ibmec). Estado do projeto em 23/10/2026. O relatório técnico completo está em [TCC-V2.md](TCC-V2.md).

---

## Parte 1 — Resumo de tudo que foi utilizado

### 1.1 Tecnologias

| Camada | Tecnologia | Para que serve no Akkyeo | Por que foi escolhida |
| --- | --- | --- | --- |
| Aplicativo | **Flutter (Dart)** | Telas do app: armário, looks, sugestões, mural, preferências | Um único código para Android, iOS e navegador, com acesso à câmera |
| Estado no app | **Riverpod** | Guarda o estado de cada tela e conversa com os serviços | Separa tela de lógica e facilita os testes |
| Servidor (API) | **FastAPI (Python)** | Recebe os pedidos do app, aplica as regras e responde (CRUD de peças, looks, referências, sugestões) | Rápido, assíncrono, valida dados sozinho e o Python concentra as bibliotecas de IA |
| Validação de dados | **Pydantic** | Define o formato de entrada e saída de cada rota | Erros de dado são barrados antes de chegar ao banco |
| Banco de dados | **PostgreSQL** | Guarda peças, looks, usos, preferências, referências e coleções | Relacional e consolidado; os dados têm relações claras |
| Busca por similaridade | **pgvector** | Reservado para a comparação automática entre imagens (futuro) | Evita um segundo banco só para vetores |
| Acesso ao banco | **SQLAlchemy 2.0** | Tabelas como classes Python | Código tipado, sem SQL espalhado |
| Migrações | **Alembic** | Histórico versionado das mudanças no banco (17 migrações) | Nada é alterado "na mão" no banco |
| Remoção de fundo | **rembg (rede U²-Net)** | Recorta a roupa da foto e tira o fundo | Roda no próprio computador, sem custo por imagem |
| IA de visão | **Gemma 3 4B (Google)** | Sugere categoria, cor e tonalidade da peça; lista as peças visíveis numa referência | Modelo aberto e leve (3,4 GB) que aceita imagens |
| Execução da IA | **Ollama** | Roda o Gemma 3 no notebook e o expõe por uma API local | Sem API paga e sem enviar fotos a terceiros |
| Autenticação | **JWT no padrão do Supabase Auth** | A API valida o token e descobre quem é o usuário | Ninguém acessa dados de outra pessoa; o login real ainda não está ligado |
| Armazenamento de imagens | **Pasta local** (`backend/uploads`) | Guarda as fotos das peças e das referências | Simples para desenvolvimento; na nuvem depois (Supabase Storage ou S3) |
| Ambiente local | **Docker Compose** | Sobe o Postgres com pgvector com um comando | O banco fica igual em qualquer máquina |
| Testes | **pytest** e **flutter test** | Testes automáticos do servidor e do app | Ferramentas padrão de cada linguagem |
| Versionamento | **Git** | Histórico de todo o código | Rastreabilidade do desenvolvimento |
| Design | **Figma** | Protótipo visual que guiou o redesenho das telas | Padrão de mercado para interface |
| Apoio ao desenvolvimento | **Claude Code** | Assistente de programação que implementou PBIs já especificadas | Decisões e revisão da autora; nada concluído sem verificação |

### 1.2 Padrões de projeto e decisões de arquitetura

| Padrão / decisão | Onde está | O que resolve |
| --- | --- | --- |
| Arquitetura em camadas | rotas → serviços → adaptadores/banco | Cada parte com uma responsabilidade |
| Service Layer | `backend/app/services/` | Lógica testável sem servidor nem banco |
| Adapter | `backend/app/adapters/` (rembg, Ollama, storage) | Trocar a IA ou o armazenamento muda um arquivo só; foi assim que o Gemini virou Gemma 3 |
| DTO | `backend/app/schemas/` (Pydantic) | Formato da API separado do formato das tabelas |
| Injeção de dependência | `Depends` do FastAPI | O usuário sempre vem do token; nos testes as dependências são trocadas |
| Exclusão lógica | campo `arquivado` nos looks | Excluir um look não apaga o histórico de uso |
| Recomendação por regras | `backend/app/services/sugestoes/` | Sugestões explicáveis, reproduzíveis e testáveis |
| IA sempre com tempo limite e alternativa | `ollama_adapter` | Se a IA falhar, o cadastro segue com campos vazios |

### 1.3 Métodos de trabalho

- Desenvolvimento incremental, inspirado no Scrum.
- Backlog em épicos, features e PBIs (`E<épico>.F<feature>.<item>`), cada PBI com critérios de aceite e log de implementação.
- Regras do motor de sugestões escritas e aprovadas antes do código (`regras-sugestoes.md`).
- Verificação por PBI: análise estática, testes automatizados e, no servidor, execução real da API com dois usuários de teste.

### 1.4 O que o Akkyeo faz hoje

| Épico | O que entrega | Situação |
| --- | --- | --- |
| 1 — Cadastro de roupas | Foto, remoção de fundo, atributos, edição e exclusão | Implementado |
| 2 — Organização | Armário por categoria e filtros | Implementado |
| 3 — Looks manuais | Montar, favoritar, ocasiões, histórico de uso em calendário | Implementado |
| 4 — Preferências de estilo | Cores que combinam, estilos, sobreposições, peças evitadas, criatividade | Implementado |
| 5 — Sugestões | Motor de regras com harmonia de cores, priorizando peças pouco usadas | Implementado |
| 6 — Look do dia | Sugestão na tela inicial com rotatividade de peças | Implementado |
| 7 — Cadastro assistido por IA | Gemma 3 pré-preenche categoria, cor e tonalidade; o usuário revisa | Implementado |
| 8 — Mural de referências | Mural tipo Pinterest, coleções, ligação a um look e etiquetas das peças por IA | Implementado |
| 8 — Ligação automática | IA sugere o look do armário mais parecido com a referência | Não iniciado |

### 1.5 Números do projeto

| Item | Valor |
| --- | --- |
| PBIs especificadas | 53 (49 concluídas, 4 não iniciadas) |
| PBIs de servidor validadas com a API real | 11 (com Postgres local e dois usuários de teste) |
| Migrações de banco | 17 |
| Testes automatizados do servidor | 159, todos passando (23/10/2026) |
| Testes automatizados do app | 317, dos quais 312 passando (23/10/2026); as 5 falhas são do redesenho da tela inicial, ainda em andamento e não commitado |
| Tempo das sugestões | 0,62 s para um armário de 100 peças |
| Tempo da IA por foto | 7 a 13 s (cadastro) e 5 a 12 s (referência), no notebook com RTX 3050 |

### 1.6 Pendências conhecidas

- Login real (Supabase) ainda não integrado: usa-se um token de desenvolvimento.
- Validação manual de ponta a ponta das telas no Chrome.
- Imagens em pasta local; mover para a nuvem antes do teste com usuários.
- Ligação automática referência → look (E8.F5.1 a E8.F5.3).
- Revisão de acessibilidade da interface.
- Avaliação com 5 a 10 usuários (tempo de decisão, peças usadas, SUS, satisfação).

---

## Parte 2 — Esboço da apresentação

### 2.1 O que o regulamento do Ibmec pede

- **Modalidade:** projeto aplicado, que é avaliado pelo **relatório técnico** e pelo **protótipo funcional**. O protótipo precisa permitir demonstrar o funcionamento e verificar se atende aos requisitos (arts. 6º e 10).
- **Conteúdo técnico do relatório (art. 9º):** introdução e objetivos; requisitos funcionais e não funcionais; modelagens funcional, estática e dinâmica; estratégias de implementação; testes e validação; resultados e considerações finais; referências e anexos.
- **Sessão de defesa (art. 19):** 45 minutos no total, conduzida pelo orientador, em quatro etapas: defesa oral (pública), arguição pela banca (pública), deliberação (reservada) e comunicação do resultado.
- **Banca (art. 14):** três membros. O orientador preside, o segundo membro é indicado por você e o terceiro é designado pelo coordenador.
- **Prazos (arts. 13 e 21):**
  - enviar o relatório à banca **pelo menos 1 semana antes** da defesa;
  - entregar a versão final **até 7 dias depois**, com os ajustes da banca e a **ficha catalográfica**.

O regulamento não fixa o tempo da fala. A proposta abaixo usa **cerca de 20 minutos**, deixando o resto para a arguição. [Confirmar com o orientador.]

### 2.2 Roteiro de slides

| # | Slide | O que mostrar | Mensagem principal | Tempo |
| --- | --- | --- | --- | --- |
| 1 | Capa | Akkyeo — Assistente Inteligente de Estilo e Vestuário; autora, orientador, curso | — | 0:30 |
| 2 | O problema | Produção de roupas dobrou e o uso de cada peça caiu 36% (Ellen MacArthur, 2017); 26% das peças sem uso há um ano (WRAP, 2022) | Usamos pouco do que temos | 1:30 |
| 3 | A proposta e o nome | O que é o Akkyeo; 아껴 (*akkyeo*): valorizar e usar com cuidado; regra central: só peças do próprio armário | Renovar o jeito de se vestir sem renovar o armário | 1:30 |
| 4 | Objetivos e hipótese | Objetivo geral, objetivos específicos e hipótese (menos tempo de decisão, mais peças usadas) | O que o projeto quer provar | 1:00 |
| 5 | Trabalhos relacionados | Tabela com Whering, Acloset, GetWardrobe, Fits e Combyne | Diferencial: só o que você tem, sugestões explicáveis, peças esquecidas, acessibilidade | 1:30 |
| 6 | Requisitos | Épicos 1 a 8 com a situação de cada um, e os requisitos não funcionais principais (privacidade, só peças do armário, resiliência da IA) | Escopo claro e entregue | 1:30 |
| 7 | Arquitetura | Diagrama app → API → banco, com rembg e Ollama; tabela de tecnologias | Por que cada tecnologia | 2:00 |
| 8 | Modelagens | Casos de uso, modelo de dados e um diagrama de sequência (cadastro com IA) | Atende ao art. 9º | 1:30 |
| 9 | IA × regras | Gemma 3 reconhece a peça; o motor de regras decide o look | Reconhecer imagem não é recomendar | 1:30 |
| 10 | Motor de sugestões | Estrutura do look, "ousadia" das cores no círculo cromático, nível de criatividade, prioridade para peças pouco usadas | Sugestão explicável e testável | 1:30 |
| 11 | **Demonstração** | Protótipo funcionando (roteiro na seção 2.3) | O sistema existe e funciona | 4:00 |
| 12 | Testes e validação | 159 testes no servidor, 317 no app [atualizar após concluir a tela inicial], API real com dois usuários, 0,62 s nas sugestões, tempos da IA | Verificado, não só implementado | 1:00 |
| 13 | Resultados e limitações | Objetivos atingidos; pendências (login, nuvem, validação manual, ligação automática) | Honestidade sobre o estado | 1:00 |
| 14 | Próximos passos | Avaliação com usuários, acessibilidade, evoluções futuras (assistente conversacional, ligação automática) | Para onde o projeto vai | 0:30 |
| 15 | Encerramento | Mensagem final e agradecimentos | — | 0:30 |

**Total aproximado: 21 minutos.**

### 2.3 Roteiro da demonstração (slide 11)

Ter tudo aberto antes da sessão: Postgres (Docker), API, Ollama com o `gemma3:4b` carregado e o app no Chrome.

1. **Cadastro com IA:** fotografar ou escolher uma peça, mostrar o fundo removido e o formulário já preenchido pelo Gemma 3, com o aviso para revisar. Corrigir um campo e salvar.
2. **Armário:** mostrar a peça na categoria certa e usar um filtro de cor.
3. **Sugestões:** pedir sugestões para uma ocasião e mostrar a explicação de cada look e o nível de criatividade.
4. **Look do dia:** mostrar o card na tela inicial e marcar "Usei hoje", com o dia aparecendo no calendário.
5. **Mural:** adicionar uma referência, mostrar as etiquetas sugeridas pela IA e ligar a referência a um look salvo.

**Plano B:** gravar um vídeo da demonstração antes, caso a rede ou o notebook falhem. A primeira chamada da IA demora mais (cerca de 17 s), então faça uma chamada de aquecimento antes de começar.

### 2.4 Perguntas prováveis da banca

| Pergunta | Resposta curta |
| --- | --- |
| Por que regras e não aprendizado de máquina na recomendação? | Não há dados de uso para treinar no início; regras são explicáveis e testáveis, e o resultado é reproduzível. |
| E se a IA errar? | A sugestão é sempre revisada pelo usuário antes de salvar; se a IA falhar ou demorar, os campos vêm vazios e o cadastro segue. |
| Por que Gemma 3 e não Gemini, Llama ou GPT? | Roda localmente sem custo e sem enviar fotos a terceiros; o Llama 4 Scout (67 GB) não cabe no notebook. A arquitetura com adaptador permitiu trocar de modelo mudando um arquivo. |
| Como garantem que um usuário não vê dados de outro? | O usuário vem só do token, toda consulta filtra por ele, e isso foi testado com dois usuários na API real. |
| Qual foi o papel da IA generativa no desenvolvimento? | Assistente de programação para PBIs já especificadas; decisões, regras e revisão foram da autora, e o histórico do Git e os logs das PBIs registram o processo. |
| O app reduz compras ou impacto ambiental? | É um benefício esperado, não comprovado; a avaliação com usuários mede tempo de decisão e variedade de peças usadas. |
| O que falta para uso real? | Login real, imagens na nuvem e publicação do app. |

### 2.5 Checklist antes da defesa

- [ ] Relatório no modelo do Manual Institucional, em ABNT, com os diagramas exportados como figuras.
- [ ] Indicar ao orientador o nome do segundo membro da banca.
- [ ] Enviar o relatório à banca pelo menos 1 semana antes.
- [ ] Ensaiar a fala dentro do tempo combinado.
- [ ] Gravar o vídeo de backup da demonstração.
- [ ] Depois da defesa: ajustes da banca e ficha catalográfica em até 7 dias.
