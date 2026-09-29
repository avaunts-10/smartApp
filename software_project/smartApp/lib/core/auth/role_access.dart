/// Which named routes each account role can reach.
///
/// Single source of truth shared by the route guards in `main.dart` (so
/// typing a URL by hand can't reach a page your role has no business in)
/// and the sidebar in `app_shell.dart` (so the nav only ever offers pages
/// you're actually allowed to open). Keep both in sync by editing this map
/// alone.
///
/// The backend enforces the real security boundary (`requireRole` on
/// mutating endpoints in `backend/src/routes/*.js`) — this only shapes what
/// each role sees and can navigate to in the app.
const Map<String, Set<String>> roleRoutes = {
  // A student's own learning space: talk to their AI teacher, browse
  // subjects, and track their own progress. No classroom-operations tools.
  'student': {
    '/dashboard',
    '/ai-teacher',
    '/ai-teacher-3d',
    '/learning',
    '/progress',
    '/notices',
    '/materials',
    '/quizzes',
  },

  // A teacher runs the classroom day-to-day and manages the AI tutor's
  // lessons/rosters, but doesn't need the personal student-facing tutor UI.
  'teacher': {
    '/dashboard',
    '/environmental',
    '/device-control',
    '/attendance',
    '/students',
    '/analytics',
    '/schedule',
    '/ai-management',
    '/notices',
    '/materials',
    '/quizzes',
  },

  // Admin gets everything a teacher gets, plus full visibility into the
  // student-facing AI teaching assistant for oversight/support, plus
  // platform-wide account administration no other role can see.
  'admin': {
    '/dashboard',
    '/environmental',
    '/device-control',
    '/attendance',
    '/students',
    '/analytics',
    '/schedule',
    '/ai-management',
    '/ai-teacher',
    '/ai-teacher-3d',
    '/learning',
    '/progress',
    '/admin-users',
    '/notices',
    '/materials',
    '/quizzes',
  },
};

/// True if [role] is allowed to open [route]. Unknown roles/routes are
/// denied by default (fail closed).
bool canAccessRoute(String? role, String route) =>
    role != null && (roleRoutes[role]?.contains(route) ?? false);
