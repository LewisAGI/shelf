import 'package:flutter/material.dart';

import '../theme/shelf_theme.dart';

class ColorLabel {
  const ColorLabel({
    required this.id,
    required this.name,
    required this.meaning,
    required this.hex,
    required this.isDefault,
    required this.sortOrder,
  });

  static const orangeId = 'label_orange';
  static const purpleId = 'label_purple';

  final String id;
  final String name;
  final String meaning;
  final String hex;
  final bool isDefault;
  final int sortOrder;

  Color get color => parseHex(hex);

  ColorLabel copyWith({
    String? id,
    String? name,
    String? meaning,
    String? hex,
    bool? isDefault,
    int? sortOrder,
  }) {
    return ColorLabel(
      id: id ?? this.id,
      name: name ?? this.name,
      meaning: meaning ?? this.meaning,
      hex: hex ?? this.hex,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'meaning': meaning,
      'hex': hex,
      'is_default': isDefault ? 1 : 0,
      'sort_order': sortOrder,
    };
  }

  factory ColorLabel.fromMap(Map<String, Object?> map) {
    return ColorLabel(
      id: map['id']! as String,
      name: map['name']! as String,
      meaning: map['meaning']! as String,
      hex: map['hex']! as String,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  static Color parseHex(String hex) {
    var value = hex.trim();
    if (value.startsWith('#')) {
      value = value.substring(1);
    }
    if (value.length == 6) {
      value = 'FF$value';
    }
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      return ShelfColors.orange;
    }
    return Color(parsed);
  }

  /// Seeded on first launch. Orange is the default for new notes.
  static List<ColorLabel> seedDefaults() {
    return const [
      ColorLabel(
        id: orangeId,
        name: 'General note',
        meaning: 'A standing remark on this passage.',
        hex: ShelfColors.defaultOrangeHex,
        isDefault: true,
        sortOrder: 0,
      ),
      ColorLabel(
        id: purpleId,
        name: 'Further research',
        meaning: 'Come back to this — more reading needed.',
        hex: ShelfColors.defaultPurpleHex,
        isDefault: false,
        sortOrder: 1,
      ),
    ];
  }
}
