# F.I.C.C.T. Proyecto Final SW2

Base de trabajo pensada como monorepo para frontend mobile/web y backend.

## Estructura actual

- `apps/mobile`: aplicacion Flutter creada y lista para evolucionar.

## Estructura recomendada a futuro

- `apps/mobile`: Flutter para Android y Web.
- `apps/web`: frontend web con Next.js.
- `apps/api`: backend con NestJS.

## Ejecutar Flutter

```bash
cd apps/mobile
/tmp/flutter-sdk/bin/flutter pub get
/tmp/flutter-sdk/bin/flutter run
```

## Configurar la URL del backend

Puedes pasar variables de compilacion con `--dart-define`:

```bash
cd apps/mobile
/tmp/flutter-sdk/bin/flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://localhost:3000/api
```

## Siguiente paso sugerido

Crear primero el backend en `NestJS` con rutas claras como `/auth`, `/users` o
`/products`, y luego conectar Flutter a esas rutas desde una capa de servicios.
