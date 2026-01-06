import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
//import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
//import 'package:gas_meter_app/config.dart';
//import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Load your API key from .env file
  //if (!kIsWeb) {
  //await dotenv.load(fileName: ".env"); // Only on mobile — no 404 on web
  //}

  // ✅ Now initialize Supabase (or any other service that needs the key)
  await Supabase.initialize(
    url: 'https://hugqwdfledpcsbupoagc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1Z3F3ZGZsZWRwY3NidXBvYWdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MTcyMzIsImV4cCI6MjA4MDQ5MzIzMn0.ZWdUiYZaRLa0HZvzGVl2SBSkgkzBUrYXMjknp7rWYRM',
  );
  // anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'no-key');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppTheme(),
      child: const FluxGuardApp(),
    ),
  );
}

class AppTheme extends ChangeNotifier {
  bool isDark = false;

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
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const LoginPage(),
    );
  }
}

// Login Page - centered card + Google Sign Up
// Login Page (blue gas flame background + centered semi-transparent box)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool rememberMe = false;
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

  Future<void> signUpWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.fluxguard://login-callback/',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google sign up failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              'https://media.gettyimages.com/id/157612903/photo/gas-burner.jpg?s=1024x1024&w=gi&k=20&c=2yJixLIYdXOB51MH2wTv24-qiOO0TneL3qVUG38omJQ=', // Exact blue gas flame burner from your image
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(
                  102,
                ), // Semi-transparent black box
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(51)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield, size: 80, color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      'FluxGuard',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Smart Gas Monitoring',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 48),
                    TextField(
                      controller: emailCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Email Address',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withAlpha(51),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withAlpha(51),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: rememberMe,
                          onChanged: (v) => setState(() => rememberMe = v!),
                          activeColor: Colors.orange,
                        ),
                        Text(
                          'Remember Me',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: loading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Sign in now',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Lost your password?',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          text: 'By clicking on "Sign in now", you agree to\n',
                          children: const [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(color: Colors.orange),
                            ),
                            TextSpan(text: ' | '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Home Screen - no Add Reading
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const ReportsPage(),
    const AlertsPage(),
    const AIChatPage(),
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        key: ValueKey<int>(_selectedIndex),
        child: _pages[_selectedIndex],
      ),
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
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'AI Chat',
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

// Dashboard Page
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
                .stream(primaryKey: ['id']).eq('id', meterId),
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
              final valveOpen = meter['valve_status'] == true;

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
                      Text(
                        'Current Credit',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${credit.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            valveOpen ? Icons.check_circle : Icons.cancel,
                            color: valveOpen
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            valveOpen ? 'Valve OPEN' : 'Valve CLOSED',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                            ),
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
          Text(
            'Recent Top-ups',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: supabase
                .from('top_ups')
                .stream(primaryKey: ['id'])
                .eq('meter_id', meterId)
                .order('timestamp', ascending: false)
                .limit(5),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No top-ups yet');
              }
              return Column(
                children: snapshot.data!.map((topUp) {
                  final amount =
                      double.tryParse(topUp['amount'].toString()) ?? 0.0;
                  final method = topUp['method'] ?? 'unknown';
                  final timestamp = DateTime.parse(
                    topUp['timestamp'],
                  ).toLocal();
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.add_circle,
                        color: Colors.green,
                      ),
                      title: Text(
                        '+$amount',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(method),
                      trailing: Text(timestamp.toString().substring(0, 16)),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Reports Page - blue bar graphs + future projection
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentData = [50.0, 70.0, 60.0, 80.0, 90.0, 75.0];
    final futureData = currentData.map((e) => e * 1.1).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usage Reports',
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Text(
            'Current Usage (Last 6 Months)',
            style: GoogleFonts.inter(fontSize: 20),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) =>
                          Text('Month ${value.toInt() + 1}'),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: currentData.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: Colors.indigo,
                        width: 20,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Projected Usage (Next 6 Months)',
            style: GoogleFonts.inter(fontSize: 20),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) =>
                          Text('Month ${value.toInt() + 1}'),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: futureData.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: Colors.blueAccent,
                        width: 20,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Alerts Page - black background
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  final String meterId = '955afea6-0e6e-43c3-88af-b7bf3d4a8485';

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alerts & Notifications',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: supabase
                  .from('alerts')
                  .stream(primaryKey: ['id'])
                  .eq('meter_id', meterId)
                  .order('timestamp', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    'No alerts',
                    style: GoogleFonts.inter(color: Colors.white),
                  );
                }
                return Column(
                  children: snapshot.data!.map((alert) {
                    final type = alert['type'] ?? 'Unknown';
                    final message = alert['message'] ?? 'No message';
                    final timestamp = DateTime.parse(
                      alert['timestamp'],
                    ).toLocal();
                    Color cardColor = Colors.grey[800]!;
                    Color textColor = Colors.white;

                    if (type.toLowerCase().contains('leak')) {
                      cardColor = Colors.red[900]!;
                    } else if (type.toLowerCase().contains('high')) {
                      cardColor = Colors.orange[900]!;
                    }

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          type,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          message,
                          style: GoogleFonts.inter(color: textColor),
                        ),
                        trailing: Text(
                          timestamp.toString().substring(11, 16),
                          style: GoogleFonts.inter(color: textColor),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// AI Chat Page (Groq powered — super fast!)
// AI Chat Page - Groq powered + knows your FluxGuard data
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  final String groqKey = const String.fromEnvironment('GROQ_API_KEY',
      defaultValue: 'no-key'); //the api key placeholder

  final String meterId = '955afea6-0e6e-43c3-88af-b7bf3d4a8485';

  Future<void> _sendMessage() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': userMessage});
      _loading = true;
    });
    _controller.clear();

    // Fetch real user data from Supabase
    double currentCredit = 80.0;
    bool valveOpen = true;
    String lastTopUp = 'No recent top-ups';
    int alertCount = 0;

    try {
      final supabase = Supabase.instance.client;

      final meter =
          await supabase.from('meters').select().eq('id', meterId).single();

      currentCredit =
          double.tryParse(meter['current_credit'].toString()) ?? 80.0;
      valveOpen = meter['valve_status'] == true;

      final topUps = await supabase
          .from('top_ups')
          .select()
          .eq('meter_id', meterId)
          .order('timestamp', ascending: false)
          .limit(1);

      if (topUps.isNotEmpty) {
        final amount = double.tryParse(topUps[0]['amount'].toString()) ?? 0.0;
        lastTopUp = '+$amount';
      }

      final alerts =
          await supabase.from('alerts').select().eq('meter_id', meterId);

      alertCount = alerts.length;
    } catch (e) {
      // Keep defaults if fetch fails
    }

    // System prompt with your real app data
    final systemPrompt = '''
You are FluxGuard AI, the smart assistant for a gas monitoring app.
Developer facts:
- Name: [Einstein Michael Mtweve]
- Skills: Flutter pro, Supabase wizard, building cool apps like this one
- Fun fact: Loves making AI chat super fast with Groq!
- Name / Preferred ID: Einstein
- Location: Laroi, Arusha, Tanzania
- Skills:
- Master troubleshooter for gaming, drivers, system-level issues, and digital workflows
- Intermediate Python developer (backend logic, web forms, automation)
- Expanding into frameworks (Flask, Django), AI (TensorFlow, PyTorch), and cross-platform tools (React Native, Flutter, Electron)
- Advanced C++ conceptualist (object-oriented design, dynamic polymorphism, vtables, runtime dispatch)
- System architect (IoT/AI systems from hardware to cloud dashboards)
- Creative coder (Python turtle animations, matplotlib visualizations for science branding)
- Flutter developer (building, packaging, distributing APKs)
- Legacy DBMS designer (Superbase schemas, forms, automation logic)
- Hardware/software troubleshooter (BIOS/CMOS errors, restart loops)
- Interests:
- Building real-world IoT/AI projects with practical impact
- Creative coding and visual communication for local science branding
- Optimizing real-time systems and embedded hardware
- Making tech accessible to non-tech audiences
- Team culture building, ethical project management, and peer accountability
- Short-Term Goals:
- Perfect the Arusha Science logo with Africa silhouette and radiant beam
- Complete schema design and simulation for Sentinel Gas Meter project in Superbase
- Prepare and format Vision 2050 project materials for stakeholder review
- Troubleshoot HP laptop BIOS/CMOS errors
- Build and distribute Flutter APKs with scalable update strategies
- Durable Facts I’ve stored:
- You have a project named Vacuum Duster
- You were the head boy at school
- You are working on a project called Sentinel Gas Meter
collaborators:Fahim Kiama
Mark Kishaiti
Gwamaka Kibona
Lorren Masika

Current user status:
- Credit: \$$currentCredit
- Valve: ${valveOpen ? 'OPEN' : 'CLOSED'}
- Last Top-up: $lastTopUp
- Active Alerts: $alertCount

Answer questions about credit, valve status, usage, top-ups, alerts, and app features.
Be friendly, helpful, and accurate. Use the data above.
If asked about unrelated topics, politely say you specialize in gas monitoring.
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile', // Current working model
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiReply = data['choices'][0]['message']['content'].trim();

        setState(() {
          _messages.add({'role': 'model', 'text': aiReply});
          _loading = false;
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'model',
            'text': 'Error: ${response.statusCode} - ${response.body}'
          });
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'model',
          'text': 'Network error. Please check your connection.'
        });
        _loading = false;
      });
    }

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Assistant',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color:
                          isUser ? Colors.indigo : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      msg['text']!,
                      style: GoogleFonts.inter(
                        color: isUser ? Colors.white : null,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(width: 12),
                  Text('AI is thinking...'),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask about your gas usage...',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _loading ? null : () => _sendMessage(),
                  backgroundColor: Colors.indigo,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Settings Page - fixed all warnings
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final oldPassCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      nameCtrl.text = user.userMetadata?['full_name'] ?? '';
      phoneCtrl.text = user.phone ?? '';
    }
  }

  Future<void> updateProfile() async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': nameCtrl.text}),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> changePassword() async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassCtrl.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password changed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppTheme>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: updateProfile,
                    child: const Text('Save Profile'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Password',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Old Password',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: changePassword,
                    child: const Text('Change Password'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dark Mode', style: GoogleFonts.inter(fontSize: 20)),
                  Switch(
                    value: theme.isDark,
                    onChanged: (v) => theme.toggle(),
                    activeThumbColor: Colors.indigo,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text('Log Out', style: GoogleFonts.inter(color: Colors.red)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
