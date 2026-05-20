from datetime import datetime

from pydantic import BaseModel


class PlanoOut(BaseModel):
    id: int
    proyecto_id: int
    nombre_archivo: str
    mime_type: str
    size_bytes: int
    uploaded_by: int
    created_at: datetime

    model_config = {"from_attributes": True}
