import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:provider/provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hugqwdfledpcsbupoagc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1Z3F3ZGZsZWRwY3NidXBvYWdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MTcyMzIsImV4cCI6MjA4MDQ5MzIzMn0.ZWdUiYZaRLa0HZvzGVl2SBSkgkzBUrYXMjknp7rWYRM',
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        scaffoldBackgroundColor: Colors.grey[900],
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const LoginPage(),
    );
  }
}

// ────────────────────── LOGIN PAGE ──────────────────────
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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal, Colors.indigo],
          ),
        ),
        child: Center(
          child: Card(
            elevation: 20,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield, size: 90, color: Colors.white),
                  const SizedBox(height: 24),
                  Text('FluxGuard', style: GoogleFonts.inter(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  Text('Smart Gas Monitoring', style: GoogleFonts.inter(color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 48),
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.email, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 10,
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.teal)
                          : Text('Login', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────── MAIN SCREEN WITH SIDEBAR ──────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _controller = SidebarXController(selectedIndex: 0, extended: true);

  final List<Widget> screens = const [
    DashboardPage(),
    AIChatPage(),
    AnalyticsPage(),
    ReportsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppTheme>(context);

    return Scaffold(
      body: Row(
        children: [
          SidebarX(
            controller: _controller,
            theme: SidebarXTheme(
              width: 220,
              decoration: BoxDecoration(
                color: theme.isDark ? Colors.grey[850] : Colors.white,
                borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              textStyle: GoogleFonts.inter(fontSize: 15),
              selectedTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.teal),
              iconTheme: IconThemeData(color: theme.isDark ? Colors.white70 : Colors.black87),
              selectedIconTheme: const IconThemeData(color: Colors.teal),
              hoverColor: Colors.teal.withAlpha(50),
            ),
            headerBuilder: (context, extended) => Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.shield, color: Colors.teal, size: 30),
                  if (extended) const SizedBox(width: 10),
                  if (extended) Text('FluxGuard', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                ],
              ),
            ),
            items: const [
              SidebarXItem(icon: Icons.dashboard, label: 'Dashboard'),
              SidebarXItem(icon: Icons.smart_toy, label: 'AI Assistant'),
              SidebarXItem(icon: Icons.bar_chart, label: 'Analytics'),
              SidebarXItem(icon: Icons.description, label: 'Reports'),
              SidebarXItem(icon: Icons.settings, label: 'Settings'),
            ],
            footerBuilder: (context, extended) => Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.teal),
                    onPressed: () => theme.toggle(),
                  ),
                  if (extended) const SizedBox(width: 10),
                  if (extended) Text('Theme', style: GoogleFonts.inter(color: Colors.teal)),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: screens[_controller.selectedIndex],
              key: ValueKey<int>(_controller.selectedIndex),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────── DASHBOARD PAGE ──────────────────────
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  final String meterId = '955afea6-0e6e-43c3-88af-b7bf3d4a8485';

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            childAspectRatio: 1.4,
            children: [
              StreamBuilder(
                stream: supabase.from('meters').stream(primaryKey: ['id']).eq('id', meterId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Card(child: Center(child: CircularProgressIndicator()));
                  }
                  final meter = snapshot.data![0];
                  final credit = double.tryParse(meter['current_credit'].toString()) ?? 0.0;
                  final valveOpen = meter['valve_status'] == true;

                  return Card(
                    elevation: 15,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: credit < 20 ? [Colors.red[800]!, Colors.red[600]!] : [Colors.teal[800]!, Colors.teal[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 50, color: Colors.white),
                          const SizedBox(height: 16),
                          Text('Credit Balance', style: GoogleFonts.inter(color: Colors.white70, fontSize: 18)),
                          Text('\$${credit.toStringAsFixed(2)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(valveOpen ? Icons.lock_open : Icons.lock, color: valveOpen ? Colors.lightGreenAccent : Colors.redAccent, size: 30),
                              const SizedBox(width: 8),
                              Text(valveOpen ? 'Valve OPEN' : 'Valve CLOSED', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.speed, size: 50, color: Colors.teal),
                      const SizedBox(height: 16),
                      Text('Gas Flow Rate', style: GoogleFonts.inter(fontSize: 18)),
                      Text('5 L/min', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.bold)),
                      const Text('Normal', style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ),
              ),

              Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber, size: 50, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text('Leak Status', style: GoogleFonts.inter(fontSize: 18)),
                      Text('None Detected', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          Text('Recent Alerts', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),

          SizedBox(
            height: 300,
            child: StreamBuilder(
              stream: supabase.from('alerts').stream(primaryKey: ['id']).eq('meter_id', meterId).order('timestamp', ascending: false).limit(5),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Card(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    child: const Center(child: Text('No alerts — system stable', style: TextStyle(fontSize: 18))),
                  );
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, i) {
                    final a = snapshot.data![i];
                    final isLeak = a['type'] == 'leak';
                    return Card(
                      elevation: 6,
                      color: isDark ? Colors.grey[800] : Colors.white,
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isLeak ? Colors.red : Colors.orange,
                          child: const Icon(Icons.warning, color: Colors.white),
                        ),
                        title: Text(a['type'].toString().toUpperCase(), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(a['message'], style: GoogleFonts.inter(fontSize: 15)),
                        trailing: Text(DateTime.parse(a['timestamp']).toLocal().toString().substring(0, 16), style: GoogleFonts.inter(color: Colors.grey)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────── REAL AI CHAT PAGE (Gemini) ──────────────────────
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;

  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: 'AIzaSyCra6qwYR7E06LBPnE4CAXVWaeMJrEvE2A',
  );

  Future<void> _sendMessage() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': userMessage});
      _loading = true;
    });

    _controller.clear();

    try {
      final content = [Content.text(userMessage)];
      final response = await _model.generateContent(content);

      setState(() {
        _messages.add({'role': 'model', 'text': response.text ?? 'No response'});
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'model', 'text': 'Error: $e'});
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['role'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.teal : (isDark ? Colors.grey[800] : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    msg['text']!,
                    style: GoogleFonts.inter(color: isUser ? Colors.white : null),
                  ),
                ),
              );
            },
          ),
        ),
        if (_loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Ask about your gas meter...',
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                onPressed: _sendMessage,
                backgroundColor: Colors.teal,
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Placeholder pages
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Analytics', style: Theme.of(context).textTheme.headlineMedium));
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Reports', style: Theme.of(context).textTheme.headlineMedium));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Settings', style: Theme.of(context).textTheme.headlineMedium));
  }
}