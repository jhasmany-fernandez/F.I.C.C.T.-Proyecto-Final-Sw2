# WiFiScope Mobile

Aplicacion Flutter para registrar mediciones reales de cobertura WiFi sobre un
plano o imagen de un ambiente.

## Objetivo de esta app

La app permite cargar un plano del lugar que se quiere analizar, seleccionar
manualmente puntos dentro de ese plano y asociarles mediciones WiFi reales
capturadas desde un telefono Android.

Esta base corresponde al Sprint 1 del proyecto y valida el nucleo del sistema:
capturar datos reales y ubicarlos correctamente sobre el plano.

## Como funciona el plano

La parte del "mapa" dentro de la app no es un mapa GPS ni algo como Google
Maps. En esta app, el mapa es el plano del ambiente, es decir, una imagen del
lugar donde quieres medir la cobertura WiFi.

Ejemplos validos:

- el plano de una casa
- el plano de una oficina
- el plano de un aula
- una imagen del ambiente exportada como `PNG` o `JPG`

## Como se usa el plano

El flujo de uso es este:

1. cargas la imagen del plano del ambiente
2. la app muestra ese plano en pantalla
3. tocas un lugar especifico del plano
4. la app entiende que quieres medir la señal WiFi en ese punto
5. presionas el boton para medir
6. la medicion se guarda asociada a esa ubicacion

## Que significa tocar un punto

Cuando tocas el plano, la app no guarda una direccion real ni coordenadas GPS.
Lo que guarda es una posicion relativa dentro de la imagen.

Por ejemplo:

- `x = 0.25`
- `y = 0.60`

Eso significa:

- 25 por ciento del ancho del plano
- 60 por ciento del alto del plano

Gracias a esto, mas adelante la app puede:

- dibujar marcadores en las posiciones medidas
- colorear zonas del plano
- construir un heatmap sobre la imagen

## Ejemplo practico

Imagina que estas analizando una casa:

1. cargas el plano de la casa
2. te paras fisicamente en la cocina
3. tocas en la app el lugar del plano que corresponde a la cocina
4. presionas `Medir senal WiFi aqui`
5. la app guarda esa medicion en ese punto

Luego repites lo mismo en:

- dormitorio
- sala
- puerta de entrada
- patio

Asi vas construyendo un conjunto de mediciones distribuidas sobre el plano.

## Que datos guarda cada medicion

Cada medicion queda asociada a un punto del plano y guarda informacion como:

- coordenada `x`
- coordenada `y`
- `SSID`
- `BSSID`
- `RSSI`
- `frequency`
- `channel`
- fecha y hora de captura

## Que ves en la pantalla del plano

En el visor del plano puedes ver:

- la imagen del ambiente
- la ubicacion que acabas de seleccionar
- puntos donde ya hay mediciones guardadas
- ayudas visuales para tocar, mover y hacer zoom

## Que no hace todavia esta parte

En esta etapa la app todavia no:

- genera heatmaps automaticamente
- interpola entre puntos
- detecta zonas muertas
- genera recomendaciones de ubicacion de APs

Por ahora el plano sirve para:

- cargar la imagen del lugar
- seleccionar puntos manualmente
- capturar y guardar mediciones reales en esos puntos

## Resumen rapido

La parte del plano funciona asi:

- no es un mapa GPS
- es una imagen del ambiente
- tu eliges manualmente donde estas
- la app registra la senal WiFi en ese punto
- luego esos puntos serviran para construir el mapa de calor

## Ejecutar la app

```bash
cd apps/mobile
/tmp/flutter-sdk/bin/flutter pub get
/tmp/flutter-sdk/bin/flutter run
```

## Ejecutar en Android por WiFi

```bash
adb connect 192.168.26.13:5555
cd apps/mobile
/tmp/flutter-sdk/bin/flutter run -d 192.168.26.13:5555
```

## Nombre actual de la app

- `WiFiScope`

## Icono de la app

La imagen fuente del icono esta guardada en:

- [assets/icons/wifiscope-app-icon.png](/home/jhasmany/Documents/Repository/F.I.C.C.T.-Proyecto-Final-Sw2/apps/mobile/assets/icons/wifiscope-app-icon.png)
