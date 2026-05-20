"""PB-02: crear tabla plano para archivo principal de proyecto.

Revision ID: c7d8e9f0a1b2
Revises: b1c2d3e4f5a6
Create Date: 2026-05-19
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c7d8e9f0a1b2"
down_revision: Union[str, None] = "b1c2d3e4f5a6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "plano",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("proyecto_id", sa.Integer(), nullable=False),
        sa.Column("nombre_archivo", sa.String(length=255), nullable=False),
        sa.Column("ruta_archivo", sa.String(length=500), nullable=False),
        sa.Column("mime_type", sa.String(length=100), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("uploaded_by", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["proyecto_id"], ["proyecto.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["uploaded_by"], ["usuario.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("proyecto_id", name="uq_plano_proyecto_id"),
        sa.UniqueConstraint("ruta_archivo"),
    )
    op.create_index(op.f("ix_plano_id"), "plano", ["id"], unique=False)
    op.create_index(op.f("ix_plano_proyecto_id"), "plano", ["proyecto_id"], unique=False)
    op.create_index(op.f("ix_plano_uploaded_by"), "plano", ["uploaded_by"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_plano_uploaded_by"), table_name="plano")
    op.drop_index(op.f("ix_plano_proyecto_id"), table_name="plano")
    op.drop_index(op.f("ix_plano_id"), table_name="plano")
    op.drop_table("plano")
