# yetki

Role-based access control (RBAC) for Dart and Flutter.

| Package | Description |
| --- | --- |
| [`yetki`](packages/yetki) [![pub](https://img.shields.io/pub/v/yetki.svg)](https://pub.dev/packages/yetki) | Pure Dart core: permissions, roles with inheritance, wildcard grants, persistence and change notifications. |
| [`yetki_flutter`](packages/yetki_flutter) [![pub](https://img.shields.io/pub/v/yetki_flutter.svg)](https://pub.dev/packages/yetki_flutter) | Flutter bindings: `YetkiScope`, guard widgets, a router `Listenable` and shared_preferences storage. |

Upgrading from 0.1.x? See the
[migration guide](packages/yetki/README.md#migration-from-01x).

## Development

This repository is a [pub workspace](https://dart.dev/tools/pub/workspaces).

```bash
flutter pub get                    # resolves both packages
(cd packages/yetki && dart test)
(cd packages/yetki_flutter && flutter test)
```

CI runs formatting, analysis, tests and a publish dry run for both packages
on every push and pull request.
