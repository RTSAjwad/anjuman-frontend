import 'class_info.dart';
import 'common.dart';

class CreateDeck {
  final String title;
  final String? description;

  CreateDeck({required this.title, this.description});

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null) 'description': description,
      };
}

class RenameDeck {
  final String title;

  RenameDeck({required this.title});

  Map<String, dynamic> toJson() => {'title': title};
}

class UpdateDeck {
  final String? title;
  final String? description;

  UpdateDeck({this.title, this.description});

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      };
}

class ShareDeck {
  final int userId;

  ShareDeck({required this.userId});

  Map<String, dynamic> toJson() => {'user_id': userId};
}

class DeckResponse {
  final int id;
  final int schoolId;
  final String title;
  final String? description;
  final int createdBy;
  final String? ownerEmail;
  final String? ownerFirstName;
  final String? ownerLastName;
  final int? originalDeckId;
  final DateTime createdAt;
  final int? newCount;
  final int? learningCount;
  final int? relearningCount;
  final int? dueCount;
  final int? totalCount;

  bool get hasCards => totalCount != null && totalCount! > 0;

  String get ownerDisplayName {
    final name = '$ownerFirstName $ownerLastName'.trim();
    return name.isNotEmpty ? name : (ownerEmail ?? 'User #$createdBy');
  }

  DeckResponse({
    required this.id,
    required this.schoolId,
    required this.title,
    this.description,
    required this.createdBy,
    this.ownerEmail,
    this.ownerFirstName,
    this.ownerLastName,
    this.originalDeckId,
    required this.createdAt,
    this.newCount,
    this.learningCount,
    this.relearningCount,
    this.dueCount,
    this.totalCount,
  });

  factory DeckResponse.fromJson(Map<String, dynamic> json) => DeckResponse(
        id: json['id'],
        schoolId: json['school_id'],
        title: json['title'],
        description: json['description'],
        createdBy: json['created_by'],
        ownerEmail: json['owner_email'],
        ownerFirstName: json['owner_first_name'],
        ownerLastName: json['owner_last_name'],
        originalDeckId: json['original_deck_id'],
        createdAt: parseTimestamp(json['created_at']),
        newCount: json['new_count'],
        learningCount: json['learning_count'],
        relearningCount: json['relearning_count'],
        dueCount: json['due_count'],
        totalCount: json['total_count'],
      );
}

class CollaboratorResponse {
  final int userId;
  final String email;
  final String firstName;
  final String lastName;
  final int sharedAt;

  CollaboratorResponse({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.sharedAt,
  });

  String get displayName => '$firstName $lastName'.trim();

  factory CollaboratorResponse.fromJson(Map<String, dynamic> json) =>
      CollaboratorResponse(
        userId: json['user_id'],
        email: json['email'],
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
        sharedAt: json['shared_at'],
      );
}

class DeckDetailResponse {
  final DeckResponse deck;
  final List<CollaboratorResponse> collaborators;
  final List<ClassInfo> classes;

  DeckDetailResponse(
      {required this.deck, required this.collaborators, required this.classes});

  factory DeckDetailResponse.fromJson(Map<String, dynamic> json) =>
      DeckDetailResponse(
        deck: DeckResponse.fromJson(json['deck']),
        collaborators: (json['collaborators'] as List)
            .map((c) => CollaboratorResponse.fromJson(c))
            .toList(),
        classes: (json['classes'] as List? ?? [])
            .map((c) => ClassInfo.fromJson(c))
            .toList(),
      );
}

// Notes

class NoteType {
  final int id;
  final String name;
  final List<String> fieldNames;
  final List<NoteTemplate> templates;

  NoteType({
    required this.id,
    required this.name,
    required this.fieldNames,
    required this.templates,
  });

  factory NoteType.fromJson(Map<String, dynamic> json) => NoteType(
        id: json['id'],
        name: json['name'],
        fieldNames:
            (json['field_names'] as List).map((e) => e as String).toList(),
        templates: (json['templates'] as List)
            .map((t) => NoteTemplate.fromJson(t))
            .toList(),
      );
}

class NoteTemplate {
  final int index;
  final String name;
  final String frontPattern;
  final String backPattern;

  NoteTemplate({
    required this.index,
    required this.name,
    required this.frontPattern,
    required this.backPattern,
  });

  factory NoteTemplate.fromJson(Map<String, dynamic> json) => NoteTemplate(
        index: json['index'],
        name: json['name'],
        frontPattern: json['front_pattern'],
        backPattern: json['back_pattern'],
      );
}

class CreateNote {
  final int noteTypeId;
  final Map<String, dynamic> fields;

  CreateNote({required this.noteTypeId, required this.fields});

  Map<String, dynamic> toJson() =>
      {'note_type_id': noteTypeId, 'fields': fields};
}

class UpdateNote {
  final int? noteTypeId;
  final Map<String, dynamic>? fields;

  UpdateNote({this.noteTypeId, this.fields});

  Map<String, dynamic> toJson() => {
        if (noteTypeId != null) 'note_type_id': noteTypeId,
        if (fields != null) 'fields': fields,
      };
}

class CardSummary {
  final int id;
  final int templateIndex;
  final String front;
  final String back;

  CardSummary({
    required this.id,
    required this.templateIndex,
    required this.front,
    required this.back,
  });

  factory CardSummary.fromJson(Map<String, dynamic> json) => CardSummary(
        id: json['id'],
        templateIndex: json['template_index'],
        front: json['front'],
        back: json['back'],
      );
}

class NoteResponse {
  final int id;
  final int deckId;
  final int noteTypeId;
  final String noteTypeName;
  final Map<String, dynamic> fields;
  final List<CardSummary> cards;
  final DateTime createdAt;

  NoteResponse({
    required this.id,
    required this.deckId,
    required this.noteTypeId,
    required this.noteTypeName,
    required this.fields,
    required this.cards,
    required this.createdAt,
  });

  factory NoteResponse.fromJson(Map<String, dynamic> json) => NoteResponse(
        id: json['id'],
        deckId: json['deck_id'],
        noteTypeId: json['note_type_id'],
        noteTypeName: json['note_type_name'],
        fields: json['fields'],
        cards: (json['cards'] as List)
            .map((c) => CardSummary.fromJson(c))
            .toList(),
        createdAt: parseTimestamp(json['created_at']),
      );
}
