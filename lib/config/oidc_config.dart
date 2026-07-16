class OidcConfig {
  static const String discoveryUrl =
      'https://oidc.authoriza.ru/oidc/.well-known/openid-configuration';

  static const String clientId =
      '58465092-a77e-4b94-8ff8-4440c70443aa';

  static const String mobileRedirectUrl =
      'ru.authoriza.demo:/oauth2callback';

  static const String webRedirectUrl =
      'http://localhost:3000/';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}
