import 'package:flutter/foundation.dart';
import '../core/cache.dart';
import '../data/volgatech_api.dart';
import '../models/exams.dart';

class ExamsController extends ChangeNotifier {
  ExamsController(this._api, this._personId, this._cache);
  final VolgatechApi _api;
  final int _personId;
  final JsonCache _cache;

  List<StudyYear> years = [];
  StudyYear? selectedYear;
  List<Exam> exams = [];

  bool loadingYears = false;
  bool loadingExams = false;
  String? error;
  bool fromCache = false;
  DateTime? cacheSavedAt;

  String get _yearsKey => 'studyyears_$_personId';
  String _examsKey(int year) => 'exams_${_personId}_$year';

  Future<void> init() async {
    await _loadYears();
    if (selectedYear != null) {
      await loadExams(selectedYear!);
    }
  }

  Future<void> _loadYears() async {
    loadingYears = true;
    error = null;
    notifyListeners();
    try {
      years = await _api.getStudyYears(_personId);
      await _cache.put(_yearsKey, years.map((y) => y.toJson()).toList());
    } catch (e) {
      final cached = await _cache.get(_yearsKey);
      if (cached != null && cached.data is List) {
        years = (cached.data as List)
            .map((y) => StudyYear.fromJson(Map<String, dynamic>.from(y)))
            .toList();
      } else {
        error = e.toString();
      }
    } finally {
      // API returns years newest-first; default to the latest.
      if (years.isNotEmpty) selectedYear ??= years.first;
      loadingYears = false;
      notifyListeners();
    }
  }

  Future<void> selectYear(StudyYear year) async {
    if (selectedYear?.value == year.value) return;
    selectedYear = year;
    notifyListeners();
    await loadExams(year);
  }

  Future<void> loadExams(StudyYear year) async {
    loadingExams = true;
    error = null;
    fromCache = false;
    cacheSavedAt = null;
    notifyListeners();
    try {
      exams = await _api.getExams(_personId, year.value);
      await _cache.put(_examsKey(year.value), exams.map((e) => e.toJson()).toList());
    } catch (e) {
      final cached = await _cache.get(_examsKey(year.value));
      if (cached != null && cached.data is List) {
        exams = (cached.data as List)
            .map((e) => Exam.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        fromCache = true;
        cacheSavedAt = cached.savedAt;
      } else {
        exams = [];
        error = e.toString();
      }
    } finally {
      loadingExams = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (selectedYear != null) await loadExams(selectedYear!);
  }
}
