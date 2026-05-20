/**
 * Pantalla de gestión de usuarios del panel admin.
 * Sp1-09 — PB-13 (CA-1, CA-2, CA-3, CA-4).
 */

import { type ReactNode, useState } from "react";
import { AxiosError } from "axios";
import {
  Activity,
  Pencil,
  Power,
  Search,
  ShieldCheck,
  SlidersHorizontal,
  UserPlus,
  Users,
  Wrench,
} from "lucide-react";
import { useActualizarUsuario, useUsuarios } from "../hooks/useUsuarios";
import type { UsuarioOut } from "../types";
import UsuarioModal from "../components/UsuarioModal";
import { Badge, Button, EmptyState } from "@/shared/components";
import { useToast } from "@/shared/components";
import { useAuth } from "@/features/auth/hooks/useAuth";
import styles from "./GestionUsuarios.module.css";

const STAT_TONE_CLASS = {
  primary: "tonePrimary",
  success: "toneSuccess",
  info: "toneInfo",
  accent: "toneAccent",
} as const;

export default function GestionUsuarios() {
  const { data: usuarios, isLoading, isError, isFetching, error } =
    useUsuarios();
  const { mutateAsync: actualizar, isPending: actualizando } =
    useActualizarUsuario();
  const [busqueda, setBusqueda] = useState("");
  const [filtroRol, setFiltroRol] = useState<"todos" | "admin" | "tecnico">(
    "todos",
  );
  const [mostrarModal, setMostrarModal] = useState(false);
  const [usuarioEditar, setUsuarioEditar] = useState<UsuarioOut | null>(null);
  const [usuarioProcesandoId, setUsuarioProcesandoId] = useState<number | null>(
    null,
  );
  const usuarioActual = useAuth((s) => s.usuario);
  const toast = useToast();
  const usuariosLista = usuarios ?? [];
  const terminoBusqueda = busqueda.trim().toLowerCase();
  const usuariosFiltrados = usuariosLista.filter((usuario) => {
    const coincideRol = filtroRol === "todos" || usuario.rol === filtroRol;
    const coincideBusqueda =
      terminoBusqueda.length === 0 ||
      usuario.nombre.toLowerCase().includes(terminoBusqueda) ||
      usuario.email.toLowerCase().includes(terminoBusqueda) ||
      usuario.rol.toLowerCase().includes(terminoBusqueda);
    return coincideRol && coincideBusqueda;
  });

  const totalUsuarios = usuariosLista.length;
  const totalActivos = usuariosLista.filter((usuario) => usuario.activo).length;
  const totalAdmins = usuariosLista.filter((usuario) => usuario.rol === "admin").length;
  const totalTecnicos = usuariosLista.filter(
    (usuario) => usuario.rol === "tecnico",
  ).length;

  const toggleActivo = async (usuario: UsuarioOut) => {
    if (usuario.id === usuarioActual?.id) return;
    setUsuarioProcesandoId(usuario.id);
    try {
      await actualizar({ id: usuario.id, datos: { activo: !usuario.activo } });
      toast.exito(
        usuario.activo
          ? `${usuario.nombre} fue desactivado.`
          : `${usuario.nombre} fue activado.`,
      );
    } catch {
      toast.error("No se pudo actualizar el estado del usuario.");
    } finally {
      setUsuarioProcesandoId(null);
    }
  };

  if (isLoading) {
    return (
      <section className={styles.pagina}>
        <div className={styles.encabezado}>
          <div>
            <h1 className={styles.titulo}>Usuarios</h1>
            <p className={styles.subtitulo}>
              Gestione las cuentas de técnicos y administradores.
            </p>
          </div>
        </div>
        <div className={styles.metricasGrid}>
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className={styles.skeletonCard} />
          ))}
        </div>
        <div className={styles.panel}>
          <div className={styles.filtros}>
            <div className={styles.skeletonBar} />
            <div className={styles.skeletonSelect} />
          </div>
          <div className={styles.estadoCentrado}>
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className={styles.skeleton} />
            ))}
          </div>
        </div>
      </section>
    );
  }

  if (isError) {
    return (
      <div className={styles.estadoCentrado}>
        <p className={styles.error}>{mapUsuariosError(error)}</p>
      </div>
    );
  }

  return (
    <section className={styles.pagina}>
      <div className={styles.encabezado}>
        <div>
          <h1 className={styles.titulo}>Usuarios</h1>
          <p className={styles.subtitulo}>
            Gestione las cuentas de técnicos y administradores.
          </p>
          {isFetching && !isLoading && (
            <p className={styles.actualizando}>Actualizando lista…</p>
          )}
        </div>
        <Button
          onClick={() => setMostrarModal(true)}
          disabled={actualizando}
          className={styles.botonPrincipal}
        >
          <UserPlus size={15} aria-hidden="true" />
          Nuevo usuario
        </Button>
      </div>

      <div className={styles.metricasGrid}>
        <StatCard
          icon={<Users size={20} aria-hidden="true" />}
          titulo="Usuarios totales"
          valor={totalUsuarios}
          tone="primary"
        />
        <StatCard
          icon={<Activity size={20} aria-hidden="true" />}
          titulo="Usuarios activos"
          valor={totalActivos}
          tone="success"
        />
        <StatCard
          icon={<ShieldCheck size={20} aria-hidden="true" />}
          titulo="Administradores"
          valor={totalAdmins}
          tone="info"
        />
        <StatCard
          icon={<Wrench size={20} aria-hidden="true" />}
          titulo="Técnicos"
          valor={totalTecnicos}
          tone="accent"
        />
      </div>

      <div className={styles.panel}>
        <div className={styles.filtros}>
          <label className={styles.buscar}>
            <Search size={18} aria-hidden="true" />
            <input
              type="search"
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
              placeholder="Buscar por nombre, correo o rol..."
              aria-label="Buscar usuarios"
            />
          </label>

          <label className={styles.selector}>
            <SlidersHorizontal size={16} aria-hidden="true" />
            <span>Rol:</span>
            <select
              value={filtroRol}
              onChange={(e) =>
                setFiltroRol(e.target.value as "todos" | "admin" | "tecnico")
              }
              aria-label="Filtrar por rol"
            >
              <option value="todos">Todos</option>
              <option value="admin">Admin</option>
              <option value="tecnico">Técnico</option>
            </select>
          </label>
        </div>

        {!usuariosLista.length ? (
          <EmptyState mensaje="No hay usuarios registrados aún." />
        ) : !usuariosFiltrados.length ? (
          <div className={styles.emptyFiltros}>
            No hay usuarios que coincidan con los filtros actuales.
          </div>
        ) : (
          <div className={styles.tablaWrapper}>
            <table className={styles.tabla}>
              <thead>
                <tr>
                  <th>Nombre</th>
                  <th>Correo</th>
                  <th>Rol</th>
                  <th>Estado</th>
                  <th>Creado</th>
                  <th>Acciones</th>
                </tr>
              </thead>
              <tbody>
                {usuariosFiltrados.map((u) => (
                  <tr key={u.id}>
                    <td>
                      <div className={styles.usuarioCelda}>
                        <div
                          className={`${styles.avatar} ${
                            u.rol === "admin" ? styles.avatarAdmin : styles.avatarTecnico
                          }`}
                          aria-hidden="true"
                        >
                          {iniciales(u.nombre)}
                        </div>
                        <span className={styles.nombre}>{u.nombre}</span>
                      </div>
                    </td>
                    <td className={styles.correo}>{u.email}</td>
                    <td>
                      <Badge variante={u.rol === "admin" ? "admin" : "tecnico"} />
                    </td>
                    <td>
                      <Badge
                        variante={u.activo ? "activo" : "inactivo"}
                        icono={<span className={styles.dotEstado} aria-hidden="true" />}
                      />
                    </td>
                    <td className={styles.creado}>
                      {new Date(u.created_at).toLocaleDateString("es-BO")}
                    </td>
                    <td>
                      <div className={styles.acciones}>
                        <Button
                          variante="secondary"
                          tamano="sm"
                          className={styles.botonAccion}
                          disabled={actualizando}
                          onClick={() => {
                            setUsuarioEditar(u);
                            setMostrarModal(false);
                          }}
                        >
                          <Pencil size={14} aria-hidden="true" />
                          Editar
                        </Button>
                        {u.id !== usuarioActual?.id && (
                          <Button
                            variante={u.activo ? "danger" : "secondary"}
                            tamano="sm"
                            className={
                              u.activo
                                ? styles.botonAccionPeligro
                                : styles.botonAccion
                            }
                            isLoading={
                              actualizando && usuarioProcesandoId === u.id
                            }
                            disabled={actualizando}
                            onClick={() => toggleActivo(u)}
                          >
                            <Power size={14} aria-hidden="true" />
                            {u.activo ? "Desactivar" : "Activar"}
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            <div className={styles.footerTabla}>
              <span>
                Mostrando {usuariosFiltrados.length} de {totalUsuarios} usuarios
              </span>
              <div className={styles.paginacionMock}>
                <button type="button" disabled aria-label="Página anterior">
                  ‹
                </button>
                <button
                  type="button"
                  className={styles.paginaActiva}
                  aria-current="page"
                >
                  1
                </button>
                <button type="button" disabled aria-label="Página siguiente">
                  ›
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {(mostrarModal || usuarioEditar !== null) && (
        <UsuarioModal
          usuarioEditar={usuarioEditar ?? undefined}
          onCerrar={() => {
            setMostrarModal(false);
            setUsuarioEditar(null);
          }}
        />
      )}
    </section>
  );
}

function StatCard({
  icon,
  titulo,
  valor,
  tone,
}: {
  icon: ReactNode;
  titulo: string;
  valor: number;
  tone: "primary" | "success" | "info" | "accent";
}) {
  return (
    <article className={styles.statCard}>
      <div className={`${styles.statIcon} ${styles[STAT_TONE_CLASS[tone]]}`}>{icon}</div>
      <div>
        <strong className={styles.statValor}>{valor}</strong>
        <p className={styles.statTitulo}>{titulo}</p>
      </div>
    </article>
  );
}

function iniciales(nombre: string): string {
  return nombre
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((parte) => parte[0]?.toUpperCase() ?? "")
    .join("");
}

function mapUsuariosError(error: unknown): string {
  if (error instanceof AxiosError) {
    if (error.code === "ECONNABORTED") {
      return "El backend tardó demasiado en responder al cargar usuarios.";
    }
    if (!error.response) {
      return "No se pudo conectar con el backend para cargar usuarios.";
    }
    if (error.response.status === 401) {
      return "La sesión expiró. Vuelve a iniciar sesión.";
    }
    if (error.response.status === 403) {
      return "No tienes permisos para ver usuarios.";
    }
  }

  return "Error al cargar los usuarios.";
}
