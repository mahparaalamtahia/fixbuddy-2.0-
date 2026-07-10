import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/area_service.dart';
import '../models/area_model.dart';

final areaServiceProvider = Provider<AreaService>((ref) => AreaService());

final activeAreasProvider = FutureProvider<List<AreaModel>>((ref) async {
  final areaService = ref.watch(areaServiceProvider);
  return await areaService.getActiveAreas();
});

final allAreasProvider = FutureProvider<List<AreaModel>>((ref) async {
  final areaService = ref.watch(areaServiceProvider);
  return await areaService.getAllAreas();
});
