"""Ligação automática de uma referência do mural ao armário (Épico 8, Feature 5).

`candidatos` é o funil: funções puras que, a partir das etiquetas de uma
referência ("calça jeans azul"), escolhem as peças do armário que valem uma
comparação visual. Não acessam banco, HTTP nem `settings`, para serem
testáveis com `pytest` (o mesmo desenho de `services/sugestoes`).
Regra do produto: só peças do usuário; sem equivalente, a resposta é uma
lacuna explícita, nunca uma peça "parecida" inventada.
"""
