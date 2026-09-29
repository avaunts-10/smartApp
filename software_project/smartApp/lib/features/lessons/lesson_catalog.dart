/// A lesson authored for a subject.
///
/// Static for now (no backend table yet) — this is the one place both the
/// student-facing [lib/ui/pages/learning_screen.dart] Lessons tab and the
/// staff-facing [lib/ui/pages/ai_management_screen.dart] Lessons tab read
/// from, so the two always agree on what lessons exist. Move this to a
/// `/api/lessons` endpoint if lesson authoring needs to persist.
class Lesson {
  const Lesson({
    required this.title,
    required this.subject,
    required this.level,
    required this.description,
    required this.duration,
  });

  final String title;
  final String subject;
  final String level;
  final String description;
  final String duration;
}

const List<Lesson> lessonCatalog = [
  Lesson(
    title: 'Introduction to Algebra',
    subject: 'Mathematics',
    level: 'beginner',
    description: 'Algebra is a branch of mathematics dealing with symbols '
        'and the rules for manipulating those symbols.',
    duration: '30 min',
  ),
  Lesson(
    title: 'Python Basics',
    subject: 'Computer Science',
    level: 'beginner',
    description: 'Python is a high-level, interpreted programming language '
        'known for its simple, readable syntax.',
    duration: '45 min',
  ),
  Lesson(
    title: "Newton's Laws of Motion",
    subject: 'Science',
    level: 'intermediate',
    description: "Newton's First Law: an object at rest stays at rest, and "
        'an object in motion stays in motion unless acted on by an external '
        'force.',
    duration: '60 min',
  ),
];
