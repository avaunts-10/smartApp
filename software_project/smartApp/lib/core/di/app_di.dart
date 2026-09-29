import '../network/api_client.dart';
import '../../features/auth/auth_service.dart';
import '../../features/environment/environment_service.dart';
import '../../features/attendance/attendance_service.dart';
import '../../features/schedule/schedule_service.dart';
import '../../features/learning/learning_service.dart';
import '../../features/admin/admin_service.dart';
import '../../features/devices/device_service.dart';
import '../../features/notices/notice_service.dart';
import '../../features/quizzes/quiz_service.dart';

/// Backend base URL. Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4000
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);

final ApiClient apiClient = ApiClient(baseUrl: apiBaseUrl);

/// App-wide auth state. Import this anywhere you need the current user.
final AuthService authService = AuthService(apiClient);

final EnvironmentService environmentService = EnvironmentService(apiClient);

final AttendanceService attendanceService = AttendanceService(apiClient);

final DeviceService deviceService = DeviceService(apiClient);

final ScheduleService scheduleService = ScheduleService(apiClient);

final LearningService learningService = LearningService(apiClient);

final AdminService adminService = AdminService(apiClient);

final NoticeService noticeService = NoticeService(apiClient);

final QuizService quizService = QuizService(apiClient);
