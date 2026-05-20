"""PB-03: crear tablas de lotes y señales WiFi.

Revision ID: d8e9f0a1b2c3
Revises: c7d8e9f0a1b2
Create Date: 2026-05-19
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "d8e9f0a1b2c3"
down_revision: Union[str, None] = "c7d8e9f0a1b2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "wifi_scan_lote",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("proyecto_id", sa.Integer(), nullable=False),
        sa.Column("plano_id", sa.Integer(), nullable=False),
        sa.Column("tecnico_id", sa.Integer(), nullable=False),
        sa.Column("punto_id", sa.String(length=100), nullable=True),
        sa.Column("capturado_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("origen", sa.String(length=30), nullable=False, server_default="mobile"),
        sa.Column("app_version", sa.String(length=50), nullable=True),
        sa.Column("device_id", sa.String(length=120), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["plano_id"], ["plano.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["proyecto_id"], ["proyecto.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["tecnico_id"], ["usuario.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_wifi_scan_lote_id"), "wifi_scan_lote", ["id"], unique=False)
    op.create_index(
        op.f("ix_wifi_scan_lote_plano_id"),
        "wifi_scan_lote",
        ["plano_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_wifi_scan_lote_proyecto_id"),
        "wifi_scan_lote",
        ["proyecto_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_wifi_scan_lote_tecnico_id"),
        "wifi_scan_lote",
        ["tecnico_id"],
        unique=False,
    )

    op.create_table(
        "wifi_scan_senal",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("lote_id", sa.Integer(), nullable=False),
        sa.Column("ssid", sa.String(length=255), nullable=True),
        sa.Column("bssid", sa.String(length=17), nullable=False),
        sa.Column("rssi_dbm", sa.Integer(), nullable=False),
        sa.Column("frequency_mhz", sa.Integer(), nullable=True),
        sa.Column("channel", sa.Integer(), nullable=True),
        sa.Column("security", sa.String(length=255), nullable=True),
        sa.ForeignKeyConstraint(["lote_id"], ["wifi_scan_lote.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_wifi_scan_senal_id"), "wifi_scan_senal", ["id"], unique=False)
    op.create_index(
        op.f("ix_wifi_scan_senal_lote_id"),
        "wifi_scan_senal",
        ["lote_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_wifi_scan_senal_lote_id"), table_name="wifi_scan_senal")
    op.drop_index(op.f("ix_wifi_scan_senal_id"), table_name="wifi_scan_senal")
    op.drop_table("wifi_scan_senal")

    op.drop_index(op.f("ix_wifi_scan_lote_tecnico_id"), table_name="wifi_scan_lote")
    op.drop_index(op.f("ix_wifi_scan_lote_proyecto_id"), table_name="wifi_scan_lote")
    op.drop_index(op.f("ix_wifi_scan_lote_plano_id"), table_name="wifi_scan_lote")
    op.drop_index(op.f("ix_wifi_scan_lote_id"), table_name="wifi_scan_lote")
    op.drop_table("wifi_scan_lote")
