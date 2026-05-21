import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:heatmapper/features/proyectos/domain/entities/proyecto.dart';
import 'package:heatmapper/features/proyectos/domain/repositories/proyecto_repository.dart';
import 'package:heatmapper/features/proyectos/domain/usecases/obtener_proyectos_activos_usecase.dart';
import 'package:heatmapper/features/proyectos/domain/usecases/crear_proyecto_usecase.dart';
import 'package:heatmapper/features/proyectos/domain/usecases/actualizar_proyecto_usecase.dart';
import 'package:heatmapper/features/proyectos/domain/usecases/archivar_proyecto_usecase.dart';
import 'package:heatmapper/features/proyectos/domain/usecases/eliminar_proyecto_usecase.dart';
import 'package:heatmapper/features/proyectos/presentation/bloc/proyecto_cubit.dart';
import 'package:heatmapper/features/proyectos/presentation/bloc/proyecto_state.dart';

// Mocks ──────────────────────────────────────────────────────────────────────
class MockObtenerProyectosActivosUseCase extends Mock
    implements ObtenerProyectosActivosUseCase {}

class MockCrearProyectoUseCase extends Mock implements CrearProyectoUseCase {}

class MockActualizarProyectoUseCase extends Mock
    implements ActualizarProyectoUseCase {}

class MockArchivarProyectoUseCase extends Mock
    implements ArchivarProyectoUseCase {}

class MockEliminarProyectoUseCase extends Mock
    implements EliminarProyectoUseCase {}

// Helpers ────────────────────────────────────────────────────────────────────
final _ahora = DateTime(2026, 4, 24);

Proyecto _proyecto({int id = 1, String nombre = 'Edificio A'}) => Proyecto(
      id: id,
      nombre: nombre,
      cliente: 'Bulldog Tech.',
      estado: EstadoProyecto.nuevo,
      createdAt: _ahora,
      updatedAt: _ahora,
    );

void main() {
  late ProyectoCubit cubit;
  late MockObtenerProyectosActivosUseCase mockObtener;
  late MockCrearProyectoUseCase mockCrear;
  late MockActualizarProyectoUseCase mockActualizar;
  late MockArchivarProyectoUseCase mockArchivar;
  late MockEliminarProyectoUseCase mockEliminar;

  setUp(() {
    mockObtener = MockObtenerProyectosActivosUseCase();
    mockCrear = MockCrearProyectoUseCase();
    mockActualizar = MockActualizarProyectoUseCase();
    mockArchivar = MockArchivarProyectoUseCase();
    mockEliminar = MockEliminarProyectoUseCase();

    cubit = ProyectoCubit(
      obtenerActivos: mockObtener,
      crear: mockCrear,
      actualizar: mockActualizar,
      archivar: mockArchivar,
      eliminar: mockEliminar,
    );
  });

  tearDown(() => cubit.close());

  // ── cargarProyectos ────────────────────────────────────────────────────────
  group('cargarProyectos', () {
    blocTest<ProyectoCubit, ProyectoState>(
      'emite [Loading, ListaExitosa] cuando la carga es exitosa',
      build: () {
        when(() => mockObtener()).thenAnswer(
          (_) async => [_proyecto(), _proyecto(id: 2, nombre: 'Torre B')],
        );
        return cubit;
      },
      act: (c) => c.cargarProyectos(),
      expect: () => [
        const ProyectoLoading(),
        isA<ProyectoListaExitosa>()
            .having((s) => s.proyectos.length, 'length', 2),
      ],
    );

    blocTest<ProyectoCubit, ProyectoState>(
      'emite [Loading, Error] cuando el use case lanza excepción',
      build: () {
        when(() => mockObtener()).thenThrow(Exception('db error'));
        return cubit;
      },
      act: (c) => c.cargarProyectos(),
      expect: () => [
        const ProyectoLoading(),
        isA<ProyectoError>(),
      ],
    );
  });

  // ── crearProyecto ──────────────────────────────────────────────────────────
  group('crearProyecto', () {
    blocTest<ProyectoCubit, ProyectoState>(
      'emite [Loading, OperacionExitosa] al crear correctamente',
      build: () {
        when(() => mockCrear(
              nombre: any(named: 'nombre'),
              clienteId: any(named: 'clienteId'),
              descripcion: any(named: 'descripcion'),
            )).thenAnswer((_) async => _proyecto());
        return cubit;
      },
      act: (c) => c.crearProyecto(nombre: 'Edificio A'),
      expect: () => [
        const ProyectoLoading(),
        isA<ProyectoOperacionExitosa>(),
      ],
    );

    blocTest<ProyectoCubit, ProyectoState>(
      'emite [Loading, Error] si el nombre está vacío',
      build: () {
        when(() => mockCrear(
              nombre: any(named: 'nombre'),
              clienteId: any(named: 'clienteId'),
              descripcion: any(named: 'descripcion'),
            )).thenThrow(const ProyectoNombreVacioException());
        return cubit;
      },
      act: (c) => c.crearProyecto(nombre: ''),
      expect: () => [
        const ProyectoLoading(),
        isA<ProyectoError>().having(
          (s) => s.mensaje,
          'mensaje',
          contains('nombre'),
        ),
      ],
    );
  });

  // ── archivarProyecto ───────────────────────────────────────────────────────
  group('archivarProyecto', () {
    blocTest<ProyectoCubit, ProyectoState>(
      'emite [Loading, ListaExitosa] tras archivar correctamente',
      build: () {
        when(() => mockArchivar(any())).thenAnswer((_) async {});
        when(() => mockObtener()).thenAnswer((_) async => []);
        return cubit;
      },
      act: (c) => c.archivarProyecto(1),
      expect: () => [
        const ProyectoLoading(),
        isA<ProyectoListaExitosa>(),
      ],
    );
  });

  // ── eliminarProyecto ───────────────────────────────────────────────────────
  group('eliminarProyecto', () {
    blocTest<ProyectoCubit, ProyectoState>(
      'emite [Loading, Eliminado] al eliminar correctamente',
      build: () {
        when(() => mockEliminar(any())).thenAnswer((_) async {});
        return cubit;
      },
      act: (c) => c.eliminarProyecto(1),
      expect: () => [
        const ProyectoLoading(),
        const ProyectoEliminado(),
      ],
    );

    blocTest<ProyectoCubit, ProyectoState>(
      'emite [Loading, Error] cuando el proyecto tiene reportes exportados',
      build: () {
        when(() => mockEliminar(any()))
            .thenThrow(const ProyectoConReportesException());
        return cubit;
      },
      act: (c) => c.eliminarProyecto(1),
      expect: () => [
        const ProyectoLoading(),
        isA<ProyectoError>().having(
          (s) => s.mensaje,
          'mensaje',
          contains('reportes'),
        ),
      ],
    );
  });
}
