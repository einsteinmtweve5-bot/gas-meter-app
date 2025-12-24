import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hugqwdfledpcsbupoagc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1Z3F3ZGZsZWRwY3NidXBvYWdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MTcyMzIsImV4cCI6MjA4MDQ5MzIzMn0.ZWdUiYZaRLa0HZvzGVl2SBSkgkzBUrYXMjknp7rWYRM',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppTheme(),
      child: const FluxGuardApp(),
    ),
  );
}

class AppTheme extends ChangeNotifier {
  bool isDark = true;

  void toggle() {
    isDark = !isDark;
    notifyListeners();
  }
}

class FluxGuardApp extends StatelessWidget {
  const FluxGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppTheme>(context);

    return MaterialApp(
      title: 'FluxGuard',
      debugShowCheckedModeBanner: false,
      themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const LoginPage(),
    );
  }
}

// Login Page (black input ink, labels, icons)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.shield, size: 60, color: Colors.indigo),
              ),
              const SizedBox(height: 32),
              Text(
                'FluxGuard',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Track your gas consumption',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: emailCtrl,
                style: const TextStyle(
                  color: Colors.black,
                ), // Black typing text
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(
                    color: Colors.black,
                  ), // Black label
                  prefixIcon: const Icon(Icons.email, color: Colors.black54),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.indigo),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(
                  color: Colors.black,
                ), // Black typing text
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(
                    color: Colors.black,
                  ), // Black label
                  prefixIcon: const Icon(Icons.lock, color: Colors.black54),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.indigo),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.indigo),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: loading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Sign In',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {},
                child: Text(
                  'New to FluxGuard? Sign Up',
                  style: GoogleFonts.inter(color: Colors.indigo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Home Screen with Bottom Navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const AddReadingPage(),
    const ReportsPage(),
    const AlertsPage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add Reading',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('3'),
              backgroundColor: Colors.red,
              child: Icon(Icons.notifications),
            ),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Dashboard Page (exact match to screenshot)
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  final String meterId = '955afea6-0e6e-43c3-88af-b7bf3d4a8485';

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: supabase
                .from('meters')
                .stream(primaryKey: ['id'])
                .eq('id', meterId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No meter data'),
                  ),
                );
              }
              final meter = snapshot.data![0];
              final credit =
                  double.tryParse(meter['current_credit'].toString()) ?? 80.0;
              final currentUsage = 245.8; // Use real total usage from logs
              final trend = '+12.5%';

              return Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.indigo[900],
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'December 2025',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                color: Colors.greenAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                trend,
                                style: GoogleFonts.inter(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$currentUsage CCF',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated Cost',
                                style: GoogleFonts.inter(color: Colors.white70),
                              ),
                              Text(
                                '\$${credit.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Last Updated\n2 hours ago',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Readings',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All >',
                  style: GoogleFonts.inter(color: Colors.indigo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recent Readings (from consumption_logs)
          StreamBuilder(
            stream: supabase
                .from('consumption_logs')
                .stream(primaryKey: ['id'])
                .eq('meter_id', meterId)
                .order('timestamp', ascending: false)
                .limit(5),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No readings yet');
              }
              return Column(
                children: snapshot.data!.map((log) {
                  final usage =
                      double.tryParse(log['m3_total'].toString()) ?? 0.0;
                  final timestamp = DateTime.parse(log['timestamp']).toLocal();
                  final cost = (usage * 0.05).toStringAsFixed(
                    2,
                  ); // Example cost calculation
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        log['photo'] != null ? Icons.camera_alt : Icons.edit,
                        color: Colors.grey,
                      ),
                      title: Text(timestamp.toString().substring(0, 10)),
                      subtitle: Text('Reading: $usage'),
                      trailing: Text(
                        '\$$cost',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddReadingPage()),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                'Add Reading',
                style: GoogleFonts.inter(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Add Reading Page (exact match)
class AddReadingPage extends StatefulWidget {
  const AddReadingPage({super.key});

  @override
  State<AddReadingPage> createState() => _AddReadingPageState();
}

class _AddReadingPageState extends State<AddReadingPage> {
  File? _image;
  final readingCtrl = TextEditingController();
  DateTime selectedDate = DateTime.now();
  final notesCtrl = TextEditingController();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Reading',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Save', style: TextStyle(color: Colors.indigo)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meter Photo', style: GoogleFonts.inter(fontSize: 18)),
            Text(
              'Capture or upload a photo of your gas meter for automatic reading extraction.',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: _image == null
                    ? Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt,
                              size: 60,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Photo',
                              style: GoogleFonts.inter(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : Image.file(
                        _image!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 32),
            Text('Meter Reading', style: GoogleFonts.inter(fontSize: 18)),
            TextField(
              controller: readingCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.speed),
                hintText: '0.0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reading must be higher than previous: 12,458.5',
              style: GoogleFonts.inter(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Text('Reading Date', style: GoogleFonts.inter(fontSize: 18)),
            ListTile(
              title: Text(selectedDate.toString().substring(0, 10)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    selectedDate = date;
                  });
                }
              },
            ),
            const SizedBox(height: 32),
            Text('Notes (Optional)', style: GoogleFonts.inter(fontSize: 18)),
            TextField(
              controller: notesCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'e.g. Meter location, weather conditions, or any observations...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reports Page (exact match)
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _selectedTab = 1; // Month

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Reports',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton(
              segments: const [
                ButtonSegment(value: 0, label: Text('Week')),
                ButtonSegment(value: 1, label: Text('Month')),
                ButtonSegment(value: 2, label: Text('Year')),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (set) {
                setState(() {
                  _selectedTab = set.first;
                });
              },
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.orange,
                          ),
                          Text(
                            'Total Usage',
                            style: GoogleFonts.inter(fontSize: 16),
                          ),
                          Text(
                            '1200.00 CCF',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.attach_money, color: Colors.green),
                          Text(
                            'Total Cost',
                            style: GoogleFonts.inter(fontSize: 16),
                          ),
                          Text(
                            '\$144.00',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Usage Analytics',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) =>
                            Text('W${value.toInt()}'),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        FlSpot(1, 20),
                        FlSpot(2, 40),
                        FlSpot(3, 30),
                        FlSpot(4, 60),
                      ],
                      isCurved: true,
                      color: Colors.indigo,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Alerts Page (exact match)
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Alerts & Notifications',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Mark All Read',
              style: TextStyle(color: Colors.indigo),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            color: Colors.red[50],
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red, size: 40),
              title: Text(
                'Critical Gas Leak Detected',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Abnormal gas flow detected at Kitchen Meter. Immediate action required.',
              ),
              trailing: Text('5m ago'),
              isThreeLine: true,
            ),
          ),
          Card(
            color: Colors.orange[50],
            child: ListTile(
              leading: const Icon(
                Icons.trending_up,
                color: Colors.orange,
                size: 40,
              ),
              title: Text(
                'High Usage Alert',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Gas consumption 45% above normal for this time period.',
              ),
              trailing: Text('2h ago'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.calendar_today,
                color: Colors.blue,
                size: 40,
              ),
              title: Text(
                'Monthly Reading Reminder',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Time to submit your monthly gas meter reading.'),
              trailing: Text('5h ago'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.lightbulb,
                color: Colors.orange,
                size: 40,
              ),
              title: Text(
                'Unusual Night Usage',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Gas consumption detected between 2 AM - 4 AM when usage is typically zero.',
              ),
              trailing: Text('8h ago'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.update, color: Colors.blue, size: 40),
              title: Text(
                'System Update Available',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'New app version 2.5.0 available with improved leak detection.',
              ),
              trailing: Text('1d ago'),
            ),
          ),
        ],
      ),
    );
  }
}

// Settings Page (exact match)
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.person, size: 50),
                ),
                title: Text(
                  'John Anderson',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text('john.anderson@email.com'),
                trailing: const Chip(
                  label: Text('Premium'),
                  backgroundColor: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('ACCOUNT', style: GoogleFonts.inter(color: Colors.grey)),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text('Edit Profile'),
              subtitle: Text('Update your personal information'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: Text('Change Password'),
              subtitle: Text('Update your account password'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: Text('Billing & Subscription'),
              subtitle: Text('Manage your subscription plan'),
              trailing: const Text('Premium'),
              onTap: () {},
            ),
            const SizedBox(height: 32),
            Text('NOTIFICATIONS', style: GoogleFonts.inter(color: Colors.grey)),
            SwitchListTile(
              title: Text('Leak Alerts'),
              subtitle: Text('Get notified of potential gas leaks'),
              value: true,
              onChanged: (v) {},
            ),
            SwitchListTile(
              title: Text('Usage Warnings'),
              subtitle: Text('Alerts for high consumption'),
              value: true,
              onChanged: (v) {},
            ),
            SwitchListTile(
              title: Text('Reading Reminders'),
              subtitle: Text('Scheduled meter reading reminders'),
              value: true,
              onChanged: (v) {},
            ),
            SwitchListTile(
              title: Text('System Updates'),
              subtitle: Text('App updates and maintenance notices'),
              value: false,
              onChanged: (v) {},
            ),
          ],
        ),
      ),
    );
  }
}
