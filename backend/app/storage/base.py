"""Protocolo abstracto de almacenamiento de planos."""

from typing import Protocol


class StorageBackend(Protocol):
    """Interfaz para guardar/recuperar/borrar archivos de planos.

    Implementaciones: ``LocalFilesystemStorage``. Pendiente: ``S3Storage``.
    """

    def save(self, contenido: bytes, nombre: str) -> str:
        """Persiste el contenido. Retorna la ruta relativa que se almacena en BD."""
        ...

    def read(self, ruta_relativa: str) -> bytes:
        """Lee el contenido binario asociado a la ruta relativa."""
        ...

    def delete(self, ruta_relativa: str) -> None:
        """Elimina el archivo (idempotente)."""
        ...

    def exists(self, ruta_relativa: str) -> bool:
        """True si el archivo está presente."""
        ...
