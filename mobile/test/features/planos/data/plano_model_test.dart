import 'package:flutter_test/flutter_test.dart';
import 'package:heatmapper/features/planos/data/models/plano_model.dart';
import 'package:heatmapper/features/planos/domain/entities/plano.dart';

void main() {
  group('PlanoModel.fromJson', () {
    final jsonBase = {
      'id': 1,
      'proyecto_id': 10,
      'nombre': 'Planta baja',
      'formato': 'png',
      'ancho_px': 1024,
      'alto_px': 768,
      'tamano_bytes': 204800,
      'url_firmada': '/planos/archivo/foo.png?exp=1&sig=abc',
      'calibrado': false,
      'escala_m_por_px': null,
      'distancia_real_m': null,
      'calibracion_x1': null,
      'calibracion_y1': null,
      'calibracion_x2': null,
      'calibracion_y2': null,
      'warning': null,
      'created_at': '2025-01-01T12:00:00',
      'updated_at': '2025-01-01T12:00:00',
    };

    test('parsea un plano sin calibrar', () {
      final m = PlanoModel.fromJson(jsonBase);
      expect(m.id, 1);
      expect(m.proyectoId, 10);
      expect(m.formato, FormatoPlano.png);
      expect(m.calibrado, isFalse);
      expect(m.escalaMPorPx, isNull);
      expect(m.warning, isNull);
    });

    test('parsea un plano calibrado con números int o double', () {
      final json = {
        ...jsonBase,
        'calibrado': true,
        'escala_m_por_px': 0.05,
        'distancia_real_m': 5,
        'calibracion_x1': 100,
        'calibracion_y1': 200,
        'calibracion_x2': 300.5,
        'calibracion_y2': 200,
        'warning': 'Solo se importó la primera página del PDF.',
        'formato': 'pdf',
      };
      final m = PlanoModel.fromJson(json);
      expect(m.calibrado, isTrue);
      expect(m.escalaMPorPx, 0.05);
      expect(m.distanciaRealM, 5.0);
      expect(m.calibracionX1, 100.0);
      expect(m.calibracionX2, 300.5);
      expect(m.formato, FormatoPlano.pdf);
      expect(m.warning, contains('PDF'));
    });

    test('FormatoPlano acepta jpeg y jpg como JPG', () {
      expect(FormatoPlano.fromString('jpeg'), FormatoPlano.jpg);
      expect(FormatoPlano.fromString('JPG'), FormatoPlano.jpg);
    });

    test('FormatoPlano lanza ArgumentError para formato inválido', () {
      expect(
        () => FormatoPlano.fromString('gif'),
        throwsArgumentError,
      );
    });
  });
}
