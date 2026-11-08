import 'dart:io';

import 'package:eye_disease_detection/core/formatters.dart';
import 'package:eye_disease_detection/data/auth_repository.dart';
import 'package:eye_disease_detection/data/disease_info.dart';
import 'package:eye_disease_detection/data/history_record.dart';
import 'package:eye_disease_detection/ml/model_config.dart';
import 'package:eye_disease_detection/ml/prediction_result.dart';
import 'package:eye_disease_detection/ml/preprocess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const labels = ['cataract', 'diabetic_retinopathy', 'glaucoma', 'normal', 'not_fundus'];

  group('Preprocess', () {
    test('UT-01 224x224 red bitmap -> buffer of raw 0-255 floats', () {
      final im = img.Image(width: 224, height: 224, numChannels: 3);
      img.fill(im, color: img.ColorRgb8(255, 0, 0));
      final buf = Preprocess.toInputBuffer(im);
      expect(buf.length, 224 * 224 * 3);
      expect(buf[0], 255);
      expect(buf[1], 0);
      expect(buf[2], 0);
    });

    test('UT-02 non-square bitmap is resized to 224x224 without exception', () {
      final im = img.Image(width: 640, height: 300, numChannels: 3);
      img.fill(im, color: img.ColorRgb8(120, 60, 30));
      final buf = Preprocess.run(im);
      expect(buf.length, 224 * 224 * 3);
    });

    test('crop_dark_border removes a black frame', () {
      final im = img.Image(width: 200, height: 100, numChannels: 3);
      img.fill(im, color: img.ColorRgb8(0, 0, 0));
      img.fillRect(im, x1: 50, y1: 0, x2: 149, y2: 99, color: img.ColorRgb8(200, 80, 40));
      final out = Preprocess.cropDarkBorder(im);
      expect(out.width, 100);
      expect(out.height, 100);
    });

    test('crop_dark_border keeps the image when < 20% would remain', () {
      final im = img.Image(width: 100, height: 100, numChannels: 3);
      img.fill(im, color: img.ColorRgb8(0, 0, 0));
      img.fillRect(im, x1: 0, y1: 0, x2: 9, y2: 9, color: img.ColorRgb8(255, 255, 255));
      expect(Preprocess.cropDarkBorder(im).width, 100);
    });

    test('pad_to_square adds black bars', () {
      final im = img.Image(width: 100, height: 50, numChannels: 3);
      img.fill(im, color: img.ColorRgb8(255, 255, 255));
      final sq = Preprocess.padToSquare(im);
      expect(sq.width, 100);
      expect(sq.height, 100);
      expect(sq.getPixel(50, 0).r, 0);
      expect(sq.getPixel(50, 50).r, 255);
    });

    test('downscale_max_448 keeps aspect ratio', () {
      final im = img.Image(width: 1000, height: 500, numChannels: 3);
      final out = Preprocess.downscaleMax(im, 448);
      expect(out.width, 448);
      expect(out.height, 224);
    });

    test('flipBuffer mirrors horizontally', () {
      final im = img.Image(width: 224, height: 224, numChannels: 3);
      img.fill(im, color: img.ColorRgb8(0, 0, 0));
      im.setPixelRgb(0, 0, 10, 20, 30);
      final buf = Preprocess.toInputBuffer(im);
      final flipped = Preprocess.flipBuffer(buf);
      final last = 223 * 3;
      expect(flipped.sublist(last, last + 3), [10, 20, 30]);
      expect(flipped[0], 0);
    });
  });

  group('Reject rule', () {
    PredictionResult run(List<double> p, {double t = 0.70}) =>
        PredictionResult.fromProbabilities(probs: p, labels: labels, minConfidence: t);

    test('UT-03 glaucoma 0.92 >= 0.70 is ACCEPTED', () {
      final r = run([0.02, 0.03, 0.92, 0.02, 0.01]);
      expect(r.status, PredictionStatus.accepted);
      expect(r.label, 'glaucoma');
    });

    test('UT-04 normal 0.55 < 0.70 is REJECTED', () {
      final r = run([0.1, 0.1, 0.15, 0.55, 0.1]);
      expect(r.status, PredictionStatus.rejected);
      expect(r.label, isNull);
      expect(r.topLabel, 'normal');
    });

    test('UT-05 not_fundus top is REJECTED', () {
      expect(run([0.01, 0.01, 0.01, 0.02, 0.95]).status, PredictionStatus.rejected);
    });

    test('UT-06 confidence exactly at threshold is ACCEPTED', () {
      expect(run([0.70, 0.1, 0.1, 0.05, 0.05]).status, PredictionStatus.accepted);
    });
  });

  group('Model files', () {
    test('UT-07 labels.txt has 5 lines, index 4 = not_fundus', () {
      final lines = File('assets/model/labels.txt')
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 5);
      expect(lines, labels);
      expect(lines[4], 'not_fundus');
    });

    test('UT-08 model_config.json parses; missing file -> default 0.70', () {
      final cfg = ModelConfig.parse(File('assets/model/model_config.json').readAsStringSync());
      expect(cfg.labels, labels);
      expect(cfg.inputSize, 224);
      expect(cfg.minConfidence, closeTo(0.6, 1e-9));
      expect(cfg.rejectLabel, 'not_fundus');
      expect(cfg.ttaHorizontalFlip, isTrue);
      expect(File('assets/model/${cfg.modelFile}').existsSync(), isTrue);

      expect(ModelConfig.parse(null).minConfidence, 0.70);
      expect(ModelConfig.parse('{broken').minConfidence, 0.70);
    });
  });

  group('Validators', () {
    test('UT-09 email', () {
      expect(Validators.email('abc'), 'err_email');
      expect(Validators.email('a@b.com'), isNull);
      expect(Validators.email(''), 'err_required');
    });

    test('UT-10 password length', () {
      expect(Validators.password('12345'), 'err_password_short');
      expect(Validators.password('123456'), isNull);
    });

    test('UT-11 password confirmation', () {
      expect(Validators.confirm('abcdef', 'abcdeg'), 'err_password_match');
      expect(Validators.confirm('abcdef', 'abcdef'), isNull);
    });

    test('OTP must be 6 digits', () {
      expect(Validators.otp('12345'), 'err_otp');
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp('12a456'), 'err_otp');
    });
  });

  group('Formatters', () {
    test('UT-12 date format "12 Oct 2026, 3:45 PM"', () {
      final dt = DateTime(2026, 10, 12, 15, 45);
      expect(Formatters.dateTime(dt), '12 Oct 2026, 3:45 PM');
    });

    test('UT-13 confidence: 1 decimal, capped at 99.9%', () {
      expect(Formatters.confidence(0.92437), '92.4%');
      expect(Formatters.confidence(0.9999), '99.9%');
      expect(Formatters.confidence(1.0), '99.9%');
      expect(Formatters.confidence(0.0), '0.0%');
    });

    test('mask email', () {
      expect(Formatters.maskEmail('khayyam@gmail.com'), 'k***@gmail.com');
    });
  });

  group('Auth error mapping', () {
    test('maps Supabase errors to friendly keys', () {
      expect(AuthRepository.mapError('invalid_credentials', 'Invalid login credentials', '400'),
          'err_login');
      expect(AuthRepository.mapError('email_not_confirmed', 'Email not confirmed', '400'),
          'err_not_verified');
      expect(AuthRepository.mapError('user_already_exists', 'User already registered', '422'),
          'err_email_in_use');
      expect(AuthRepository.mapError('otp_expired', 'Token has expired or is invalid', '403'),
          'err_otp_invalid');
      expect(AuthRepository.mapError(null, 'Email rate limit exceeded', '429'),
          'err_rate_limit');
    });
  });

  test('UT-17 disease_info.json: 4 classes, every section non-empty', () {
    final info = DiseaseInfoRepository.parse(File('assets/disease_info.json').readAsStringSync());
    expect(info.keys.toSet(), {'cataract', 'diabetic_retinopathy', 'glaucoma', 'normal'});
    for (final d in info.values) {
      expect(d.title, isNotEmpty);
      expect(d.about, isNotEmpty);
      expect(d.symptoms, isNotEmpty);
      expect(d.prevention, isNotEmpty);
      expect(d.treatment, isNotEmpty);
      expect(d.seeDoctor, isNotEmpty);
    }
  });

  test('HistoryRecord JSON round-trip and Supabase row', () {
    final r = HistoryRecord(
      id: 'abc',
      userId: 'u1',
      label: 'glaucoma',
      confidence: 0.92,
      probabilities: const {'glaucoma': 0.92, 'normal': 0.08},
      createdAt: DateTime.utc(2026, 10, 12, 10),
      remoteImagePath: 'u1/abc.jpg',
      localImagePath: '/x/abc.jpg',
    );
    final back = HistoryRecord.fromJson(r.toJson());
    expect(back.id, 'abc');
    expect(back.label, 'glaucoma');
    expect(back.probabilities['normal'], 0.08);
    expect(back.synced, isFalse);
    final row = r.toRow();
    expect(row['client_id'], 'abc');
    expect(row['predicted_label'], 'glaucoma');
    expect(row.containsKey('user_id'), isFalse); // filled by auth.uid() default
  });
}
