import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const teal = Color(0xFF009E9A);
const darkBlue = Color(0xFF123C4A);
const muted = Color(0xFF647C84);
const paleTeal = Color(0xFFE5F8F7);

void main() => runApp(const DoseMateApp());

class DoseMateApp extends StatelessWidget {
  const DoseMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DoseMate',
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
              child: const Icon(
                Icons.medication_rounded,
                size: 76,
                color: teal,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'DoseMate',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your Health, Our Reminder',
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
      title: 'Your Health, Our Reminder',
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    final name = isLogin
        ? 'User'
        : nameController.text.trim();
final prefs = await SharedPreferences.getInstance();

await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userName', name);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(userName: name),
      ),
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
                    child: const Icon(
                      Icons.medication_rounded,
                      color: teal,
                      size: 46,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'DoseMate',
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
                      onPressed: () => showMessage(
                        'Password recovery will be added later.',
                      ),
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

  Medicine({
    required this.name,
    required this.dose,
    required this.time,
    required this.frequency,
    this.taken = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dose': dose,
      'time': time,
      'frequency': frequency,
      'taken': taken,
    };
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      name: json['name'] as String,
      dose: json['dose'] as String,
      time: json['time'] as String,
      frequency: json['frequency'] as String,
      taken: json['taken'] as bool? ?? false,
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
  
@override
void initState() {
  super.initState();
  loadMedicines();
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
            (item) => Medicine.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
    });
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


  Future<void> addMedicine() async {
    final medicine = await Navigator.push<Medicine>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
if (medicine != null) {
  setState(() => medicines.add(medicine));
  await saveMedicines();
}
  }

  void openTab(int index) {
    setState(() => selectedTab = index);
    if (index == 1) {
      addMedicine();
    } else if (index == 2 || index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            index == 2
                ? 'History screen will be added next.'
                : 'Profile screen will be added next.',
          ),
        ),
      );
      setState(() => selectedTab = 0);
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
    MaterialPageRoute(
      builder: (_) => const AuthScreen(),
    ),
    (route) => false,
  );
}

  @override
  Widget build(BuildContext context) {
    final pending = medicines.where((m) => !m.taken).length;
    final taken = medicines.where((m) => m.taken).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'DoseMate',
          style: TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
  tooltip: 'Logout',
  onPressed: logout,
  icon: const Icon(
    Icons.logout,
    color: darkBlue,
  ),
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
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: teal, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's progress",
                          style: TextStyle(
                            color: darkBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$taken taken  ·  $pending pending',
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
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
            else
              ...medicines.map(
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
                              style: const TextStyle(color: muted, fontSize: 13),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              medicine.frequency,
                              style: const TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        children: [
                          Text(
                            medicine.taken ? 'Taken' : 'Pending',
                            style: TextStyle(
                              color: medicine.taken ? teal : Colors.orange.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Checkbox(
                            value: medicine.taken,
                            activeColor: teal,
                            onChanged: (value) async {
  setState(() {
    medicine.taken = value ?? false;
  });

  await saveMedicines();
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
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
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

  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
  String frequency = 'Once daily';

  @override
  void dispose() {
    nameController.dispose();
    doseController.dispose();
    super.dispose();
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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

  void saveMedicine() {
    if (!formKey.currentState!.validate()) return;

    final medicine = Medicine(
      name: nameController.text.trim(),
      dose: doseController.text.trim(),
      time: selectedTime.format(context),
      frequency: frequency,
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
              const SizedBox(height: 26),
              const Text(
                'Medicine Name',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: fieldDecoration(
                  'e.g. Vitamin tablet',
                  Icons.medication_outlined,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Please enter the medicine name'
                        : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Dosage',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: doseController,
                decoration: fieldDecoration(
                  'e.g. 1 tablet, 5 ml',
                  Icons.local_hospital_outlined,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Please enter the dosage'
                        : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Reminder Time',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: pickTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: fieldDecoration(
                    'Select time',
                    Icons.access_time,
                  ),
                  child: Text(
                    selectedTime.format(context),
                    style: const TextStyle(color: darkBlue, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Frequency',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                decoration: fieldDecoration(
                  'How often?',
                  Icons.repeat,
                ),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
