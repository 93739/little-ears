import 'dart:convert';
import 'package:flutter/services.dart';

enum TrackCategory {
  rhymes('英文童谣'),
  daily('生活英语'),
  stories('小故事');

  const TrackCategory(this.label);
  final String label;
}

class Caption {
  const Caption({
    required this.at,
    required this.english,
    required this.chinese,
  });
  final Duration at;
  final String english;
  final String chinese;
}

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.art,
    required this.color,
    required this.duration,
    required this.asset,
    required this.captions,
  });
  final String id, title, subtitle, art, asset;
  final TrackCategory category;
  final int color;
  final Duration duration;
  final List<Caption> captions;

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    art: json['art'] as String,
    category: TrackCategory.values.byName(json['category'] as String),
    color: 0xFF000000 | int.parse(json['color'] as String, radix: 16),
    duration: Duration(
      milliseconds: ((json['duration'] as num) * 1000).round(),
    ),
    asset: json['asset'] as String,
    captions: (json['captions'] as List)
        .map(
          (item) => Caption(
            at: Duration(milliseconds: ((item['at'] as num) * 1000).round()),
            english: item['en'] as String,
            chinese: item['zh'] as String,
          ),
        )
        .toList(growable: false),
  );

  Caption captionAt(Duration position) {
    var current = captions.first;
    for (final caption in captions) {
      if (caption.at > position) break;
      current = caption;
    }
    return current;
  }
}

Future<List<Track>> loadCatalog() async {
  final json =
      jsonDecode(await rootBundle.loadString('assets/catalog.json')) as List;
  return json
      .map((item) => Track.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
}

String clockLabel(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
