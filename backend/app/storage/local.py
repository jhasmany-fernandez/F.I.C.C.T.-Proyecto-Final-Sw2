"""Implementación de StorageBackend sobre filesystem local."""

from pathlib import Path


class LocalFilesystemStorage:
    """Persiste planos en ``root/{nombre}`` dentro del filesystem local.

    Pensada para entornos contenerizados con un volumen Docker montado en
    ``root`` (por defecto ``/var/lib/heatmapper/planos``).
    """

    def __init__(self, root: str | Path) -> None:
        self._root = Path(root)
        self._root.mkdir(parents=True, exist_ok=True)

    def _abs(self, ruta_relativa: str) -> Path:
        # Bloquear traversal (``..``) y rutas absolutas que escapen del root.
        path = (self._root / ruta_relativa).resolve()
        if not str(path).startswith(str(self._root.resolve())):
            raise ValueError(f"Ruta inválida: {ruta_relativa}")
        return path

    def save(self, contenido: bytes, nombre: str) -> str:
        destino = self._abs(nombre)
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_bytes(contenido)
        return nombre

    def read(self, ruta_relativa: str) -> bytes:
        return self._abs(ruta_relativa).read_bytes()

    def delete(self, ruta_relativa: str) -> None:
        path = self._abs(ruta_relativa)
        if path.exists():
            path.unlink()

    def exists(self, ruta_relativa: str) -> bool:
        return self._abs(ruta_relativa).exists()
