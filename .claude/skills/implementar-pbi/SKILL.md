---
name: implementar-pbi
description: Implementa uma PBI já detalhada em docs/PBIs/, seguindo o padrão de execução, verificação honesta e log de implementação estabelecido no projeto — o exemplo canônico é docs/PBIs/E1-F1-adicionar-foto/E1.F1.1-captura-e-selecao-de-foto.md (releia-o antes de aplicar este skill, ele é a fonte de verdade). Use quando o usuário pedir para implementar, desenvolver, codar ou executar uma PBI específica. Complementa o skill `criar-pbi` (que cria o arquivo detalhado antes deste existir).
---

# Implementar PBI

## Antes de implementar

1. **Localize o arquivo detalhado da PBI** em `docs/PBIs/E<épico>-F<feature>-<slug>/`. Se o usuário só deu um ID (ex: "E1.F1.3") e o arquivo não existir ainda, **pare e avise** — sugira rodar o skill `criar-pbi` primeiro. Não implemente a partir de uma descrição resumida do `backlog.md` só; o arquivo detalhado é o que define escopo, "como será feito" e critérios de aceite.
2. Leia junto o `docs/backlog.md` e as PBIs vizinhas da mesma feature, pra não reabrir uma sobreposição de escopo já resolvida antes (isso já aconteceu neste projeto entre E1.F1.2 e E1.F1.4).
3. Confira `CLAUDE.md` e `docs/arquitetura.md` pelas convenções de stack já registradas (camadas, gerenciamento de estado, etc.) antes de tomar qualquer decisão técnica não especificada na PBI.

## Pergunte antes de agir quando houver dúvida real

Não pergunte sobre escolhas rotineiras de implementação (texto de botão, cor, nome de variável). Pergunte quando:
- A PBI pressupõe algo que não existe no código atual e que ela mesma não cobre (ex: nenhuma navegação leva até a tela que você vai construir).
- O "Como será feito" da PBI conflita com o estado real do código (mudou desde que a PBI foi escrita).
- Alguma decisão mudaria o que é entregue de forma que o usuário razoavelmente ia querer opinar (ex: tocar em um arquivo fora da lista de "Arquivos afetados" da PBI).

Isso já aconteceu na implementação da E1.F1.1 (pergunta sobre onde adicionar a navegação) — é o padrão a seguir, não a exceção.

## Implemente seguindo o "Como será feito" da PBI

Trate as decisões técnicas já registradas na PBI (gerenciamento de estado, arquivos afetados, pontos de atenção) como definidas — não as reabra sem motivo. Se durante a implementação for necessário desviar (dependência que a Definição de Pronto proíbe adicionar, arquivo que não existe mais, etc.), isso é uma mudança de escopo — trate como tal na seção "Como será feito" e resuma na seção de log (ver abaixo), nunca implemente silenciosamente diferente do documentado sem registrar.

## Verifique de verdade — nunca presuma

Rode os comandos reais do projeto (ver `README.md`/`CLAUDE.md` para os comandos atuais — não assuma um comando genérico do framework sem checar se é esse mesmo que o projeto usa):
- Mobile (Flutter): `flutter analyze` e `flutter test`, no mínimo.
- Backend (Python/FastAPI): suíte de testes configurada (`pytest` ou equivalente — confirme o comando real), e migração (`alembic upgrade head`) se o PBI alterou o schema.

Nunca escreva "testado" ou marque um item da Definição de Pronto como feito sem ter executado algo e visto o resultado. Se um critério de aceite exige interação humana que não é roteirizável (clicar num seletor de arquivo nativo, ver uma imagem renderizada visualmente, testar num dispositivo físico), diga isso explicitamente — deixe o item em aberto e explique por que não pode ser fechado por você.

Quando possível, prefira estender um teste automatizado existente pra cobrir mais do fluxo em vez de só confiar em análise estática (ex: um teste de widget que efetivamente navega e renderiza a tela nova pega erros de runtime que `flutter analyze` sozinho não pega).

## Corrija bloqueios pré-existentes encontrados no caminho

Se, ao verificar, você encontrar um problema que já existia antes desta PBI (não introduzido pela sua implementação) e que impede a verificação de passar limpa, é aceitável corrigi-lo como parte do trabalho — mas **documente como fora do escopo original**, não misture com o que a PBI pediu.

## Feche o ciclo de documentação (obrigatório, não opcional)

No arquivo detalhado da PBI:
1. Atualize o campo **Status** na tabela de metadados.
2. Marque a **Definição de Pronto** item por item, honestamente — só marcado `[x]` o que foi de fato executado e verificado; o que ficou pendente de validação humana continua `[ ]` com uma nota.
3. Adicione (ou atualize) uma seção `## Log de implementação` ao final, cobrindo:
   - O que foi entregue (arquivos criados/alterados).
   - Mudanças de escopo, com a razão de cada uma (inclui perguntas feitas ao usuário e o que foi decidido, e fixes de bloqueios pré-existentes).
   - Verificação realizada — comandos reais rodados e o resultado literal (não "deve funcionar").
   - O que fica pendente de validação humana, e por quê.
   - Qualquer decisão de implementação que a PBI não detalhava e você teve que tomar.

Em `docs/backlog.md`: atualize a entrada resumida dessa PBI (status + uma frase), mantendo consistência com o arquivo detalhado — nunca deixe os dois dizendo coisas diferentes.

## Nunca infle o status

Não marque uma PBI como "Concluída" sem qualificação se alguma parte dos critérios de aceite depende de verificação humana ainda não feita. Nesse caso o status é algo como "Concluída (validação manual pendente)" — nunca "Concluída" liso quando isso esconderia uma lacuna real. Essa distinção entre "implementado" e "verificado" já foi uma correção necessária neste projeto (PBI E1.F1.2) — não repita o erro.

## Ao final, resuma para o usuário

Poucas linhas: mudanças de escopo, comandos executados com resultado, e o que fica pendente de validação humana. Não repita o arquivo inteiro da PBI na resposta do chat.
