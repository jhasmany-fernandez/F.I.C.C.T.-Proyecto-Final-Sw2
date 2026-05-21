"""Backends de almacenamiento de planos (Sprint 2).

Expone un protocolo ``StorageBackend`` para permitir intercambiar la
implementación local por S3 u otro provider en el futuro.

Las URLs firmadas usan HMAC-SHA256 + timestamp de expiración.
"""

from app.storage.base import StorageBackend
from app.storage.local import LocalFilesystemStorage
from app.storage.signing import generar_url_firmada, verificar_firma

__all__ = [
    "StorageBackend",
    "LocalFilesystemStorage",
    "generar_url_firmada",
    "verificar_firma",
]
