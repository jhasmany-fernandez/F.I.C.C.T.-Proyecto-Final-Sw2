import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:heatmapper/features/proyectos/data/datasources/proyecto_remote_datasource.dart';
import 'package:heatmapper/features/proyectos/data/models/proyecto_model.dart';
import 'package:heatmapper/features/proyectos/data/repositories/proyecto_repository_impl.dart';
import 'package:heatmapper/features/proyectos/domain/entities/proyecto.dart';
import 'package:heatmapper/features/proyectos/domain/repositories/proyecto_repository.dart';

// Mocks ──────────────────────────────────────────────────────────────────────
class MockProyectoRemoteDatasource extends Mock
    implements ProyectoRemoteDatasource {}

// Helpers ────────────────────────────────────────────────────────────────────
final _ahora = DateTime(2026, 4, 24);

ProyectoModel _modelo({
  int id = 1,
  String nombre = 'Edificio A',
  String cliente = 'Bulldog Tech.',
  String estado = 'NUEVO',
}) {
  return ProyectoModel(
    id: id,
    nombre: nombre,
    cliente: cliente,
    descripcion: null,
    estado: estado,
    createdAt: _ahora.toIso8601String(),
    updatedAt: _ahora.toIso8601String(),
  );
}

void main() {
  late ProyectoRepositoryImpl repositorio;
  late MockProyectoRemoteDatasource mockRemote;

  setUp(() {
    mockRemote = MockProyectoRemoteDatasource();
    repositorio = ProyectoRepositoryImpl(mockRemote);
  });

  // ── obtenerActivos ─────────────────────────────────────────────────────────
  group('obtenerActivos', () {
    test('retorna lista de proyectos activos mapeados a dominio', () async {
      when(() => mockRemote.obtenerActivos()).thenAnswer(
          (_) async => [_modelo(), _modelo(id: 2, nombre: 'Torre B')]);

      final lista = await repositorio.obtenerActivos();

      expect(lista.length, 2);
      expect(lista.first.nombre, 'Edificio A');
      expect(lista.first.estado, EstadoProyecto.nuevo);
    });

    test('lanza ProyectoStorageException si el datasource lanza excepción',
        () async {
      when(() => mockRemote.obtenerActivos())
          .thenThrow(Exception('fallo de red'));

      expect(
        () => repositorio.obtenerActivos(),
        throwsA(isA<ProyectoStorageException>()),
      );
    });
  });

  // ── crear ──────────────────────────────────────────────────────────────────
  group('crear', () {
    test('crea proyecto y retorna entidad con id generado', () async {
      when(() => mockRemote.crear(
            nombre: any(named: 'nombre'),
            clienteId: any(named: 'clienteId'),
            descripcion: any(named: 'descripcion'),
          )).thenAnswer((_) async => _modelo(id: 5));

      final proyecto = await repositorio.crear(
        nombre: 'Edificio A',
      );

      expect(proyecto.id, 5);
      expect(proyecto.estado, EstadoProyecto.nuevo);
    });

    test('lanza ProyectoNombreVacioException si el nombre está vacío', () {
      expect(
        () => repositorio.crear(nombre: '   '),
        throwsA(isA<ProyectoNombreVacioException>()),
      );
      verifyNever(() => mockRemote.crear(
            nombre: any(named: 'nombre'),
            clienteId: any(named: 'clienteId'),
            descripcion: any(named: 'descripcion'),
          ));
    });
  });

  // ── actualizar ─────────────────────────────────────────────────────────────
  group('actualizar', () {
    test('actualiza y retorna proyecto actualizado', () async {
      when(() => mockRemote.actualizar(
                id: any(named: 'id'),
                nombre: any(named: 'nombre'),
                clienteId: any(named: 'clienteId'),
                descripcion: any(named: 'descripcion'),
              ))
          .thenAnswer((_) async =>
              _modelo(nombre: 'Nuevo Nombre', cliente: 'Otro Cliente'));

      final proyecto = await repositorio.actualizar(
        id: 1,
        nombre: 'Nuevo Nombre',
      );

      expect(proyecto.nombre, 'Nuevo Nombre');
      expect(proyecto.cliente, 'Otro Cliente');
    });

    test('lanza ProyectoNombreVacioException si el nombre queda vacío', () {
      expect(
        () => repositorio.actualizar(id: 1, nombre: ''),
        throwsA(isA<ProyectoNombreVacioException>()),
      );
    });

    test('lanza ProyectoNoEncontradoException si el proyecto no existe',
        () async {
      when(() => mockRemote.actualizar(
            id: any(named: 'id'),
            nombre: any(named: 'nombre'),
            clienteId: any(named: 'clienteId'),
            descripcion: any(named: 'descripcion'),
          )).thenThrow(ProyectoNoEncontradoException(99));

      await expectLater(
        () => repositorio.actualizar(id: 99, nombre: 'X'),
        throwsA(isA<ProyectoNoEncontradoException>()),
      );
    });
  });

  // ── archivar ───────────────────────────────────────────────────────────────
  group('archivar', () {
    test('delega al datasource remoto', () async {
      when(() => mockRemote.archivar(any())).thenAnswer((_) async {});

      await repositorio.archivar(1);

      verify(() => mockRemote.archivar(1)).called(1);
    });

    test('lanza ProyectoNoEncontradoException si el proyecto no existe',
        () async {
      when(() => mockRemote.archivar(any()))
          .thenThrow(ProyectoNoEncontradoException(99));

      await expectLater(
        () => repositorio.archivar(99),
        throwsA(isA<ProyectoNoEncontradoException>()),
      );
    });
  });

  // ── eliminar ───────────────────────────────────────────────────────────────
  group('eliminar', () {
    test('elimina proyecto correctamente', () async {
      when(() => mockRemote.eliminar(any())).thenAnswer((_) async {});

      await repositorio.eliminar(1);

      verify(() => mockRemote.eliminar(1)).called(1);
    });

    test('lanza ProyectoConReportesException si tiene reportes exportados',
        () async {
      when(() => mockRemote.eliminar(any()))
          .thenThrow(const ProyectoConReportesException());

      await expectLater(
        () => repositorio.eliminar(1),
        throwsA(isA<ProyectoConReportesException>()),
      );
    });

    test('lanza ProyectoNoEncontradoException si el proyecto no existe',
        () async {
      when(() => mockRemote.eliminar(any()))
          .thenThrow(ProyectoNoEncontradoException(99));

      await expectLater(
        () => repositorio.eliminar(99),
        throwsA(isA<ProyectoNoEncontradoException>()),
      );
    });
  });
}
