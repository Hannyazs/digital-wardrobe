/// Categorias e ocasiões com valores enumerados em docs/requisitos.md.
/// Usadas tanto pelo formulário de cadastro (E1.F2.1, dropdowns) quanto
/// pela ordem fixa de agrupamento do armário (E2.F1.1) — por isso vivem
/// num lugar só, em vez de duas cópias que podem dessincronizar.
/// Lista fechada é só UX: o banco aceita `String` livre em
/// categoria/ocasiao (sem enum), revisável sem migração.
const categoriasFixas = ['Camisetas', 'Calças', 'Vestidos', 'Sapatos', 'Acessórios'];
const ocasioesFixas = ['Trabalho', 'Faculdade', 'Festa', 'Academia', 'Viagem'];
