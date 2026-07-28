import 'class_info.dart';
import 'common.dart';

class CreateDeck {
  final String title;
  final String? description;
  final int? parentId;

  CreateDeck({required this.title, this.description, this.parentId});

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null) 'description': description,
        if (parentId != null) 'parent_id': parentId,
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
  final int? parentId;

  UpdateDeck({this.title, this.description, this.parentId});

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (parentId != null) 'parent_id': parentId,
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
  final int? parentId;

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
    this.parentId,
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
        parentId: json['parent_id'],
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
  final String sortField;
  final List<NoteTemplate> templates;
  final int noteCount;

  bool get hasNotes => noteCount > 0;

  NoteType({
    required this.id,
    required this.name,
    required this.fieldNames,
    required this.sortField,
    required this.templates,
    required this.noteCount,
  });

  factory NoteType.fromJson(Map<String, dynamic> json) => NoteType(
        id: json['id'],
        name: json['name'],
        fieldNames:
            (json['field_names'] as List).map((e) => e as String).toList(),
        sortField: json['sort_field'] ?? '',
        templates: (json['templates'] as List)
            .map((t) => NoteTemplate.fromJson(t))
            .toList(),
        noteCount: json['note_count'] is int ? json['note_count'] as int : 0,
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

class CreateNoteType {
  final String name;
  final List<String> fieldNames;
  final String? sortField;
  final List<CreateNoteTemplate> templates;

  CreateNoteType({
    required this.name,
    required this.fieldNames,
    this.sortField,
    required this.templates,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'field_names': fieldNames,
        if (sortField != null) 'sort_field': sortField,
        'templates': templates.map((t) => t.toJson()).toList(),
      };
}

class CreateNoteTemplate {
  final String name;
  final String frontPattern;
  final String backPattern;

  CreateNoteTemplate({
    required this.name,
    required this.frontPattern,
    required this.backPattern,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'front_pattern': frontPattern,
        'back_pattern': backPattern,
      };
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
  final List<int> deckIds;
  final int noteTypeId;
  final String noteTypeName;
  final Map<String, dynamic> fields;
  final List<CardSummary> cards;
  final DateTime createdAt;

  NoteResponse({
    required this.id,
    required this.deckIds,
    required this.noteTypeId,
    required this.noteTypeName,
    required this.fields,
    required this.cards,
    required this.createdAt,
  });

  factory NoteResponse.fromJson(Map<String, dynamic> json) => NoteResponse(
        id: json['id'],
        deckIds: (json['deck_ids'] as List).map((e) => e as int).toList(),
        noteTypeId: json['note_type_id'],
        noteTypeName: json['note_type_name'],
        fields: json['fields'],
        cards: (json['cards'] as List)
            .map((c) => CardSummary.fromJson(c))
            .toList(),
        createdAt: parseTimestamp(json['created_at']),
      );
}
