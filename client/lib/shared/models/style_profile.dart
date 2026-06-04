class StyleProfile {
  final int id;
  final int userId;
  final String name;
  final String? entityName;
  final String? entityType;
  final String tone;
  final String structure;
  final String lengthPreset;
  final int? charMin;
  final int? charMax;
  final String emojiUsage;
  final String jargonHandling;
  final String callToAction;
  final String hashtagStyle;
  final String? additionalInstructions;

  StyleProfile({required this.id, required this.userId, required this.name, this.entityName, this.entityType, required this.tone, required this.structure, required this.lengthPreset, this.charMin, this.charMax, required this.emojiUsage, required this.jargonHandling, required this.callToAction, required this.hashtagStyle, this.additionalInstructions});

  factory StyleProfile.fromJson(Map<String, dynamic> json) => StyleProfile(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        name: json['name'] as String,
        entityName: json['entity_name'] as String?,
        entityType: json['entity_type'] as String?,
        tone: json['tone'] as String? ?? 'semi_formal',
        structure: json['structure'] as String? ?? 'paragraph',
        lengthPreset: json['length_preset'] as String? ?? 'medium',
        charMin: json['char_min'] as int?,
        charMax: json['char_max'] as int?,
        emojiUsage: json['emoji_usage'] as String? ?? 'minimal',
        jargonHandling: json['jargon_handling'] as String? ?? 'simplify',
        callToAction: json['call_to_action'] as String? ?? 'none',
        hashtagStyle: json['hashtag_style'] as String? ?? 'none',
        additionalInstructions: json['additional_instructions'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'user_id': userId, 'name': name, 'entity_name': entityName, 'entity_type': entityType, 'tone': tone, 'structure': structure, 'length_preset': lengthPreset, 'char_min': charMin, 'char_max': charMax, 'emoji_usage': emojiUsage, 'jargon_handling': jargonHandling, 'call_to_action': callToAction, 'hashtag_style': hashtagStyle, 'additional_instructions': additionalInstructions};
}
