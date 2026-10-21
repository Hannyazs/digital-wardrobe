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
  'Calças',
  'Saias',
  'Vestidos',
  'Casacos',
  'Sapatos',
  'Acessórios',
];

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
/// padrão do backend é 3. Provisórios: quando o Épico 6 definir o efeito de
/// cada nível, ajustar o texto aqui (sem migração — o banco guarda o número).
const niveisDeCriatividade = ['Bem seguro', 'Seguro', 'Equilibrado', 'Ousado', 'Bem ousado'];

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
  'Casacos': ['Oversized', 'Justa', 'Reta', 'Larga'],
  'Calças': ['Justa', 'Reta', 'Larga'],
  'Saias': ['Justa', 'Reta', 'Evasê'],
  'Vestidos': ['Justa', 'Reta', 'Evasê', 'Larga'],
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
