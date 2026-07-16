# Authoriza Flutter OIDC Client

**Демонстрационный проект интеграции Авторизы для Flutter**

Проект представляет собой Flutter-приложение, демонстрирующее интеграцию с сервисом Авториза по протоколу OpenID Connect.

Приложение реализует OpenID Connect Authorization Code Flow with PKCE, получение токенов через Token Endpoint, отображение ответа Token Endpoint, декодирование JWT payload, сохранение сессии, восстановление авторизации после перезапуска, ручное и автоматическое обновление токенов, а также выход с очисткой сохранённых данных.

## Назначение проекта

Данный проект является примером интеграции Авторизы для Flutter-приложения.

Он демонстрирует:

- реализацию OpenID Connect Authorization Code Flow with PKCE;
- использование Discovery Endpoint для получения OIDC-конфигурации;
- перенаправление пользователя в Авторизу после нажатия кнопки входа;
- получение Access Token, ID Token и Refresh Token;
- сохранение результатов аутентификации;
- восстановление сессии после перезапуска приложения;
- ручное обновление токенов через Refresh Token;
- автоматическое обновление Access Token до истечения срока действия;
- обработку ситуации, когда Refresh Token отсутствует, истёк или больше не принимается провайдером;
- отображение маскированных токенов;
- отображение decoded payload для Access Token и ID Token;
- logout с очисткой сохранённой сессии.

## Стек технологий

| Компонент | Инструмент |
| --- | --- |
| Язык | Dart |
| Фреймворк | Flutter |
| OIDC-клиент для Android/iOS | flutter_appauth |
| Web OIDC | Authorization Code Flow with PKCE |
| Хранение токенов | flutter_secure_storage |
| Управление состоянием | provider |
| HTTP-запросы для web-flow | http |
| PKCE code challenge для web | crypto |
| iOS CI build | Codemagic |

Основные библиотеки:

```yaml
flutter_appauth
flutter_secure_storage
provider
http
crypto