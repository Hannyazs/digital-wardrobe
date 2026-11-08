/// Projeto Supabase usado pelo app (E9.F2.1). Os padrões apontam para o
/// projeto de desenvolvimento; outro projeto entra por `--dart-define`.
///
/// A chave aqui é a **pública** (publishable): pode ficar no app e no
/// repositório. A chave secreta (service key) nunca vem para o app.
class AuthConfig {
  AuthConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vxzadsokzxwqalqvnepd.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_M27Z6iEXz9gJU6nRBujXZA_fwsPKBj3',
  );
}
