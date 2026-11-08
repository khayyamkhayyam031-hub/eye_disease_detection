import 'dart:convert';

import 'package:flutter/services.dart';

class DiseaseInfo {
  const DiseaseInfo({
    required this.key,
    required this.title,
    required this.summary,
    required this.about,
    required this.symptoms,
    required this.prevention,
    required this.treatment,
    required this.seeDoctor,
  });

  final String key;
  final String title;
  final String summary;
  final String about;
  final List<String> symptoms;
  final List<String> prevention;
  final List<String> treatment;
  final String seeDoctor;

  factory DiseaseInfo.fromJson(String key, Map<String, dynamic> j) {
    List<String> list(String k) =>
        ((j[k] as List?) ?? const []).map((e) => e.toString()).toList();
    return DiseaseInfo(
      key: key,
      title: (j['title'] ?? key).toString(),
      summary: (j['summary'] ?? '').toString(),
      about: (j['about'] ?? '').toString(),
      symptoms: list('symptoms'),
      prevention: list('prevention'),
      treatment: list('treatment'),
      seeDoctor: (j['see_doctor'] ?? '').toString(),
    );
  }
}

/// Loads `assets/disease_info.json` once (decoded off the UI thread) and caches it.
class DiseaseInfoRepository {
  DiseaseInfoRepository._();
  static final DiseaseInfoRepository instance = DiseaseInfoRepository._();

  static const order = ['cataract', 'diabetic_retinopathy', 'glaucoma', 'normal'];

  Future<Map<String, DiseaseInfo>>? _cache;

  Future<Map<String, DiseaseInfo>> load() => _cache ??= _load();

  Future<Map<String, DiseaseInfo>> _load() async {
    final text = await rootBundle.loadString('assets/disease_info.json');
    return parse(text);
  }

  static Map<String, DiseaseInfo> parse(String text) {
    final m = jsonDecode(text) as Map<String, dynamic>;
    return {
      for (final e in m.entries)
        e.key: DiseaseInfo.fromJson(e.key, e.value as Map<String, dynamic>),
    };
  }

  Future<DiseaseInfo?> get(String? key) async =>
      key == null ? null : (await load())[key];
}
