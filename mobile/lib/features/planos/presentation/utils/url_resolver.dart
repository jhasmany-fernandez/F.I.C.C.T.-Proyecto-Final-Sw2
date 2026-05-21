/// Resuelve una URL firmada relativa a una URL absoluta consumible por el cliente.
/// El backend devuelve la URL relativa (p. ej. `/planos/archivo/...?exp=&sig=`)
/// cuando `PUBLIC_API_URL` no está configurado en el servidor.
/// Sprint 2 — PB-02.
String resolverUrlFirmada(String urlFirmada) {
  if (urlFirmada.startsWith('http://') || urlFirmada.startsWith('https://')) {
    return urlFirmada;
  }
  const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2/api',
  );
  if (urlFirmada.startsWith('/')) {
    return '$base$urlFirmada';
  }
  return '$base/$urlFirmada';
}
