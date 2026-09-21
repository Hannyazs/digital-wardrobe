# Documento de Visão — Guarda-Roupa Virtual

## Objetivo do produto

Ajudar qualquer pessoa a aproveitar melhor as roupas que já possui, eliminando a fricção diária de "não sei o que vestir" através de um armário digital que organiza as peças e sugere looks — usando exclusivamente o que já está no guarda-roupa do usuário, nunca recomendando compra ou peças que ele não tem.

## Visão

Um assistente de estilo pessoal que conhece o guarda-roupa do usuário tão bem quanto ele mesmo — e usa isso para tirar do caminho a decisão repetitiva de "o que vestir hoje", ao mesmo tempo em que ajuda a redescobrir peças esquecidas em vez de sempre repetir as mesmas combinações.

## Problema

Boa parte das pessoas usa uma fração pequena do próprio guarda-roupa no dia a dia — não por falta de opções, mas por falta de visibilidade e de tempo para pensar em combinações. O resultado é dinheiro parado em roupas não utilizadas e tempo gasto (ou estresse) toda vez que é preciso se vestir para uma ocasião fora da rotina.

## Público-alvo

Público geral — o produto não é voltado a um nicho de moda específico (não é uma ferramenta para quem já domina styling, nem exclusiva de um estilo como streetwear ou minimalismo). A dor que resolve — indecisão na hora de se vestir e subutilização do próprio guarda-roupa — é comum independente de idade, gênero ou quanto a pessoa se interessa por moda.

### Persona primária

**Marina, 29 anos.** Trabalha em horário comercial, tem uma rotina cheia e um guarda-roupa de tamanho médio acumulado ao longo dos anos. Não se considera "fashionista", mas gosta de estar bem vestida sem gastar tempo demais pensando nisso. Compra roupa algumas vezes por ano, mas sente que "sempre usa as mesmas 5 peças". Já salvou fotos de looks no Pinterest/Instagram que gostaria de reproduzir, mas nunca sentou pra conferir se tem roupas parecidas em casa.

- **Frustração principal**: decidir o que vestir consome tempo e energia mental todo dia, especialmente para ocasiões fora do comum (entrevista, festa, viagem).
- **O que valoriza**: rapidez, praticidade, e não precisar comprar roupa nova pra "ter algo pra vestir".
- **Como o produto ajuda**: reduz a decisão diária a escolher entre sugestões prontas, e traz de volta ao uso peças que ela esqueceu que tinha.

A persona é ilustrativa — o produto não restringe funcionalidades a esse perfil, ela serve para ancorar decisões de design em uma pessoa concreta em vez de "o usuário" abstrato.

## Proposta de valor

- Organização completa do guarda-roupa em um só lugar, com busca e filtro.
- Recomendações de looks que usam **somente** roupas que a pessoa já tem — nunca sugestão de compra.
- Sugestões variam de propósito para incentivar o uso de peças esquecidas, não só repetir os favoritos óbvios.
- Permite recriar o estilo de uma foto de referência (Pinterest, Instagram, TikTok) com peças reais do próprio armário.
- Aprende as preferências de estilo da pessoa em vez de aplicar um gosto genérico.

## Diferenciais

- A restrição "só sugere o que a pessoa já tem" é a regra central do produto (ver [CLAUDE.md](../CLAUDE.md)) — é o que separa o produto de um Pinterest genérico de moda.
- Combinação de cadastro assistido por IA (visão computacional remove fundo e sugere metadados) com um motor de recomendação que respeita preferências pessoais.
- Inspiração por imagem como ponte entre "o que eu queria vestir" e "o que eu realmente tenho".

## Não-objetivos (fora do escopo do MVP)

Registrado explicitamente para não expandir escopo por conta própria durante o desenvolvimento:

- Recomendação de compra de roupas novas ou integração com e-commerce.
- Rede social / compartilhamento de looks entre usuários.
- Múltiplos idiomas — MVP é em português.
- Aprendizado de estilo sofisticado (ex: fine-tuning de modelo por usuário) — a personalização inicial é baseada em preferências explícitas cadastradas, não em aprendizado implícito de longo prazo.
- Suporte multi-dispositivo sincronizado em tempo real (ex: editar em dois celulares ao mesmo tempo).

## Estágio e restrição de prazo

Projeto em estágio de validação de ideia (startup), com meta de **MVP funcional em 2 meses**. Essa restrição de tempo é uma decisão de produto, não só técnica: a ordem de implementação definida no [Documento de Requisitos](requisitos.md) prioriza as features mais simples e com maior retorno primeiro, deixando a feature de maior risco técnico (inspiração por imagem, que depende de embeddings e busca vetorial) por último — se o prazo apertar, é a que deve ser simplificada ou adiada, não as anteriores.

## Métricas de sucesso (fase de validação)

Como o objetivo agora é validar se existe demanda real, as métricas do MVP são de ativação e uso, não de crescimento ou receita:

- **Ativação**: % de usuários que cadastram pelo menos 5 peças na primeira sessão.
- **Engajamento central**: % de usuários que criam ou aceitam pelo menos 1 look (manual ou sugerido) na primeira semana.
- **Retenção curta**: % de usuários que voltam a abrir o app pelo menos uma vez na semana seguinte ao cadastro.
- **Sinal qualitativo**: feedback direto de usuários-teste sobre se as sugestões automáticas fazem sentido (mais relevante que qualquer métrica quantitativa nesse estágio, dado o volume baixo de usuários esperado em 2 meses).
