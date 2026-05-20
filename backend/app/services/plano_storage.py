from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from app.core.config import settings

ALLOWED_EXTENSIONS = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".pdf": "application/pdf",
}


class PlanoValidationError(ValueError):
    pass


@dataclass
class StoredPlanoFile:
    original_filename: str
    relative_path: str
    mime_type: str
    size_bytes: int


class PlanoStorageService:
    def __init__(self, base_dir: str | None = None) -> None:
        self._base_dir = Path(base_dir or settings.plano_storage_dir).resolve()

    @property
    def max_size_bytes(self) -> int:
        return settings.plano_max_size_bytes

    def save(self, *, proyecto_id: int, upload: UploadFile) -> StoredPlanoFile:
        filename = Path(upload.filename or "").name
        if not filename:
            raise PlanoValidationError("Archivo obligatorio.")

        extension = Path(filename).suffix.lower()
        expected_mime_type = ALLOWED_EXTENSIONS.get(extension)
        if expected_mime_type is None:
            raise PlanoValidationError("Formato no permitido. Use PNG, JPG, JPEG o PDF.")

        content_type = upload.content_type or ""
        if content_type != expected_mime_type:
            raise PlanoValidationError("Formato no permitido. Use PNG, JPG, JPEG o PDF.")

        proyecto_dir = self._base_dir / f"proyecto_{proyecto_id}"
        proyecto_dir.mkdir(parents=True, exist_ok=True)

        stored_name = f"{uuid4().hex}{extension}"
        relative_path = Path(f"proyecto_{proyecto_id}") / stored_name
        destination = (self._base_dir / relative_path).resolve()
        if self._base_dir not in destination.parents:
            raise PlanoValidationError("Ruta de almacenamiento inválida.")

        total_size = 0
        with destination.open("wb") as output:
            while True:
                chunk = upload.file.read(1024 * 1024)
                if not chunk:
                    break
                total_size += len(chunk)
                if total_size > self.max_size_bytes:
                    destination.unlink(missing_ok=True)
                    raise PlanoValidationError(
                        f"El archivo excede el tamaño máximo permitido de {self.max_size_bytes} bytes."
                    )
                output.write(chunk)

        upload.file.seek(0)
        return StoredPlanoFile(
            original_filename=filename,
            relative_path=relative_path.as_posix(),
            mime_type=expected_mime_type,
            size_bytes=total_size,
        )

    def resolve(self, relative_path: str) -> Path:
        resolved = (self._base_dir / relative_path).resolve()
        if self._base_dir != resolved and self._base_dir not in resolved.parents:
            raise FileNotFoundError("Ruta de plano inválida.")
        return resolved

    def delete(self, relative_path: str | None) -> None:
        if not relative_path:
            return
        try:
            path = self.resolve(relative_path)
        except FileNotFoundError:
            return
        path.unlink(missing_ok=True)
