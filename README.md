# biohelix_app

Starter Flutter client for a Bun + D1 backend.

## Included starter pieces

- Provider-based app state via `SessionProvider`
- Dio API client with bearer-token support
- SharedPreferences token persistence
- `.env` based API configuration
- Basic home screen to verify backend connectivity

## First-run steps

1. Update `.env` with your Bun API base URL.
2. Run `flutter pub get`.
3. Start the app with `flutter run`.
4. Use the home screen to save a token and test your health endpoint.

## Suggested next features

- Add real auth flows wired to your backend endpoints
- Split features into auth, dashboard, and domain modules
- Add repository classes between providers and the API client
- Add `go_router` once you have more than a couple of screens

