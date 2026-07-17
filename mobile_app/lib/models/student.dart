class Student {
  final int? id;
  final String uniqueStudentId;
  final String name;
  final String index;
  final String contact;
  final String? photoUrl;

  const Student({
    this.id,
    required this.uniqueStudentId,
    required this.name,
    required this.index,
    required this.contact,
    this.photoUrl,
  });

  factory Student.fromMap(Map<String, Object?> map) {
    return Student(
      id: map['id'] as int?,
      uniqueStudentId: map['unique_student_id'] as String,
      name: map['name'] as String,
      index: map['student_index'] as String,
      contact: map['contact'] as String,
      photoUrl: map['photo_url'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'unique_student_id': uniqueStudentId,
      'name': name,
      'student_index': index,
      'contact': contact,
      'photo_url': photoUrl,
    };
  }
}

class AttendanceEntry {
  final int? id;
  final String uniqueStudentId;
  final String timestamp;
  final String status;
  final String syncStatus;

  const AttendanceEntry({
    this.id,
    required this.uniqueStudentId,
    required this.timestamp,
    required this.status,
    required this.syncStatus,
  });

  factory AttendanceEntry.fromMap(Map<String, Object?> map) {
    return AttendanceEntry(
      id: map['id'] as int?,
      uniqueStudentId: map['unique_student_id'] as String,
      timestamp: map['timestamp'] as String,
      status: map['status'] as String,
      syncStatus: map['sync_status'] as String,
    );
  }
}
