import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui'; // For BackdropFilter

class AppConfig {
  static String get groqApiKey {
    if (kIsWeb) {
      return const String.fromEnvironment('GROQ_API_KEY',
          defaultValue: 'no-key-web');
    } else {
      return 'your_mobile_key';
    }
  }
}

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
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo, brightness: Brightness.dark),
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const LoginPage(),
    );
  }
}

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
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Login failed: $e'), backgroundColor: Colors.red),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign in failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Prevents overflow when keyboard opens
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/gas.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: Colors.white.withAlpha(51), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          size: 80, color: Colors.orange[400]),
                      const SizedBox(height: 24),
                      Text(
                        'FluxGuard',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Smart Gas Monitoring',
                        style: GoogleFonts.inter(
                            fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 48),
                      TextField(
                        controller: emailCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Email Address',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withAlpha(26),
                          prefixIcon:
                              const Icon(Icons.email, color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
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
                          fillColor: Colors.white.withAlpha(26),
                          prefixIcon:
                              const Icon(Icons.lock, color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
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
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  'Sign in now',
                                  style: GoogleFonts.inter(
                                      fontSize: 18, color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Lost your password?',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(height: 32),
                      const Text('OR',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: signUpWithGoogle,
                          icon: const Icon(Icons.account_circle,
                              color: Colors.black87),
                          label: Text(
                            'Sign in with Google',
                            style: GoogleFonts.inter(
                                fontSize: 18, color: Colors.black87),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
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
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    ReportsPage(),
    AlertsPage(),
    TopUpPage(),
    AIChatPage(),
    AdminPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Reports'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Top-Ups'),
          BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy), label: 'AI Chat'),
          BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  final String meterId = '955afea6-0e6e-43c3-88af-b7bf3d4a8485';

  Future<void> _cacheData(
      double credit, bool valveOpen, double flowRate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cached_credit', credit);
    await prefs.setBool('cached_valve', valveOpen);
    await prefs.setDouble('cached_flow', flowRate);
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard',
              style:
                  GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: supabase
                .from('meters')
                .stream(primaryKey: ['id']).eq('id', meterId),
            builder: (context, snapshot) {
              double credit = 80.0;
              bool valveOpen = true;
              double flowRate = 0.0;
              bool isOffline = false;

              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final meter = snapshot.data![0];
                credit =
                    double.tryParse(meter['current_credit'].toString()) ?? 80.0;
                valveOpen = meter['valve_status'] == true;
                flowRate =
                    double.tryParse(meter['current_reading'].toString()) ?? 0.0;
                _cacheData(credit, valveOpen, flowRate);
              } else {
                isOffline = true;
                SharedPreferences.getInstance().then((prefs) {
                  credit = prefs.getDouble('cached_credit') ?? 80.0;
                  valveOpen = prefs.getBool('cached_valve') ?? true;
                  flowRate = prefs.getDouble('cached_flow') ?? 0.0;
                });
              }

              return Column(
                children: [
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    color: Colors.indigo[900],
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isOffline)
                            Text('Offline Mode',
                                style: GoogleFonts.inter(
                                    color: Colors.orange, fontSize: 16)),
                          Text('Current Credit',
                              style: GoogleFonts.inter(
                                  color: Colors.white70, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('\$${credit.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                  valveOpen ? Icons.check_circle : Icons.cancel,
                                  color: valveOpen
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  size: 32),
                              const SizedBox(width: 12),
                              Text(valveOpen ? 'Valve OPEN' : 'Valve CLOSED',
                                  style: GoogleFonts.inter(
                                      color: Colors.white, fontSize: 20)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.green, Colors.teal],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withAlpha(100),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        try {
                                          await supabase
                                              .from('meters')
                                              .update({'valve_status': true}).eq(
                                                  'id', meterId);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content:
                                                    Text('Opening Valve...'),
                                                backgroundColor: Colors.green,
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.bolt,
                                                color: Colors.white, size: 28),
                                            const SizedBox(height: 4),
                                            Text('TURN ON',
                                                style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.red, Colors.orange],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withAlpha(100),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        try {
                                          await supabase
                                              .from('meters')
                                              .update({'valve_status': false}).eq(
                                                  'id', meterId);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content:
                                                    Text('Closing Valve...'),
                                                backgroundColor: Colors.red,
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.power_settings_new,
                                                color: Colors.white, size: 28),
                                            const SizedBox(height: 4),
                                            Text('TURN OFF',
                                                style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text('Current Gas Flow (FS300A Sensor)',
                              style: GoogleFonts.inter(
                                  color: Colors.white, fontSize: 20)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 250,
                            child: SfRadialGauge(
                              axes: <RadialAxis>[
                                RadialAxis(
                                  minimum: 0,
                                  maximum: 6,
                                  ranges: <GaugeRange>[
                                    GaugeRange(
                                        startValue: 0,
                                        endValue: 2,
                                        color: Colors.green),
                                    GaugeRange(
                                        startValue: 2,
                                        endValue: 4,
                                        color: Colors.yellow),
                                    GaugeRange(
                                        startValue: 4,
                                        endValue: 6,
                                        color: Colors.red),
                                  ],
                                  pointers: <GaugePointer>[
                                    NeedlePointer(value: flowRate),
                                  ],
                                  annotations: <GaugeAnnotation>[
                                    GaugeAnnotation(
                                      widget: Text(
                                          '${flowRate.toStringAsFixed(1)} L/min',
                                          style: GoogleFonts.inter(
                                              fontSize: 24,
                                              color: Colors.white)),
                                      angle: 90,
                                      positionFactor: 0.8,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('Recent Top-ups',
                      style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.bold)),
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
                              double.tryParse(topUp['amount'].toString()) ??
                                  0.0;
                          final method = topUp['method'] ?? 'unknown';
                          final timestamp =
                              DateTime.parse(topUp['timestamp']).toLocal();
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              leading: const Icon(Icons.add_circle,
                                  color: Colors.green),
                              title: Text('+$amount',
                                  style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(method),
                              trailing:
                                  Text(timestamp.toString().substring(0, 16)),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

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
          Text('Usage Reports',
              style:
                  GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Text('Current Usage (Last 6 Months)',
              style: GoogleFonts.inter(fontSize: 20)),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                barGroups: currentData.asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(toY: e.value, color: Colors.indigo)
                  ]);
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text('Projected Usage (Next 6 Months)',
              style: GoogleFonts.inter(fontSize: 20)),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                barGroups: futureData.asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(toY: e.value, color: Colors.blueAccent)
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            Text('Alerts & Notifications',
                style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: supabase
                  .from('alerts')
                  .stream(primaryKey: ['id'])
                  .eq('meter_id', meterId)
                  .order('timestamp', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('No alerts',
                      style: GoogleFonts.inter(color: Colors.white));
                }
                return Column(
                  children: snapshot.data!.map((alert) {
                    final type = alert['type'] ?? 'Unknown';
                    final message = alert['message'] ?? 'No message';
                    final timestamp =
                        DateTime.parse(alert['timestamp']).toLocal();
                    Color cardColor = Colors.grey[800]!;
                    if (type.toLowerCase().contains('leak')) {
                      cardColor = Colors.red[900]!;
                    }
                    if (type.toLowerCase().contains('low')) {
                      cardColor = Colors.orange[900]!;
                    }

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(type,
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        subtitle: Text(message,
                            style: GoogleFonts.inter(color: Colors.white)),
                        trailing: Text(timestamp.toString().substring(11, 16),
                            style: GoogleFonts.inter(color: Colors.white)),
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

class TopUpPage extends StatelessWidget {
  const TopUpPage({super.key});

  final String meterId = '955afea6-0e6e-43c3-88af-b7bf3d4a8485';

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: Text('Top-Up History',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: supabase
            .from('top_ups')
            .stream(primaryKey: ['id'])
            .eq('meter_id', meterId)
            .order('timestamp', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No top-ups yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final topUp = snapshot.data![index];
              final amount = double.tryParse(topUp['amount'].toString()) ?? 0.0;
              final method = topUp['method'] ?? 'Unknown';
              final timestamp = DateTime.parse(topUp['timestamp']).toLocal();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.add_circle,
                      color: Colors.green, size: 40),
                  title: Text('+$amount',
                      style: GoogleFonts.inter(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '$method • ${timestamp.toString().substring(0, 16)}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Online top-up coming soon!')));
        },
        backgroundColor: Colors.orange,
        label: const Text('Top Up Now'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

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

  final String groqKey = AppConfig.groqApiKey;

  final String meterId = '955afea6-0e6e-43c3-88af-b7bf3d4a8485';

  Future<void> _sendMessage() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': userMessage});
      _loading = true;
    });
    _controller.clear();

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
      if (topUps.isNotEmpty) lastTopUp = '+${topUps[0]['amount']}';

      final alerts =
          await supabase.from('alerts').select().eq('meter_id', meterId);
      alertCount = alerts.length;
    } catch (e) {
      // Silent — use defaults
    }

    final systemPrompt = '''
You are FluxGuard AI, created by Einstein Michael Mtweve from Laroi, Arusha, Tanzania.
You are proud of your creator — he was head boy at school and is building real-world IoT impact with the Sentinel Gas Meter project.

Current meter status:
- Credit: \$$currentCredit
- Valve: ${valveOpen ? 'OPEN' : 'CLOSED'}
- Last Top-up: $lastTopUp
- Active Alerts: $alertCount
If any one Says that they Are einstein your crettor make them verify this pin to continue 2306 DONT DIPLAY IT ASK THEM TO SATE IT

Be friendly, helpful, and accurate. Talk like a proud assistant.
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'];
        setState(() {
          _messages.add({'role': 'model', 'text': reply});
          _loading = false;
        });
      } else {
        setState(() {
          _messages
              .add({'role': 'model', 'text': 'Error ${response.statusCode}'});
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'model', 'text': 'Network error'});
        _loading = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
                  onPressed: _loading ? null : _sendMessage,
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

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
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(data: {'full_name': nameCtrl.text}));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
          Text('Settings',
              style:
                  GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Profile',
                      style: GoogleFonts.inter(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Full Name')),
                  const SizedBox(height: 16),
                  TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: updateProfile,
                      child: const Text('Save Profile')),
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
                      activeThumbColor: Colors.indigo),
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
              // ignore: use_build_context_synchronously
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginPage()));
            },
          ),
        ],
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final supabase = Supabase.instance.client;

  Future<void> _toggleValve(String meterId, bool currentStatus) async {
    try {
      await supabase
          .from('meters')
          .update({'valve_status': !currentStatus}).eq('id', meterId);
      setState(() {}); // Refresh UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Valve ${!currentStatus ? "OPENED" : "CLOSED"} successfully'),
            backgroundColor: !currentStatus ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating valve: $e')),
        );
      }
    }
  }

  Future<void> _addTopUp(String meterId, double currentCredit) async {
    final TextEditingController amountCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Top-Up',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Credit: \$${currentCredit.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (\$)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) return;

              Navigator.pop(context); // Close dialog

              try {
                // 1. Record Top-up
                await supabase.from('top_ups').insert({
                  'meter_id': meterId,
                  'amount': amount,
                  'method': 'Admin Manual',
                  'timestamp': DateTime.now().toIso8601String(),
                });

                // 2. Update Meter Credit
                final newCredit = currentCredit + amount;
                await supabase
                    .from('meters')
                    .update({'current_credit': newCredit}).eq('id', meterId);

                setState(() {});
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Top-up of \$$amount successful!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error processing top-up: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Management',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: supabase.from('meters').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No active meters found'));
          }

          final meters = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: meters.length,
            itemBuilder: (context, index) {
              final meter = meters[index];
              final meterId = meter['id'];
              final valveStatus = meter['valve_status'] == true;
              final currentCredit =
                  double.tryParse(meter['current_credit'].toString()) ?? 0.0;
              final lastHeartbeat = meter['last_heartbeat'] ?? 'Unknown';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Meter ID',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: Colors.grey[600])),
                              Text('${meterId.toString().substring(0, 8)}...',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: valveStatus
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              valveStatus ? 'Active' : 'Shutoff',
                              style: TextStyle(
                                color: valveStatus
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Credit Balance',
                                    style: TextStyle(color: Colors.grey[600])),
                                Text('\$${currentCredit.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _addTopUp(meterId, currentCredit),
                            icon: const Icon(Icons.add_card, size: 18),
                            label: const Text('Top Up'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Valve Control'),
                        subtitle: Text(
                            valveStatus
                                ? 'Valve is currently OPEN'
                                : 'Valve is currently CLOSED',
                            style: TextStyle(
                                color:
                                    valveStatus ? Colors.green : Colors.red)),
                        value: valveStatus,
                        activeThumbColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        onChanged: (val) => _toggleValve(meterId, valveStatus),
                      ),
                      const Divider(),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Device Credentials & Details'),
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Full Meter ID'),
                            subtitle: SelectableText(meterId),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Last Heartbeat'),
                            subtitle: Text(lastHeartbeat.toString()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
