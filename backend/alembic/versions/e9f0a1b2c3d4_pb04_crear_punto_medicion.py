"""PB-04: crear tabla punto_medicion y FK opcional desde wifi_scan_lote.

Revision ID: e9f0a1b2c3d4
Revises: d8e9f0a1b2c3
Create Date: 2026-05-19
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e9f0a1b2c3d4"
down_revision: Union[str, None] = "d8e9f0a1b2c3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "punto_medicion",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("proyecto_id", sa.Integer(), nullable=False),
        sa.Column("plano_id", sa.Integer(), nullable=False),
        sa.Column("x", sa.Float(), nullable=False),
        sa.Column("y", sa.Float(), nullable=False),
        sa.Column("modo", sa.String(length=20), nullable=False),
        sa.Column("etiqueta", sa.String(length=120), nullable=True),
        sa.Column("descripcion", sa.String(length=255), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=True,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["plano_id"], ["plano.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["proyecto_id"], ["proyecto.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_punto_medicion_id"), "punto_medicion", ["id"], unique=False)
    op.create_index(
        op.f("ix_punto_medicion_plano_id"),
        "punto_medicion",
        ["plano_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_punto_medicion_proyecto_id"),
        "punto_medicion",
        ["proyecto_id"],
        unique=False,
    )

    op.add_column(
        "wifi_scan_lote",
        sa.Column("punto_medicion_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_wifi_scan_lote_punto_medicion_id",
        "wifi_scan_lote",
        "punto_medicion",
        ["punto_medicion_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        op.f("ix_wifi_scan_lote_punto_medicion_id"),
        "wifi_scan_lote",
        ["punto_medicion_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_wifi_scan_lote_punto_medicion_id"), table_name="wifi_scan_lote")
    op.drop_constraint(
        "fk_wifi_scan_lote_punto_medicion_id",
        "wifi_scan_lote",
        type_="foreignkey",
    )
    op.drop_column("wifi_scan_lote", "punto_medicion_id")

    op.drop_index(op.f("ix_punto_medicion_proyecto_id"), table_name="punto_medicion")
    op.drop_index(op.f("ix_punto_medicion_plano_id"), table_name="punto_medicion")
    op.drop_index(op.f("ix_punto_medicion_id"), table_name="punto_medicion")
    op.drop_table("punto_medicion")
