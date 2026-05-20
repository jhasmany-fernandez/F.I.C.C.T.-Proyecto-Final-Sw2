/**
 * Layout del panel admin con navegación lateral responsive.
 * Protege rutas admin — redirige a login si no hay sesión.
 * Sprint 1 — PB-13, PB-18.
 */

import { useEffect, useState } from "react";
import {
  NavLink,
  Navigate,
  Outlet,
  useNavigate,
  useLocation,
} from "react-router-dom";
import {
  Bell,
  Radio,
  Users,
  Building2,
  ClipboardList,
  LogOut,
  Menu,
  X,
} from "lucide-react";
import { useAuth } from "@/features/auth/hooks/useAuth";
import { ToastContainer } from "@/shared/components";
import styles from "./AdminLayout.module.css";

const ITEMS_NAV = [
  { to: "/admin/usuarios", etiqueta: "Usuarios", Icono: Users },
  { to: "/admin/clientes", etiqueta: "Clientes", Icono: Building2 },
  { to: "/admin/proyectos", etiqueta: "Proyectos", Icono: ClipboardList },
];

function iniciales(nombre: string): string {
  return nombre
    .split(" ")
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? "")
    .join("");
}

export default function AdminLayout() {
  const { isAuthenticated, isReady, usuario, cerrarSesion } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  // El drawer se abre "en" un pathname específico; si el pathname cambia, queda cerrado.
  const [menuAbiertoEn, setMenuAbiertoEn] = useState<string | null>(null);
  const menuAbierto = menuAbiertoEn === location.pathname;

  useEffect(() => {
    if (isReady && isAuthenticated && usuario?.rol !== "admin") {
      void cerrarSesion().finally(() => {
        navigate("/admin/login", { replace: true });
      });
    }
  }, [cerrarSesion, isAuthenticated, isReady, navigate, usuario]);

  if (!isReady) {
    return <main className={styles.estadoPantalla}>Cargando sesión…</main>;
  }

  if (!isAuthenticated) {
    return <Navigate to="/admin/login" replace />;
  }

  if (usuario?.rol !== "admin") {
    return (
      <main className={styles.estadoPantalla}>
        Verificando permisos del panel administrativo…
      </main>
    );
  }

  const handleLogout = async () => {
    await cerrarSesion();
    navigate("/admin/login", { replace: true });
  };

  const sidebar = (
    <nav className={styles.nav} aria-label="Navegación principal">
      <div className={styles.marca}>
        <Radio size={20} aria-hidden="true" />
        <span>HeatMapper Admin</span>
      </div>

      <ul className={styles.menu} role="list">
        {ITEMS_NAV.map(({ to, etiqueta, Icono }) => (
          <li key={to}>
            <NavLink
              to={to}
              className={({ isActive }) =>
                isActive ? `${styles.enlace} ${styles.activo}` : styles.enlace
              }
            >
              <Icono size={16} aria-hidden="true" />
              {etiqueta}
            </NavLink>
          </li>
        ))}
      </ul>

      <div className={styles.perfil}>
        <div className={styles.identidad}>
          <div className={styles.avatar} aria-hidden="true">
            {iniciales(usuario?.nombre ?? "A")}
          </div>
          <span className={styles.nombreUsuario}>
            {usuario?.nombre ?? "Admin"}
          </span>
        </div>
      </div>
    </nav>
  );

  return (
    <div className={styles.layout}>
      {/* Botón hamburguesa — visible solo en móvil */}
      <button
        className={styles.triggerMovil}
        onClick={() => setMenuAbiertoEn(location.pathname)}
        aria-label="Abrir menú"
        aria-expanded={menuAbierto}
      >
        <Menu size={22} />
      </button>

      {/* Overlay móvil */}
      {menuAbierto && (
        <div
          className={styles.overlay}
          onClick={() => setMenuAbiertoEn(null)}
          aria-hidden="true"
        />
      )}

      {/* Drawer móvil / Sidebar desktop */}
      <div
        className={`${styles.navWrapper} ${menuAbierto ? styles.navAbierto : ""}`}
      >
        <button
          className={styles.cerrarDrawer}
          onClick={() => setMenuAbiertoEn(null)}
          aria-label="Cerrar menú"
        >
          <X size={20} />
        </button>
        {sidebar}
      </div>

      <main className={styles.contenido}>
        <header className={styles.topbar}>
          <div className={styles.topbarSpacer} />

          <div className={styles.topbarAcciones}>
            <div className={styles.topbarUsuario}>
              <div className={styles.avatar} aria-hidden="true">
                {iniciales(usuario?.nombre ?? "A")}
              </div>
              <span className={styles.topbarNombre}>
                {usuario?.nombre ?? "Admin"}
              </span>
            </div>

            <button
              type="button"
              className={styles.botonNotificaciones}
              aria-label="Notificaciones"
              title="Notificaciones"
            >
              <Bell size={16} aria-hidden="true" />
            </button>

            <button
              onClick={handleLogout}
              className={styles.botonSalirTopbar}
              aria-label="Cerrar sesión"
              title="Cerrar sesión"
            >
              <LogOut size={14} aria-hidden="true" />
            </button>
          </div>
        </header>

        <div className={styles.contenidoInterno}>
          <Outlet />
        </div>
      </main>

      <ToastContainer />
    </div>
  );
}
