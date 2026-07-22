class StudentStats {
  final int studentId;
  final int totalReviews;
  final int reviewsToday;
  final double retentionRate;
  final double averageRating;
  final int cardsTotal;
  final int cardsMastered;
  final int cardsLearning;
  final int cardsStruggling;
  final int studyStreakDays;
  final int timeSpentTodaySeconds;
  final int sessionsThisWeek;

  StudentStats({
    required this.studentId,
    required this.totalReviews,
    required this.reviewsToday,
    required this.retentionRate,
    required this.averageRating,
    required this.cardsTotal,
    required this.cardsMastered,
    required this.cardsLearning,
    required this.cardsStruggling,
    required this.studyStreakDays,
    required this.timeSpentTodaySeconds,
    required this.sessionsThisWeek,
  });

  factory StudentStats.fromJson(Map<String, dynamic> json) => StudentStats(
        studentId: json['student_id'],
        totalReviews: json['total_reviews'],
        reviewsToday: json['reviews_today'],
        retentionRate: (json['retention_rate'] as num).toDouble(),
        averageRating: (json['average_rating'] as num).toDouble(),
        cardsTotal: json['cards_total'],
        cardsMastered: json['cards_mastered'],
        cardsLearning: json['cards_learning'],
        cardsStruggling: json['cards_struggling'],
        studyStreakDays: json['study_streak_days'],
        timeSpentTodaySeconds: json['time_spent_today_seconds'],
        sessionsThisWeek: json['sessions_this_week'],
      );
}

class DailyPoint {
  final String date;
  final int reviews;
  final double avgRating;
  final double avgTimeMs;

  DailyPoint({
    required this.date,
    required this.reviews,
    required this.avgRating,
    required this.avgTimeMs,
  });

  factory DailyPoint.fromJson(Map<String, dynamic> json) => DailyPoint(
        date: json['date'],
        reviews: json['reviews'],
        avgRating: (json['avg_rating'] as num).toDouble(),
        avgTimeMs: (json['avg_time_ms'] as num).toDouble(),
      );
}

class StudentStatsWithEmail {
  final int studentId;
  final String email;
  final int totalReviews;
  final double retentionRate;
  final int cardsMastered;
  final String? lastActive;
  final int assignmentsCompleted;
  final int assignmentsTotal;

  StudentStatsWithEmail({
    required this.studentId,
    required this.email,
    required this.totalReviews,
    required this.retentionRate,
    required this.cardsMastered,
    this.lastActive,
    required this.assignmentsCompleted,
    required this.assignmentsTotal,
  });

  factory StudentStatsWithEmail.fromJson(Map<String, dynamic> json) =>
      StudentStatsWithEmail(
        studentId: json['student_id'],
        email: json['email'],
        totalReviews: json['total_reviews'],
        retentionRate: (json['retention_rate'] as num).toDouble(),
        cardsMastered: json['cards_mastered'],
        lastActive: json['last_active'],
        assignmentsCompleted: json['assignments_completed'],
        assignmentsTotal: json['assignments_total'],
      );
}

class DifficultCard {
  final int cardId;
  final String front;
  final double avgRating;
  final int totalReviews;

  DifficultCard({
    required this.cardId,
    required this.front,
    required this.avgRating,
    required this.totalReviews,
  });

  factory DifficultCard.fromJson(Map<String, dynamic> json) => DifficultCard(
        cardId: json['card_id'],
        front: json['front'],
        avgRating: (json['avg_rating'] as num).toDouble(),
        totalReviews: json['total_reviews'],
      );
}

class ClassAnalytics {
  final String className;
  final int studentsEnrolled;
  final int assignmentsGiven;
  final double averageCompletion;
  final double averageRetention;
  final List<DifficultCard> mostDifficultCards;
  final List<StudentStatsWithEmail> students;

  ClassAnalytics({
    required this.className,
    required this.studentsEnrolled,
    required this.assignmentsGiven,
    required this.averageCompletion,
    required this.averageRetention,
    required this.mostDifficultCards,
    required this.students,
  });

  factory ClassAnalytics.fromJson(Map<String, dynamic> json) => ClassAnalytics(
        className: json['class_name'],
        studentsEnrolled: json['students_enrolled'],
        assignmentsGiven: json['assignments_given'],
        averageCompletion: (json['average_completion'] as num).toDouble(),
        averageRetention: (json['average_retention'] as num).toDouble(),
        mostDifficultCards: (json['most_difficult_cards'] as List)
            .map((c) => DifficultCard.fromJson(c))
            .toList(),
        students: (json['students'] as List)
            .map((s) => StudentStatsWithEmail.fromJson(s))
            .toList(),
      );
}

class StudentDetail {
  final int studentId;
  final String email;
  final int totalReviews;
  final int reviewsToday;
  final double retentionRate;
  final double averageRating;
  final int cardsTotal;
  final int cardsMastered;
  final int cardsLearning;
  final int cardsStruggling;
  final int studyStreakDays;
  final int timeSpentTodaySeconds;
  final int sessionsThisWeek;
  final List<DailyPoint> daily;

  StudentDetail({
    required this.studentId,
    required this.email,
    required this.totalReviews,
    required this.reviewsToday,
    required this.retentionRate,
    required this.averageRating,
    required this.cardsTotal,
    required this.cardsMastered,
    required this.cardsLearning,
    required this.cardsStruggling,
    required this.studyStreakDays,
    required this.timeSpentTodaySeconds,
    required this.sessionsThisWeek,
    required this.daily,
  });

  factory StudentDetail.fromJson(Map<String, dynamic> json) => StudentDetail(
        studentId: json['student_id'],
        email: json['email'],
        totalReviews: json['total_reviews'],
        reviewsToday: json['reviews_today'],
        retentionRate: (json['retention_rate'] as num).toDouble(),
        averageRating: (json['average_rating'] as num).toDouble(),
        cardsTotal: json['cards_total'],
        cardsMastered: json['cards_mastered'],
        cardsLearning: json['cards_learning'],
        cardsStruggling: json['cards_struggling'],
        studyStreakDays: json['study_streak_days'],
        timeSpentTodaySeconds: json['time_spent_today_seconds'],
        sessionsThisWeek: json['sessions_this_week'],
        daily:
            (json['daily'] as List).map((d) => DailyPoint.fromJson(d)).toList(),
      );
}

// Dashboard

class ClassCard {
  final int classId;
  final String name;
  final int studentCount;
  final double avgRetention;
  final String? lastActivity;
  final double assignmentCompletion;

  ClassCard({
    required this.classId,
    required this.name,
    required this.studentCount,
    required this.avgRetention,
    this.lastActivity,
    required this.assignmentCompletion,
  });

  factory ClassCard.fromJson(Map<String, dynamic> json) => ClassCard(
        classId: json['class_id'],
        name: json['name'],
        studentCount: json['student_count'],
        avgRetention: (json['avg_retention'] as num).toDouble(),
        lastActivity: json['last_activity'],
        assignmentCompletion: (json['assignment_completion'] as num).toDouble(),
      );
}

class AttentionStudent {
  final int studentId;
  final String email;
  final String reason;
  final String? lastActive;
  final double retention;
  final String className;

  AttentionStudent({
    required this.studentId,
    required this.email,
    required this.reason,
    this.lastActive,
    required this.retention,
    required this.className,
  });

  factory AttentionStudent.fromJson(Map<String, dynamic> json) =>
      AttentionStudent(
        studentId: json['student_id'],
        email: json['email'],
        reason: json['reason'],
        lastActive: json['last_active'],
        retention: (json['retention'] as num).toDouble(),
        className: json['class_name'],
      );
}

class AssignmentCard {
  final int assignmentId;
  final String title;
  final String className;
  final int? dueAt;
  final double completion;
  final int totalStudents;
  final int completedCount;

  AssignmentCard({
    required this.assignmentId,
    required this.title,
    required this.className,
    this.dueAt,
    required this.completion,
    required this.totalStudents,
    required this.completedCount,
  });

  factory AssignmentCard.fromJson(Map<String, dynamic> json) => AssignmentCard(
        assignmentId: json['assignment_id'],
        title: json['title'],
        className: json['class_name'],
        dueAt: json['due_at'],
        completion: (json['completion'] as num).toDouble(),
        totalStudents: json['total_students'],
        completedCount: json['completed_count'],
      );
}

class DashboardResponse {
  final int totalStudents;
  final int activeClasses;
  final int reviewsToday;
  final double averageRetention;
  final List<ClassCard> classes;
  final List<AttentionStudent> attentionNeeded;
  final List<AssignmentCard> recentAssignments;

  DashboardResponse({
    required this.totalStudents,
    required this.activeClasses,
    required this.reviewsToday,
    required this.averageRetention,
    required this.classes,
    required this.attentionNeeded,
    required this.recentAssignments,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) =>
      DashboardResponse(
        totalStudents: json['total_students'],
        activeClasses: json['active_classes'],
        reviewsToday: json['reviews_today'],
        averageRetention: (json['average_retention'] as num).toDouble(),
        classes: (json['classes'] as List)
            .map((c) => ClassCard.fromJson(c))
            .toList(),
        attentionNeeded: (json['attention_needed'] as List)
            .map((s) => AttentionStudent.fromJson(s))
            .toList(),
        recentAssignments: (json['recent_assignments'] as List)
            .map((a) => AssignmentCard.fromJson(a))
            .toList(),
      );
}
