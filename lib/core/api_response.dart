List<dynamic> readList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    final results = data['results'];
    if (results is List) return results;
    final wrapped = data['data'];
    if (wrapped is List) return wrapped;
    if (wrapped is Map && wrapped['results'] is List) {
      return wrapped['results'] as List;
    }
  }
  return const [];
}

Map<String, dynamic> readMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

Map<String, dynamic> readDataMap(dynamic data) {
  final map = readMap(data);
  final wrapped = map['data'];
  if (wrapped is Map<String, dynamic>) return wrapped;
  if (wrapped is Map) return Map<String, dynamic>.from(wrapped);
  return map;
}
