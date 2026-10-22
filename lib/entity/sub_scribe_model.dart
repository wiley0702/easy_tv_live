import 'dart:math';

class SubScribeModel {
  SubScribeModel({this.time, this.link, this.selected = false, this.local = false, String? id}) : id = id ?? newId();

  static String newId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  late String id;

  SubScribeModel.fromJson(dynamic json) {
    time = json['time'];
    id = json['id'] as String? ?? newId();
    link = json['link'];
    selected = json['selected'] ?? false;
    local = json['local'] ?? false;
  }
  String? time;
  String? link;
  bool? selected;
  bool? local;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['time'] = time;
    map['id'] = id;
    map['link'] = link;
    map['selected'] = selected ?? false;
    map['local'] = local ?? false;
    return map;
  }
}
