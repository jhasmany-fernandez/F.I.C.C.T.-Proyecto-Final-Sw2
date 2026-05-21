"""Router principal v1: agrupa auth, admin/usuarios, admin/proyectos, clientes y proyectos.

Sprint 1 — PB-09, PB-13, PB-18, PB-19.
Sprint 3 — PB-03, PB-04.
"""

from fastapi import APIRouter

from app.api.v1 import (
    admin_proyectos,
    admin_usuarios,
    auth,
    clientes,
    mediciones,
    planos,
    proyectos,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(admin_usuarios.router)
api_router.include_router(admin_proyectos.router)
api_router.include_router(clientes.router)
api_router.include_router(proyectos.router)
api_router.include_router(planos.router_proyectos)
api_router.include_router(planos.router_planos)
api_router.include_router(mediciones.router_mediciones)
api_router.include_router(mediciones.router_puntos)
api_router.include_router(mediciones.router_planos_puntos)
