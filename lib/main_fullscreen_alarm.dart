import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const teal = Color(0xFF009E9A);
const darkBlue = Color(0xFF123C4A);
const muted = Color(0xFF647C84);
const paleTeal = Color(0xFFE5F8F7);

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();
  runApp(const DoseMateApp());
}

Future<void> initializeNotifications() async {
  tz_data.initializeTimeZones();
  try {
    final localTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
  } catch (error) {
    debugPrint('Could not set local timezone: $error');
  }

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidSettings);
  await notifications.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: onNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  final androidPlugin = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.requestNotificationsPermission();
}

int medicineNotificationId(String name) {
  var id = 0;
  for (final unit in name.toLowerCase().codeUnits) {
    id = (id * 31 + unit) & 0x7fffffff;
  }
  return id == 0 ? 1 : id;
}

void onNotificationResponse(NotificationResponse response) {
  if (response.actionId == 'snooze_10' && response.payload != null) {
    unawaited(_scheduleSnoozedReminder(response.payload!));
  }
}

// Handles the Snooze action when Android invokes the notification action
// while the app is in the background. Must remain a top-level entry point.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  if (response.actionId == 'snooze_10' && response.payload != null) {
    unawaited(_initializeTimezoneForBackground().then(
      (_) => _scheduleSnoozedReminder(response.payload!),
    ));
  }
}

Future<void> _initializeTimezoneForBackground() async {
  tz_data.initializeTimeZones();
  try {
    final localTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
  } catch (error) {
    debugPrint('Could not set background timezone: $error');
  }
}

Future<void> _scheduleSnoozedReminder(String payload) async {
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'your medicine';
    final dose = data['dose'] as String? ?? '';
    final id = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    await notifications.zonedSchedule(
      id: id == 0 ? 1 : id,
      title: 'Medicine reminder (snoozed)',
      body: 'Time to take $name${dose.isEmpty ? '' : ' ($dose)'}.',
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'meditick_medicine_reminders',
          'Medicine reminders',
          channelDescription: 'Daily reminders for your medicines',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  } catch (error) {
    debugPrint('Could not snooze medicine reminder: $error');
  }
}

Future<void> scheduleMedicineReminder(Medicine medicine) async {
  final match = RegExp(
  r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
  caseSensitive: false,
).firstMatch(medicine.time.trim());

  if (match == null) {
    debugPrint('Could not parse medicine reminder time: ${medicine.time}');
    return;
  }

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final period = match.group(3)?.toUpperCase();
  if (period == 'PM' && hour < 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return;

  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }

  await notifications.zonedSchedule(
    id: medicineNotificationId(medicine.name),
    title: 'Medicine reminder',
    body: 'Time to take ${medicine.name} (${medicine.dose}).',
    scheduledDate: scheduled,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'meditick_medicine_reminders',
        'Medicine reminders',
        channelDescription: 'Daily reminders for your medicines',
        importance: Importance.max,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze_10',
            'Snooze 10 min',
            showsUserInterface: true,
          ),
        ],
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
    payload: jsonEncode({'name': medicine.name, 'dose': medicine.dose}),
  );
}

class DoseMateApp extends StatelessWidget {
  const DoseMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediTick',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
      ),
      home: const SplashScreen(),
    );
  }
}

// SPLASH SCREEN

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final savedName = prefs.getString('userName') ?? 'User';

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isLoggedIn
              ? HomeScreen(userName: savedName)
              : const OnboardingScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1FFFF), Color(0xFFDDF7FA), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Image.asset(
                'assets/images/meditick_logo.png',
                width: 76,
                height: 76,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'MediTick',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'MEDICINE REMINDER',
              style: TextStyle(fontSize: 16, color: muted),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: teal),
          ],
        ),
      ),
    );
  }
}

// ONBOARDING

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  int current = 0;

  final slides = const [
    (
      icon: Icons.notifications_active_rounded,
      title: 'Never Miss Your Medicine',
      description: 'Get timely reminders and manage your medicines with ease.',
    ),
    (
      icon: Icons.calendar_month_rounded,
      title: 'Organize Your Schedule',
      description: 'Set medicine times and keep your daily routine organized.',
    ),
    (
      icon: Icons.medical_information_rounded,
      title: 'MEDICINE REMINDER',
      description: 'Stay on track with your medicine schedule every day.',
    ),
  ];

  void openLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  void continueNext() {
    if (current < slides.length - 1) {
      controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      openLogin();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: openLogin,
                  child: const Text('Skip', style: TextStyle(color: darkBlue)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: slides.length,
                  onPageChanged: (index) => setState(() => current = index),
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: const BoxDecoration(
                            color: paleTeal,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon, size: 100, color: teal),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: muted,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: current == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: current == index ? teal : const Color(0xFFD5E5E7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: continueNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    current == slides.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// LOGIN AND SIGNUP

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool hidePassword = true;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  InputDecoration decoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: muted),
      suffixIcon: hint.toLowerCase().contains('password')
          ? IconButton(
              onPressed: () => setState(() => hidePassword = !hidePassword),
              icon: Icon(
                hidePassword ? Icons.visibility_off : Icons.visibility,
                color: muted,
              ),
            )
          : null,
      filled: true,
      fillColor: const Color(0xFFFAFCFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E8EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E8EA)),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (!isLogin && nameController.text.trim().isEmpty) {
      showMessage('Please enter your name.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      showMessage('Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      showMessage('Password must be at least 6 characters.');
      return;
    }
    if (!isLogin && password != confirmController.text) {
      showMessage('Passwords do not match.');
      return;
    }

    // Demo navigation only; real authentication is not connected yet.
    final name = isLogin ? 'User' : nameController.text.trim();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userName', name);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(userName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: paleTeal,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Image.asset(
                      'assets/images/meditick_logo.png',
                      width: 58,
                      height: 58,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'MediTick',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    isLogin ? 'Welcome Back' : 'Create Your Account',
                    style: const TextStyle(fontSize: 17, color: muted),
                  ),
                ),
                const SizedBox(height: 32),
                if (!isLogin) ...[
                  TextField(
                    controller: nameController,
                    decoration: decoration('Full Name', Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: decoration('Email Address', Icons.email_outlined),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration: decoration('Password', Icons.lock_outline),
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    obscureText: hidePassword,
                    decoration: decoration(
                      'Confirm Password',
                      Icons.lock_outline,
                    ),
                  ),
                ],
                if (isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          showMessage('Password recovery will be added later.'),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: teal),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 20),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isLogin ? 'Login' : 'Create Account'),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLogin
                          ? "Don't have an account? "
                          : 'Already have an account? ',
                      style: const TextStyle(color: muted),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin ? 'Sign Up' : 'Login',
                        style: const TextStyle(
                          color: teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// MEDICINE DATA MODEL

class Medicine {
  final String name;
  final String dose;
  final String time;
  final String frequency;
  bool taken;
  String? takenDate;
  final String? imagePath;
  int? stockCount;

  Medicine({
    required this.name,
    required this.dose,
    required this.time,
    required this.frequency,
    this.taken = false,
    this.takenDate,
    this.imagePath,
    this.stockCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dose': dose,
      'time': time,
      'frequency': frequency,
      'taken': taken,
      'takenDate': takenDate,
      'imagePath': imagePath,
      'stockCount': stockCount,
    };
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      name: json['name'] as String,
      dose: json['dose'] as String,
      time: json['time'] as String,
      frequency: json['frequency'] as String,
      taken: json['taken'] as bool? ?? false,
      takenDate: json['takenDate'] as String?,
      imagePath: json['imagePath'] as String?,
      stockCount: json['stockCount'] as int?,
    );
  }
}

// HOME SCREEN

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Medicine> medicines = [];
  int selectedTab = 0;
  String medicineSearchText = '';
  String medicineFilter = 'All';

  @override
  void initState() {
    super.initState();
    loadMedicines();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('medicines');

    if (savedData == null) return;

    try {
      final List<dynamic> decodedData = jsonDecode(savedData);

      if (!mounted) return;

      setState(() {
        medicines
          ..clear()
          ..addAll(
            decodedData.map(
              (item) =>
                  Medicine.fromJson(Map<String, dynamic>.from(item as Map)),
            ),
          );
        final today = _todayKey();
        for (final medicine in medicines) {
          if (medicine.taken && medicine.takenDate != today) {
            medicine.taken = false;
            medicine.takenDate = null;
          }
        }
      });
      await saveMedicines();
      for (final medicine in medicines) {
        await scheduleMedicineReminder(medicine);
      }
    } catch (e) {
      debugPrint('Could not load saved medicines: $e');
    }
  }

  Future<void> saveMedicines() async {
    final prefs = await SharedPreferences.getInstance();

    final encodedData = jsonEncode(
      medicines.map((medicine) => medicine.toJson()).toList(),
    );

    await prefs.setString('medicines', encodedData);
  }

  Future<void> deleteMedicine(Medicine medicine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete medicine?'),
        content: Text('Do you want to delete "${medicine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => medicines.remove(medicine));
    await saveMedicines();
    await notifications.cancel(id: medicineNotificationId(medicine.name));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${medicine.name} deleted')),
    );
  }

  Future<void> addMedicine() async {
    final medicine = await Navigator.push<Medicine>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
    if (medicine != null) {
      setState(() => medicines.add(medicine));
      await saveMedicines();
      await scheduleMedicineReminder(medicine);
    }
  }

  void openTab(int index) {
    setState(() => selectedTab = index);
    if (index == 1) {
      addMedicine();
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HistoryScreen()),
      ).then((_) {
        if (mounted) setState(() => selectedTab = 0);
      });
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            userName: widget.userName,
            medicines: medicines,
          ),
        ),
      ).then((_) {
        if (mounted) setState(() => selectedTab = 0);
      });
    }
  }

  Future<void> logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userName');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Widget _dashboardCount(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
              Text(label, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = medicines.where((m) => !m.taken).length;
    final taken = medicines.where((m) => m.taken).length;
    final filteredMedicines = medicines.where((medicine) {
      final matchesSearch = medicine.name
          .toLowerCase()
          .contains(medicineSearchText.trim().toLowerCase());
      final matchesFilter = medicineFilter == 'All' ||
          (medicineFilter == 'Taken' && medicine.taken) ||
          (medicineFilter == 'Pending' && !medicine.taken);
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'MediTick',
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(Icons.logout, color: darkBlue),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Hello, ${widget.userName}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Here's your medicine schedule for today.",
              style: TextStyle(color: muted, fontSize: 14),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: paleTeal,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: teal.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.insights_outlined, color: teal, size: 27),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today's progress", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 17)),
                            SizedBox(height: 3),
                            Text('Keep going — your health matters!', style: TextStyle(color: muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(
                        '${medicines.isEmpty ? 0 : (taken * 100 / medicines.length).round()}%',
                        style: const TextStyle(color: teal, fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: medicines.isEmpty ? 0 : taken / medicines.length,
                      minHeight: 10,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation<Color>(teal),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _dashboardCount(Icons.medication_outlined, 'Total', medicines.length.toString(), darkBlue)),
                      Expanded(child: _dashboardCount(Icons.check_circle_outline, 'Taken', taken.toString(), teal)),
                      Expanded(child: _dashboardCount(Icons.schedule, 'Pending', pending.toString(), Colors.orange.shade800)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Medicines",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                Text(
                  '${medicines.length} total',
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) =>
                  setState(() => medicineSearchText = value),
              decoration: InputDecoration(
                hintText: 'Search medicines by name',
                prefixIcon: const Icon(Icons.search, color: muted),
                suffixIcon: medicineSearchText.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () =>
                            setState(() => medicineSearchText = ''),
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: const Color(0xFFFAFCFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E8EA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E8EA)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['All', 'Pending', 'Taken'].map((filter) {
                final selected = medicineFilter == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: selected,
                  selectedColor: paleTeal,
                  labelStyle: TextStyle(
                    color: selected ? darkBlue : muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(color: selected ? teal : const Color(0xFFE0E8EA)),
                  onSelected: (_) => setState(() => medicineFilter = filter),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (medicines.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFCFC),
                  border: Border.all(color: const Color(0xFFE5ECEE)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.medication_outlined, size: 42, color: teal),
                    SizedBox(height: 12),
                    Text(
                      'No medicines added yet',
                      style: TextStyle(
                        color: darkBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Tap Add Medicine to create your schedule.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              )
            else if (filteredMedicines.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 42, color: teal),
                    SizedBox(height: 10),
                    Text(
                      'No matching medicines',
                      style: TextStyle(
                        color: darkBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Try another name or filter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              )
            else
              ...filteredMedicines.map(
                (medicine) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0E8EA)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: paleTeal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: medicine.imagePath != null &&
                                File(medicine.imagePath!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(medicine.imagePath!),
                                  width: 46,
                                  height: 46,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.medication_outlined,
                                color: teal,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicine.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: darkBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${medicine.dose} · ${medicine.time}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              medicine.frequency,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            if (medicine.stockCount != null)
                              Text(
                                medicine.stockCount! <= 5
                                    ? 'Low stock: ${medicine.stockCount} left'
                                    : 'Stock: ${medicine.stockCount} left',
                                style: TextStyle(
                                  color: medicine.stockCount! <= 5 ? Colors.red.shade700 : muted,
                                  fontSize: 12,
                                  fontWeight: medicine.stockCount! <= 5 ? FontWeight.w700 : FontWeight.normal,
                                ),
                              )
                            else
                              const Text('Stock not set', style: TextStyle(color: muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete medicine',
                        onPressed: () => deleteMedicine(medicine),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                      const SizedBox(width: 2),
                      Column(
                        children: [
                          Text(
                            medicine.taken ? 'Taken' : 'Pending',
                            style: TextStyle(
                              color: medicine.taken
                                  ? teal
                                  : Colors.orange.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Checkbox(
                            value: medicine.taken,
                            activeColor: teal,
                            onChanged: (value) async {
                              final isTaken = value ?? false;
                              final alreadyTakenToday = medicine.taken &&
                                  medicine.takenDate == _todayKey();
                              setState(() {
                                if (isTaken && !alreadyTakenToday && medicine.stockCount != null && medicine.stockCount! > 0) {
                                  medicine.stockCount = medicine.stockCount! - 1;
                                }
                                medicine.taken = isTaken;
                                medicine.takenDate = isTaken ? _todayKey() : null;
                              });
                              await saveMedicines();
                              await saveMedicineHistory(medicine, isTaken);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: addMedicine,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Medicine',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: openTab,
        backgroundColor: Colors.white,
        indicatorColor: paleTeal,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: teal),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add Medicine',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}


// MEDICINE HISTORY

Future<void> saveMedicineHistory(Medicine medicine, bool isTaken) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString('medicine_history');
  final List<dynamic> records =
      existing == null ? [] : (jsonDecode(existing) as List<dynamic>);

  records.insert(0, {
    'name': medicine.name,
    'dose': medicine.dose,
    'time': medicine.time,
    'status': isTaken ? 'Taken' : 'Marked as pending',
    'recordedAt': DateTime.now().toIso8601String(),
  });

  await prefs.setString('medicine_history', jsonEncode(records));
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('medicine_history');
    final List<dynamic> decoded =
        raw == null ? [] : (jsonDecode(raw) as List<dynamic>);

    if (!mounted) return;
    setState(() {
      records = decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      loading = false;
    });
  }

  String formatDate(String? raw) {
    if (raw == null) return 'Date unavailable';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return 'Date unavailable';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} · '
        '$hour:$minute $period';
  }

  Future<void> clearHistory() async {
    if (records.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This will permanently remove all history entries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('medicine_history');
    if (!mounted) return;
    setState(() => records = []);
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = records.where((record) {
      final name = (record['name'] ?? '').toString().toLowerCase();
      return name.contains(searchText.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medicine History',
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Clear history',
            onPressed: records.isEmpty ? null : clearHistory,
            icon: const Icon(Icons.delete_outline, color: darkBlue),
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: teal))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      onChanged: (value) => setState(() => searchText = value),
                      decoration: InputDecoration(
                        hintText: 'Search medicine name',
                        prefixIcon: const Icon(Icons.search, color: muted),
                        filled: true,
                        fillColor: const Color(0xFFFAFCFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E8EA)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filteredRecords.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.history, size: 52, color: teal),
                                  const SizedBox(height: 12),
                                  Text(
                                    searchText.isEmpty
                                        ? 'No history yet'
                                        : 'No matching medicines',
                                    style: const TextStyle(
                                      color: darkBlue,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Mark a medicine as taken on the Home screen to record it here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: muted),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredRecords.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final record = filteredRecords[index];
                              final status = (record['status'] ?? 'Taken').toString();
                              final isTaken = status == 'Taken';
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFE0E8EA)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: paleTeal,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.medication_outlined,
                                        color: teal,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (record['name'] ?? 'Medicine').toString(),
                                            style: const TextStyle(
                                              color: darkBlue,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${record['dose'] ?? ''} · ${record['time'] ?? ''}',
                                            style: const TextStyle(color: muted, fontSize: 13),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            formatDate(record['recordedAt']?.toString()),
                                            style: const TextStyle(color: muted, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        color: isTaken ? teal : Colors.orange.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}


// ADD MEDICINE FORM

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final doseController = TextEditingController();
  final stockController = TextEditingController(text: '30');

  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
  String frequency = 'Once daily';
  String? medicineImagePath;
  bool pickingImage = false;

  @override
  void dispose() {
    nameController.dispose();
    doseController.dispose();
    stockController.dispose();
    super.dispose();
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDCE5E7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: teal, width: 1.5),
      ),
    );
  }

  Future<void> pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (result != null) {
      setState(() => selectedTime = result);
    }
  }

  Future<void> pickMedicineImage(ImageSource source) async {
    if (pickingImage) return;
    setState(() => pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (picked == null) return;

      // Copy the selected photo into app storage so it remains available later.
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/medicine_photos');
      if (!await imageDir.exists()) await imageDir.create(recursive: true);
      final extension = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final destination = '${imageDir.path}/medicine_${DateTime.now().microsecondsSinceEpoch}$extension';
      final savedFile = await File(picked.path).copy(destination);
      if (!mounted) return;
      setState(() => medicineImagePath = savedFile.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add photo: $e')),
      );
    } finally {
      if (mounted) setState(() => pickingImage = false);
    }
  }

  Future<void> showPhotoOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: teal),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                pickMedicineImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: teal),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                pickMedicineImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void saveMedicine() {
    if (!formKey.currentState!.validate()) return;

    final medicine = Medicine(
      name: nameController.text.trim(),
      dose: doseController.text.trim(),
      time: selectedTime.format(context),
      frequency: frequency,
      imagePath: medicineImagePath,
      stockCount: int.tryParse(stockController.text.trim()) ?? 30,
    );

    Navigator.pop(context, medicine);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Medicine',
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Medicine Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Enter the details for your medicine schedule.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 22),
              const Text(
                'Medicine Photo (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, color: darkBlue),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDCE5E7)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: paleTeal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: medicineImagePath != null && File(medicineImagePath!).existsSync()
                          ? Image.file(File(medicineImagePath!), fit: BoxFit.cover)
                          : const Icon(Icons.medication_outlined, color: teal, size: 34),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicineImagePath == null ? 'Add a medicine photo' : 'Photo added',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: darkBlue),
                          ),
                          const SizedBox(height: 5),
                          const Text('Use your camera or choose an existing photo.', style: TextStyle(color: muted, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: pickingImage ? null : () => pickMedicineImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_outlined, size: 17),
                                label: const Text('Camera'),
                              ),
                              OutlinedButton.icon(
                                onPressed: pickingImage ? null : () => pickMedicineImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_outlined, size: 17),
                                label: const Text('Gallery'),
                              ),
                            ],
                          ),
                          if (pickingImage) const LinearProgressIndicator(color: teal),
                          if (medicineImagePath != null)
                            TextButton.icon(
                              onPressed: () => setState(() => medicineImagePath = null),
                              icon: const Icon(Icons.delete_outline, size: 17),
                              label: const Text('Remove photo'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Medicine Name',
                style: TextStyle(fontWeight: FontWeight.w600, color: darkBlue),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: fieldDecoration(
                  'e.g. Vitamin tablet',
                  Icons.medication_outlined,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter the medicine name'
                    : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Dosage',
                style: TextStyle(fontWeight: FontWeight.w600, color: darkBlue),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: doseController,
                decoration: fieldDecoration(
                  'e.g. 1 tablet, 5 ml',
                  Icons.local_hospital_outlined,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter the dosage'
                    : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Initial Stock (tablets/doses)',
                style: TextStyle(fontWeight: FontWeight.w600, color: darkBlue),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration('e.g. 30', Icons.inventory_2_outlined),
                validator: (value) {
                  final count = int.tryParse(value?.trim() ?? '');
                  if (count == null || count < 0) return 'Enter a valid stock quantity (0 or more)';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Reminder Time',
                style: TextStyle(fontWeight: FontWeight.w600, color: darkBlue),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: pickTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: fieldDecoration('Select time', Icons.access_time),
                  child: Text(
                    selectedTime.format(context),
                    style: const TextStyle(color: darkBlue, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Frequency',
                style: TextStyle(fontWeight: FontWeight.w600, color: darkBlue),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                decoration: fieldDecoration('How often?', Icons.repeat),
                items: const [
                  DropdownMenuItem(
                    value: 'Once daily',
                    child: Text('Once daily'),
                  ),
                  DropdownMenuItem(
                    value: 'Twice daily',
                    child: Text('Twice daily'),
                  ),
                  DropdownMenuItem(
                    value: 'Three times daily',
                    child: Text('Three times daily'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => frequency = value);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Medicine',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// USER PROFILE
class ProfileScreen extends StatefulWidget {
  final String userName;
  final List<Medicine> medicines;
  const ProfileScreen({super.key, required this.userName, required this.medicines});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyController = TextEditingController();
  String? _photoPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString('profile_name') ?? widget.userName;
      _ageController.text = prefs.getString('profile_age') ?? '';
      _emailController.text = prefs.getString('profile_email') ?? '';
      _emergencyController.text = prefs.getString('profile_emergency') ?? '';
      _photoPath = prefs.getString('profile_photo');
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 700);
      if (picked == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_photo', picked.path);
      if (mounted) setState(() => _photoPath = picked.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo select nahi ho payi. image_picker setup check karo.')));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', _nameController.text.trim());
    await prefs.setString('profile_age', _ageController.text.trim());
    await prefs.setString('profile_email', _emailController.text.trim());
    await prefs.setString('profile_emergency', _emergencyController.text.trim());
    await prefs.setString('userName', _nameController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully')));
  }

  @override
  void dispose() {
    _nameController.dispose(); _ageController.dispose(); _emailController.dispose(); _emergencyController.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller, keyboardType: keyboardType, validator: validator,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: teal), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: teal))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taken = widget.medicines.where((m) => m.taken).length;
    final pending = widget.medicines.length - taken;
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile', style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, foregroundColor: darkBlue, surfaceTintColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator(color: teal)) : ListView(
        padding: const EdgeInsets.all(20), children: [
          Center(child: Column(children: [
            GestureDetector(onTap: _pickPhoto, child: CircleAvatar(radius: 52, backgroundColor: paleTeal, backgroundImage: _photoPath != null && File(_photoPath!).existsSync() ? FileImage(File(_photoPath!)) : null, child: _photoPath == null || !File(_photoPath!).existsSync() ? const Icon(Icons.person, size: 54, color: teal) : null)),
            TextButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Change profile photo')),
          ])),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: paleTeal, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Daily medicine summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: _summaryTile('Total', '${widget.medicines.length}', Icons.medication_outlined)), Expanded(child: _summaryTile('Taken', '$taken', Icons.check_circle_outline)), Expanded(child: _summaryTile('Pending', '$pending', Icons.schedule))]),
          ])),
          const SizedBox(height: 24),
          const Text('Personal details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
          const SizedBox(height: 14),
          Form(key: _formKey, child: Column(children: [
            _field('Name', _nameController, Icons.person_outline, validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null),
            _field('Age', _ageController, Icons.cake_outlined, keyboardType: TextInputType.number, validator: (v) { if (v == null || v.trim().isEmpty) return null; final age = int.tryParse(v); return age == null || age < 1 || age > 120 ? 'Enter a valid age' : null; }),
            _field('Email', _emailController, Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) => v != null && v.isNotEmpty && !v.contains('@') ? 'Enter a valid email' : null),
            _field('Emergency contact', _emergencyController, Icons.emergency_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save_outlined), label: const Text('Save Profile'), style: ElevatedButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ])),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon) => Column(children: [Icon(icon, color: teal), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)), Text(label, style: const TextStyle(fontSize: 12, color: muted))]);
}
