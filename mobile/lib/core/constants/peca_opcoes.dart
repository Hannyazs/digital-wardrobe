import 'package:flutter/material.dart';

/// Opções predefinidas do cadastro de peça (E1.F2.1 + categorização por
/// seleção). Usadas pelo formulário, pelos filtros do armário e pela ordem
/// fixa de agrupamento (E2.F1.1) — por isso vivem num lugar só, em vez de
/// cópias que podem dessincronizar.
/// Lista fechada é só UX: o banco aceita `String` livre em todos esses
/// campos (sem enum), então valores antigos ou personalizados continuam
/// válidos e o formulário os preserva ao editar (ver `comValorAtual`).

const categoriasFixas = [
  'Camisetas',
  'Camisas',
  'Blusas',
  'Regatas',
  'Suéteres',
  'Calças',
  'Shorts',
  'Saias',
  'Vestidos',
  'Macacões',
  'Casacos',
  'Sapatos',
  'Acessórios',
];

/// "Gaveta" do armário: agrupa categorias afins na tela principal. Mesmos
/// grupos que o motor de sugestões usa (backend `services/sugestoes/tipos.py`:
/// partes de cima, partes de baixo, vestidos, casacos, sapatos), mais
/// acessórios. Agrupamento só visual: a categoria gravada na peça não muda.
class Gaveta {
  const Gaveta(this.nome, this.categorias);

  final String nome;
  final List<String> categorias;
}

/// Na ordem de [categoriasFixas]: a montagem de look, que lista por categoria,
/// fica na mesma sequência do armário.
const gavetasDoArmario = [
  Gaveta('Partes de cima', ['Camisetas', 'Camisas', 'Blusas', 'Regatas', 'Suéteres']),
  Gaveta('Partes de baixo', ['Calças', 'Shorts', 'Saias']),
  Gaveta('Vestidos', ['Vestidos']),
  Gaveta('Macacões', ['Macacões']),
  Gaveta('Casacos', ['Casacos']),
  Gaveta('Sapatos', ['Sapatos']),
  Gaveta('Acessórios', ['Acessórios']),
];

/// Peças com categoria fora de [categoriasFixas] (o banco aceita texto livre).
const gavetaOutras = Gaveta('Outras', []);

/// "Outros" não é uma ocasião: é o gatilho do campo de texto. O valor
/// digitado é o que vai para o banco (junto das ocasiões marcadas).
const ocasiaoOutros = 'Outros';
const ocasioesFixas = [
  'Casual',
  'Trabalho',
  'Faculdade',
  'Festa',
  'Evento formal',
  'Esporte',
  'Academia',
  'Encontro',
  'Praia',
  'Viagem',
];

const estacoesFixas = ['Verão', 'Outono', 'Inverno', 'Primavera', 'Todas as estações'];

const estilosFixos = ['Casual', 'Formal', 'Esportivo', 'Elegante', 'Streetwear', 'Minimalista'];

/// Tipos de sobreposição que o usuário pode preferir (E4.F2.1). Nenhum
/// marcado = sem preferência. Lista de produto: acrescentar um tipo não exige
/// migração (o banco guarda texto livre).
const sobreposicoesFixas = ['Jaqueta', 'Cardigan', 'Camisa aberta', 'Blazer', 'Colete'];

/// Rótulos do nível de criatividade das sugestões (E4.F5.1), do 1 ao 5; o
/// padrão do backend é 3. Cada nível é a ousadia máxima das cores do look
/// (docs/regras-sugestoes.md, seção 1; definidos na E5.F2.1).
const niveisDeCriatividade = [
  'Neutros + uma cor',
  'Tom sobre tom',
  'Cores vizinhas',
  'Cores contrastantes',
  'Cores opostas',
];

const tonalidadesFixas = ['Escura', 'Clara', 'Vibrante', 'Pastel', 'Neutra'];

/// Cor específica + a tonalidade sugerida para ela. A tonalidade é guardada
/// à parte da cor (campo próprio) e o usuário pode trocá-la: a sugestão só
/// poupa um toque.
class CorOpcao {
  const CorOpcao(this.nome, this.cor, this.tonalidadeSugerida);

  final String nome;
  final Color cor;
  final String tonalidadeSugerida;
}

const coresFixas = [
  CorOpcao('Preto', Color(0xFF111111), 'Escura'),
  CorOpcao('Branco', Color(0xFFFFFFFF), 'Clara'),
  CorOpcao('Cinza', Color(0xFF9E9E9E), 'Neutra'),
  CorOpcao('Bege', Color(0xFFD9C3A5), 'Neutra'),
  CorOpcao('Marrom', Color(0xFF6D4C41), 'Escura'),
  CorOpcao('Vermelho', Color(0xFFD32F2F), 'Vibrante'),
  CorOpcao('Vinho', Color(0xFF6A1B2B), 'Escura'),
  CorOpcao('Laranja', Color(0xFFF57C00), 'Vibrante'),
  CorOpcao('Amarelo', Color(0xFFFDD835), 'Vibrante'),
  CorOpcao('Verde', Color(0xFF2E7D32), 'Vibrante'),
  CorOpcao('Azul-marinho', Color(0xFF14284B), 'Escura'),
  CorOpcao('Azul', Color(0xFF1976D2), 'Vibrante'),
  CorOpcao('Azul-claro', Color(0xFFAED6F1), 'Pastel'),
  CorOpcao('Rosa', Color(0xFFF48FB1), 'Pastel'),
  CorOpcao('Roxo', Color(0xFF7B1FA2), 'Vibrante'),
];

String? tonalidadeSugeridaPara(String? nomeCor) {
  for (final opcao in coresFixas) {
    if (opcao.nome == nomeCor) return opcao.tonalidadeSugerida;
  }
  return null;
}

/// Modelagens que fazem sentido por categoria. Categoria ausente do mapa
/// (sapatos, acessórios, ou uma categoria antiga) não pergunta modelagem.
const modelagensPorCategoria = {
  'Camisetas': ['Oversized', 'Justa', 'Reta', 'Larga'],
  'Camisas': ['Oversized', 'Justa', 'Reta', 'Larga'],
  'Blusas': ['Oversized', 'Justa', 'Reta', 'Larga'],
  'Regatas': ['Justa', 'Reta', 'Larga'],
  'Suéteres': ['Oversized', 'Justa', 'Reta', 'Larga'],
  'Casacos': ['Oversized', 'Justa', 'Reta', 'Larga'],
  'Calças': ['Justa', 'Reta', 'Larga'],
  'Shorts': ['Justa', 'Reta', 'Larga'],
  'Saias': ['Justa', 'Reta', 'Evasê'],
  'Vestidos': ['Justa', 'Reta', 'Evasê', 'Larga'],
  'Macacões': ['Justa', 'Reta', 'Larga'],
};

List<String> modelagensDe(String? categoria) => modelagensPorCategoria[categoria] ?? const [];

/// Acrescenta [valorAtual] ao fim de [opcoes] quando ele não está na lista —
/// peças cadastradas antes das opções predefinidas (texto livre) continuam
/// aparecendo selecionadas ao editar, em vez de sumirem ou quebrarem o
/// dropdown.
List<String> comValorAtual(List<String> opcoes, String? valorAtual) {
  if (valorAtual == null || valorAtual.isEmpty || opcoes.contains(valorAtual)) return opcoes;
  return [...opcoes, valorAtual];
}
