import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // For BackdropFilter
import 'services/meter_service.dart';
import 'services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/notification_service.dart';
import 'package:crypto/crypto.dart';

class AppConfig {
  static String get groqApiKey {
    // Check .env first as it's more reliable in this setup
    final envKey = dotenv.env['GROQ_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey.trim();

    // Fallback to dart-define
    const cliKey = String.fromEnvironment('GROQ_API_KEY');
    return cliKey.trim();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    await NotificationService.init();
  } catch (e) {
    debugPrint('DEBUG: Firebase/Notification initialization failed: $e');
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('DEBUG: .env load failed: $e');
  }

  final key = dotenv.env['GROQ_API_KEY'];
  debugPrint(
      'DEBUG: GROQ_API_KEY loaded: ${key != null && key.isNotEmpty ? "YES (First 5: ${key.substring(0, 5)}...)" : "NO"}');

  try {
    await Supabase.initialize(
      url: 'https://hugqwdfledpcsbupoagc.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1Z3F3ZGZsZWRwY3NidXBvYWdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MTcyMzIsImV4cCI6MjA4MDQ5MzIzMn0.ZWdUiYZaRLa0HZvzGVl2SBSkgkzBUrYXMjknp7rWYRM',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (e) {
    debugPrint('DEBUG: Supabase initialization failed: $e');
    // We continue even if init fails to allow the app to boot into offline-capable screens
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppTheme()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
      child: const FluxGuardApp(),
    ),
  );
}

class FluxGuardColors {
  static const Color background = Color(0xFF0F172A);
  static const Color cardBackground = Color(0xFF1E293B);
  static const Color primary = Color(0xFF3B82F6); // AI Blue
  static const Color accent = Color(0xFFF97316); // Orange
  static const Color success = Color(0xFF22C55E); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color info = Color(0xFF06B6D4); // Cyan
  static const Color danger = Color(0xFFEF4444); // Red
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient successGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme extends ChangeNotifier {
  bool isDark = true; // Still supporting dark mode only as requested

  ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: FluxGuardColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FluxGuardColors.primary,
      brightness: Brightness.dark,
      surface: FluxGuardColors.cardBackground,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineMedium: GoogleFonts.inter(
        color: FluxGuardColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
      bodyLarge: GoogleFonts.inter(
        color: FluxGuardColors.textPrimary,
        fontSize: 16,
      ),
      bodySmall: GoogleFonts.inter(
        color: FluxGuardColors.textSecondary,
        fontSize: 12,
      ),
    ),
    cardTheme: CardThemeData(
      color: FluxGuardColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
    ),
  );
}

class FluxGuardApp extends StatelessWidget {
  const FluxGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppTheme>(context);

    return MaterialApp(
      title: 'FluxGuard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: theme.themeData,
      darkTheme: theme.themeData,
      home: const AuthWrapper(),
    );
  }
}

// AuthWrapper to handle session persistence
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCachedMeter = prefs.getString('offline_meter_id') != null;
    
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && mounted) {
        // Use addPostFrameCallback to navigate after build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        });
        return;
      }
    } catch (e) {
      debugPrint('DEBUG: Session check failed (most likely offline): $e');
    }

    // Fallback for offline mode: if we have cached data, we can proceed to HomeScreen
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.every((r) => r == ConnectivityResult.none);
    
    if (isOffline && hasCachedMeter && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen(isOffline: true)),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const LoginPage();
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
  final _passFocus = FocusNode();
  bool loading = false;

  @override
  void dispose() {
    _passFocus.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> login() async {
    setState(() => loading = true);
    final email = emailCtrl.text.trim();
    final password = passCtrl.text;

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // On successful login, cache credentials and user info
      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offline_email', email);
        await prefs.setString('offline_pass_hash', _hashPassword(password));

        // Cache role and meter_id for later use
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role, meter_id')
              .eq('id', response.user!.id)
              .single();

          await prefs.setString('offline_role', profile['role'] ?? 'user');
          if (profile['meter_id'] != null) {
            await prefs.setString('offline_meter_id', profile['meter_id']);
          }
        } catch (e) {
          debugPrint('Failed to cache profile info: $e');
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      debugPrint('DEBUG: Login error type: ${e.runtimeType}, error: $e');

      // Broader check for network errors or specific Supabase offline states
      bool isOffline = e is AuthException &&
          (e.statusCode == '0' ||
              e.message.contains('connection') ||
              e.message.contains('Failed host lookup'));

      if (!isOffline) {
        // Check for common socket/http errors that might not be AuthException
        final errString = e.toString().toLowerCase();
        isOffline = errString.contains('socketexception') ||
            errString.contains('failed host lookup') ||
            errString.contains('connection') ||
            errString.contains('network');
      }

      if (isOffline) {
        final prefs = await SharedPreferences.getInstance();
        final cachedEmail = prefs.getString('offline_email');
        final cachedHash = prefs.getString('offline_pass_hash');

        if (cachedEmail == email && cachedHash == _hashPassword(password)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offline Mode: Using cached credentials'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const HomeScreen(isOffline: true)));
          }
          return;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No cached credentials for this user or wrong password'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Login failed: $e'), backgroundColor: Colors.red),
          );
        }
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
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passFocus);
                        },
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
                        focusNode: _passFocus,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => login(),
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
  final bool isOffline;
  const HomeScreen({super.key, this.isOffline = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userRole = 'user'; // Default to user role
  bool _isLoadingRole = true;
  int _adminTabIndex = 0; // For admin tab navigation

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    if (widget.isOffline) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userRole = prefs.getString('offline_role') ?? 'user';
        _isLoadingRole = false;
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId != null) {
        final response = await supabase
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .single();

        final role = response['role'] ?? 'user';
        setState(() {
          _userRole = role;
          _isLoadingRole = false;
        });

        // Cache role for offline use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offline_role', role);
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userRole = prefs.getString('offline_role') ?? 'user';
        _isLoadingRole = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onAdminTabTapped(int index) {
    setState(() => _adminTabIndex = index);
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange[900],
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Text(
            'Offline Mode - Using Cached Data',
            style: GoogleFonts.inter(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = Provider.of<ConnectivityService>(context);
    final isOffline = connectivity.isOffline;

    if (_isLoadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If admin, show admin tabs instead of regular user navigation
    if (_userRole == 'admin') {
      final List<Widget> adminPages = [
        const AdminDashboardTab(),
        const AdminUsersTab(),
        const AdminMetersTab(),
        const AdminSettingsTab(),
      ];

      return Scaffold(
        appBar: AppBar(
          title: Text(
              isOffline
                  ? 'FluxGuard Admin (Offline)'
                  : 'FluxGuard Admin',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor:
              isOffline ? Colors.orange[900] : Colors.indigo[900],
          foregroundColor: Colors.white,
          bottom: isOffline
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(24),
                  child: _buildOfflineBanner(),
                )
              : null,
        ),
        body: adminPages[_adminTabIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.indigo,
          currentIndex: _adminTabIndex,
          onTap: _onAdminTabTapped,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
            BottomNavigationBarItem(
                icon: Icon(Icons.gas_meter), label: 'Meters'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      );
    }

    // Regular user navigation
    final List<Widget> pages = [
      DashboardPage(isOffline: isOffline),
      ReportsPage(isOffline: isOffline),
      const AlertsPage(),
      const TopUpPage(),
      const AIInsightPage(),
      const SettingsPage(),
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined), 
          activeIcon: Icon(Icons.home),
          label: 'Dashboard'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Reports'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Alerts'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.credit_card_outlined),
          activeIcon: Icon(Icons.credit_card),
          label: 'Top-Ups'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome),
          label: 'AI Insight'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings'),
    ];

    return Scaffold(
      appBar: isOffline
          ? PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: SafeArea(child: _buildOfflineBanner()),
            )
          : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: FluxGuardColors.cardBackground,
          selectedItemColor: FluxGuardColors.primary,
          unselectedItemColor: FluxGuardColors.textSecondary,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: navItems,
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final bool isOffline;
  const DashboardPage({super.key, this.isOffline = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  String? meterId;
  String? userName;
  bool? _localValveStatus;
  bool _isLoadingMeterId = true;
  MeterService? _meterService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAlert = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadUserMeterId();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _meterService?.dispose();
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUserMeterId() async {
    final supabase = Supabase.instance.client;
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final profile = await supabase.from('profiles').select('meter_id, full_name').eq('id', userId).single();
        setState(() {
          meterId = profile['meter_id'];
          userName = profile['full_name'] ?? 'edg fahim';
          _isLoadingMeterId = false;
          if (meterId != null) _meterService = MeterService(meterId!);
        });
      } else {
        setState(() => _isLoadingMeterId = false);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        meterId = prefs.getString('offline_meter_id');
        userName = 'edg fahim';
        _isLoadingMeterId = false;
        if (meterId != null) _meterService = MeterService(meterId!);
      });
    }
  }

  Future<void> _toggleValve(bool newStatus) async {
    if (meterId == null) return;
    setState(() => _localValveStatus = newStatus);
    try {
      await Supabase.instance.client.from('meters').update({'valve_status': newStatus}).eq('id', meterId!);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMeterId) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (meterId == null) return _buildNoMeterState();

    return Scaffold(
      body: StreamBuilder(
        stream: Supabase.instance.client.from('meters').stream(primaryKey: ['id']).eq('id', meterId!),
        builder: (context, snapshot) {
          double credit = 0.0;
          bool valveOpen = false;
          double velocity = 0.0;
          bool leakDetected = false;

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final meter = snapshot.data![0];
            credit = double.tryParse(meter['current_credit'].toString()) ?? 0.0;
            valveOpen = _localValveStatus ?? (meter['valve_status'] == true);
            velocity = double.tryParse(meter['velocity']?.toString() ?? '0.0') ?? 0.0;
            leakDetected = meter['gas_leak'] == true;
            
            if (leakDetected && !_isPlayingAlert) {
              _isPlayingAlert = true;
              _audioPlayer.setReleaseMode(ReleaseMode.loop);
              _audioPlayer.play(UrlSource('https://www.soundjay.com/buttons/beep-01a.mp3'));
            } else if (!leakDetected && _isPlayingAlert) {
              _isPlayingAlert = false;
              _audioPlayer.stop();
            }
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_localValveStatus == true && (_meterService?.currentFlow ?? 0.0) > 0.5) _buildLeakAlert(true),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildCreditCard(credit),
                    const SizedBox(height: 30),
                    _buildValveControls(valveOpen),
                    const SizedBox(height: 30),
                    _buildFlowGauge(velocity),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome Back,', style: Theme.of(context).textTheme.bodySmall),
              Text(userName ?? 'edg fahim', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: FluxGuardColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FluxGuardColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: FluxGuardColors.success, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Connected', style: GoogleFonts.inter(color: FluxGuardColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(double credit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: FluxGuardColors.cardBackground,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Credit', style: GoogleFonts.inter(color: FluxGuardColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: credit),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Text(
                '${value.toStringAsFixed(2)} TZS',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildValveControls(bool isOpen) {
    return Row(
      children: [
        Expanded(child: _buildValveButton(
          label: 'OPEN VALVE',
          icon: Icons.water_drop,
          color: FluxGuardColors.success,
          isActive: isOpen,
          onTap: () => _toggleValve(true),
        )),
        const SizedBox(width: 20),
        Expanded(child: _buildValveButton(
          label: 'CLOSE VALVE',
          icon: Icons.block,
          color: FluxGuardColors.danger,
          isActive: !isOpen,
          onTap: () => _toggleValve(false),
        )),
      ],
    );
  }

  Widget _buildValveButton({required String label, required IconData icon, required Color color, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : FluxGuardColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isActive ? color : Colors.transparent, width: 2),
          boxShadow: isActive ? [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2)
          ] : [],
        ),
        child: Column(
          children: [
            FadeTransition(
              opacity: isActive ? _pulseController : const AlwaysStoppedAnimation(1.0),
              child: Icon(icon, color: isActive ? color : FluxGuardColors.textSecondary, size: 32),
            ),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.inter(color: isActive ? Colors.white : FluxGuardColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowGauge(double velocity) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FluxGuardColors.cardBackground,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: SfRadialGauge(
              axes: [
                RadialAxis(
                  minimum: 0, maximum: 6, startAngle: 180, endAngle: 0,
                  showLabels: false, showTicks: false,
                  axisLineStyle: const AxisLineStyle(thickness: 0.2, thicknessUnit: GaugeSizeUnit.factor, cornerStyle: CornerStyle.bothCurve),
                  pointers: [
                    RangePointer(value: velocity, width: 0.2, sizeUnit: GaugeSizeUnit.factor, cornerStyle: CornerStyle.bothCurve, color: FluxGuardColors.primary),
                    MarkerPointer(value: velocity, markerType: MarkerType.circle, color: Colors.white, markerHeight: 12, markerWidth: 12),
                  ],
                  annotations: [
                    GaugeAnnotation(
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(velocity.toStringAsFixed(2), style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('m/s Flow Rate', style: GoogleFonts.inter(fontSize: 12, color: FluxGuardColors.textSecondary)),
                        ],
                      ),
                      angle: 90, positionFactor: 0.1,
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMeterState() {
    return const Scaffold(body: Center(child: Text('No meter assigned', style: TextStyle(color: Colors.white))));
  }

  Widget _buildLeakAlert(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRITICAL: LEAK DETECTED',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Valve has been automatically closed to prevent hazards. Please check your appliance.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.red[200] : Colors.red[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportsPage extends StatefulWidget {
  final bool isOffline;
  const ReportsPage({super.key, this.isOffline = false});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? meterId;
  bool _isLoadingMeterId = true;

  @override
  void initState() {
    super.initState();
    _loadUserMeterId();
  }

  Future<void> _loadUserMeterId() async {
    final supabase = Supabase.instance.client;
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final profile = await supabase.from('profiles').select('meter_id').eq('id', userId).single();
        setState(() {
          meterId = profile['meter_id'];
          _isLoadingMeterId = false;
        });
      } else {
        setState(() => _isLoadingMeterId = false);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        meterId = prefs.getString('offline_meter_id');
        _isLoadingMeterId = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMeterId) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (meterId == null) return const Scaffold(body: Center(child: Text('No meter assigned', style: TextStyle(color: Colors.white))));

    return Scaffold(
      body: StreamBuilder(
        stream: Supabase.instance.client.from('meters').stream(primaryKey: ['id']).eq('id', meterId!),
        builder: (context, snapshot) {
          double totalVolume = 0.0;
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            totalVolume = double.tryParse(snapshot.data![0]['total_volume'].toString()) ?? 0.0;
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(totalVolume)),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildChartSection(
                      title: 'Weekly Usage',
                      subtitle: 'Gas consumption in Liters',
                      child: _buildLineChart(),
                    ),
                    const SizedBox(height: 30),
                    _buildChartSection(
                      title: 'Monthly Forecast',
                      subtitle: 'Predicted usage based on AI',
                      child: _buildBarChart(),
                    ),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(double total) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics', style: Theme.of(context).textTheme.bodySmall),
          Text('Consumption Reports', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: FluxGuardColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: FluxGuardColors.primary.withValues(alpha: 0.2))),
            child: Row(
              children: [
                const Icon(Icons.show_chart, color: FluxGuardColors.primary, size: 30),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Consumption', style: GoogleFonts.inter(color: FluxGuardColors.textSecondary, fontSize: 12)),
                    Text('${total.toStringAsFixed(1)} Liters', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: FluxGuardColors.cardBackground, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: FluxGuardColors.textSecondary)),
          const SizedBox(height: 20),
          SizedBox(height: 200, child: child),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [const FlSpot(0, 3), const FlSpot(2, 5), const FlSpot(4, 4), const FlSpot(6, 8)],
            isCurved: true,
            color: FluxGuardColors.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: FluxGuardColors.primary.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: FluxGuardColors.primary, width: 15, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 10, color: FluxGuardColors.primary, width: 15, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 14, color: FluxGuardColors.primary, width: 15, borderRadius: BorderRadius.circular(4))]),
        ],
      ),
    );
  }
}

class AlertsPage extends StatefulWidget {
  final bool isOffline;
  const AlertsPage({super.key, this.isOffline = false});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  String? meterId;
  bool _isLoadingMeterId = true;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['All', 'Critical', 'Maintenance', 'Billing'];

  @override
  void initState() {
    super.initState();
    _loadUserMeterId();
  }

  Future<void> _loadUserMeterId() async {
    final supabase = Supabase.instance.client;
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final profile = await supabase.from('profiles').select('meter_id').eq('id', userId).single();
        setState(() {
          meterId = profile['meter_id'];
          _isLoadingMeterId = false;
        });
      } else {
        setState(() => _isLoadingMeterId = false);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        meterId = prefs.getString('offline_meter_id');
        _isLoadingMeterId = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMeterId) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (meterId == null) return const Scaffold(body: Center(child: Text('No meter assigned', style: TextStyle(color: Colors.white))));

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildFilters()),
          StreamBuilder(
            stream: Supabase.instance.client.from('alerts').stream(primaryKey: ['id']).eq('meter_id', meterId!).order('timestamp', ascending: false),
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? [];
              final filteredAlerts = alerts.where((a) {
                if (_selectedCategory == 'All') return true;
                return (a['type'] ?? '').toString().toLowerCase().contains(_selectedCategory.toLowerCase());
              }).toList();

              if (filteredAlerts.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text('No events found', style: TextStyle(color: Colors.grey))));
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildAlertItem(filteredAlerts[index]),
                    childCount: filteredAlerts.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity', style: Theme.of(context).textTheme.bodySmall),
          Text('History & Logs', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: FluxGuardColors.cardBackground,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: FluxGuardColors.textSecondary, size: 20),
                hintText: 'Find specific events...',
                hintStyle: TextStyle(color: FluxGuardColors.textSecondary),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: _categories.map((c) {
          final isSelected = _selectedCategory == c;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(c, style: TextStyle(color: isSelected ? Colors.white : FluxGuardColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              selected: isSelected,
              onSelected: (s) => setState(() => _selectedCategory = c),
              selectedColor: FluxGuardColors.primary,
              backgroundColor: FluxGuardColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.transparent)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    final type = (alert['type'] ?? 'Info').toString();
    final message = (alert['message'] ?? '').toString();
    final time = DateTime.parse(alert['timestamp']).toLocal();
    
    Color color = FluxGuardColors.primary;
    IconData icon = Icons.info_outline;
    
    if (type.toLowerCase().contains('leak')) {
      color = FluxGuardColors.danger;
      icon = Icons.warning_amber_rounded;
    } else if (type.toLowerCase().contains('credit')) {
      color = FluxGuardColors.warning;
      icon = Icons.payment;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluxGuardColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${time.hour}:${time.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: FluxGuardColors.textSecondary, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: FluxGuardColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
}
}

class TopUpPage extends StatefulWidget {
  final bool isOffline;
  const TopUpPage({super.key, this.isOffline = false});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  String? meterId;
  bool _isLoadingMeterId = true;

  @override
  void initState() {
    super.initState();
    _loadUserMeterId();
  }

  Future<void> _loadUserMeterId() async {
    final supabase = Supabase.instance.client;
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final profile = await supabase.from('profiles').select('meter_id').eq('id', userId).single();
        setState(() {
          meterId = profile['meter_id'];
          _isLoadingMeterId = false;
        });
      } else {
        setState(() => _isLoadingMeterId = false);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        meterId = prefs.getString('offline_meter_id');
        _isLoadingMeterId = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMeterId) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (meterId == null) return const Scaffold(body: Center(child: Text('No meter assigned', style: TextStyle(color: Colors.white))));

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          StreamBuilder(
            stream: Supabase.instance.client.from('top_ups').stream(primaryKey: ['id']).eq('meter_id', meterId!).order('timestamp', ascending: false),
            builder: (context, snapshot) {
              final topUps = snapshot.data ?? [];
              if (topUps.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text('No transactions', style: TextStyle(color: Colors.grey))));
              }

              return SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTransactionCard(topUps[index]),
                    childCount: topUps.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: FluxGuardColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Credit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payments', style: Theme.of(context).textTheme.bodySmall),
          Text('Credit History', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> topUp) {
    final amount = double.tryParse(topUp['amount'].toString()) ?? 0.0;
    final method = topUp['method'] ?? 'Mobile Money';
    final time = DateTime.parse(topUp['timestamp']).toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FluxGuardColors.cardBackground,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: FluxGuardColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet_outlined, color: FluxGuardColors.success, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${time.day}/${time.month}/${time.year}', style: const TextStyle(color: FluxGuardColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text('+${amount.toStringAsFixed(0)} TZS', style: GoogleFonts.outfit(color: FluxGuardColors.success, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}

class AIInsightPage extends StatefulWidget {
  const AIInsightPage({super.key});

  @override
  State<AIInsightPage> createState() => _AIInsightPageState();
}

class _AIInsightPageState extends State<AIInsightPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  String? meterId;
  bool _isLoadingMeterId = true;
  List<Map<String, dynamic>> _sessions = [];
  int _currentSessionIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserMeterId();
    _loadAllSessions();
  }

  Future<void> _loadAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedSessions = prefs.getString('chat_sessions');
    if (storedSessions != null) {
      try {
        final List<dynamic> decoded = jsonDecode(storedSessions);
        setState(() {
          _sessions = decoded.map((s) => Map<String, dynamic>.from(s)).toList();
          if (_sessions.isEmpty) _createNewSession();
        });
      } catch (e) {
        _createNewSession();
      }
    } else {
      _createNewSession();
    }
  }

  void _createNewSession() {
    setState(() {
      _sessions.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': 'New Insight',
        'messages': <Map<String, String>>[],
      });
      _currentSessionIndex = 0;
    });
    _saveAllSessions();
  }

  void _deleteSession(int index) {
    setState(() {
      _sessions.removeAt(index);
      if (_sessions.isEmpty) {
        _createNewSession();
      } else if (_currentSessionIndex >= _sessions.length) {
        _currentSessionIndex = _sessions.length - 1;
      } else if (_currentSessionIndex > index) {
        _currentSessionIndex--;
      }
    });
    _saveAllSessions();
  }

  Future<void> _saveAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_sessions', jsonEncode(_sessions));
  }

  List<Map<String, String>> get _messages {
    if (_sessions.isEmpty || _currentSessionIndex >= _sessions.length) return [];
    final msgs = _sessions[_currentSessionIndex]['messages'] as List;
    return msgs.map((m) => Map<String, String>.from(m)).toList();
  }

  set _messages(List<Map<String, String>> newMessages) {
    if (_sessions.isNotEmpty) {
      _sessions[_currentSessionIndex]['messages'] = newMessages;
      if (newMessages.length == 1 && _sessions[_currentSessionIndex]['title'] == 'New Insight') {
        String firstMsg = newMessages[0]['text'] ?? '';
        _sessions[_currentSessionIndex]['title'] =
            firstMsg.length > 20 ? '${firstMsg.substring(0, 20)}...' : firstMsg;
      }
    }
  }

  Future<void> _loadUserMeterId() async {
    final prefs = await SharedPreferences.getInstance();
    final supabase = Supabase.instance.client;
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final profile = await supabase.from('profiles').select('meter_id').eq('id', userId).single();
        setState(() {
          meterId = profile['meter_id'];
          _isLoadingMeterId = false;
        });
      } else {
        setState(() => _isLoadingMeterId = false);
      }
    } catch (e) {
      setState(() {
        meterId = prefs.getString('offline_meter_id');
        _isLoadingMeterId = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    final initialMsgs = List<Map<String, String>>.from(_messages);
    initialMsgs.add({'role': 'user', 'text': userMessage});
    setState(() {
      _messages = initialMsgs;
      _loading = true;
    });
    _controller.clear();

    double currentCredit = 0.0;
    bool valveOpen = false;
    try {
      if (meterId != null) {
        final meter = await Supabase.instance.client.from('meters').select().eq('id', meterId!).single();
        currentCredit = double.tryParse(meter['current_credit'].toString()) ?? 0.0;
        valveOpen = meter['valve_status'] == true;
      }
    } catch (_) {}

    final systemPrompt = '''
You are FluxGuard AI Insight, a premium assistant for smart LPG gas meters in Tanzania.
Status: Credit $currentCredit TZS, Valve ${valveOpen ? 'OPEN' : 'CLOSED'}.
Goal: Provide proactive, smart insights and help with cooking/recipes.
Tone: Professional, high-tech, helpful.
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${AppConfig.groqApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            ..._messages.map((m) => {
              'role': m['role'] == 'model' ? 'assistant' : m['role'],
              'content': m['text']
            }),
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'];
        final finalMsgs = List<Map<String, String>>.from(_messages);
        finalMsgs.add({'role': 'assistant', 'text': reply});
        setState(() {
          _messages = finalMsgs;
          _loading = false;
        });
        _saveAllSessions();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMeterId) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                return _buildMessageBubble(msg['text']!, msg['role'] == 'user');
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: FluxGuardColors.cardBackground.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Builder(builder: (context) => IconButton(
            icon: const Icon(Icons.menu_open, color: FluxGuardColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          )),
          const SizedBox(width: 10),
          const Icon(Icons.auto_awesome, color: FluxGuardColors.primary, size: 28),
          const SizedBox(width: 12),
          Text('AI Insight', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
          const Spacer(),
          const CircleAvatar(
            backgroundColor: FluxGuardColors.primary,
            radius: 18,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) const CircleAvatar(
            backgroundColor: FluxGuardColors.cardBackground,
            child: Icon(Icons.auto_awesome, color: FluxGuardColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? FluxGuardColors.primary : FluxGuardColors.cardBackground,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: isUser ? [
                  BoxShadow(color: FluxGuardColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
                ] : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Text(
                text,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: FluxGuardColors.cardBackground,
            child: Icon(Icons.auto_awesome, color: FluxGuardColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: FluxGuardColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('...', style: GoogleFonts.inter(color: FluxGuardColors.primary, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FluxGuardColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: FluxGuardColors.textSecondary),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: FluxGuardColors.primary),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: FluxGuardColors.background,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: FluxGuardColors.primary),
            child: Center(child: Text('Conversations', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
          ),
          ListTile(
            leading: const Icon(Icons.add, color: FluxGuardColors.primary),
            title: const Text('New Session', style: TextStyle(color: Colors.white)),
            onTap: () {
              _createNewSession();
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_sessions[index]['title'], style: const TextStyle(color: Colors.white)),
                  selected: _currentSessionIndex == index,
                  onTap: () {
                    setState(() => _currentSessionIndex = index);
                    Navigator.pop(context);
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

class SettingsPage extends StatefulWidget {
  final bool isOffline;
  const SettingsPage({super.key, this.isOffline = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String userName = 'edg fahim';
  String userEmail = 'fahim@fluxguard.io';
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final profile = await supabase.from('profiles').select('full_name, email').eq('id', user.id).single();
        setState(() {
          userName = profile['full_name'] ?? 'edg fahim';
          userEmail = profile['email'] ?? user.email ?? '';
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildProfileHeader()),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionHeader('ACCOUNT'),
                _buildSettingsTile(icon: Icons.person_outline, title: 'Edit Profile', subtitle: userName, color: Colors.blue),
                _buildSettingsTile(icon: Icons.notifications_none_outlined, title: 'Notifications', color: Colors.orange, isSwitch: true, switchValue: notificationsEnabled, onSwitchChanged: (v) => setState(() => notificationsEnabled = v)),
                const SizedBox(height: 20),
                _buildSectionHeader('SYSTEM'),
                _buildSettingsTile(icon: Icons.dark_mode_outlined, title: 'Dark Mode', color: Colors.purple, isSwitch: true, switchValue: true, onSwitchChanged: (v) {}),
                _buildSettingsTile(icon: Icons.security_outlined, title: 'Security & Privacy', color: Colors.cyan),
                const SizedBox(height: 20),
                _buildSectionHeader('SUPPORT'),
                _buildSettingsTile(icon: Icons.help_outline, title: 'Help Center', color: Colors.teal),
                _buildSettingsTile(icon: Icons.info_outline, title: 'About FluxGuard', color: Colors.grey),
                const SizedBox(height: 40),
                _buildLogoutButton(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 40, left: 20, right: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [FluxGuardColors.primary.withValues(alpha: 0.2), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: FluxGuardColors.primary, width: 2)),
            child: CircleAvatar(radius: 50, backgroundColor: FluxGuardColors.cardBackground, child: Text(userName[0].toUpperCase(), style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
          const SizedBox(height: 15),
          Text(userName, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(userEmail, style: GoogleFonts.inter(fontSize: 14, color: FluxGuardColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: FluxGuardColors.textSecondary, letterSpacing: 1.5)),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, String? subtitle, required Color color, bool isSwitch = false, bool switchValue = false, Function(bool)? onSwitchChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: FluxGuardColors.cardBackground, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: FluxGuardColors.textSecondary, fontSize: 12)) : null,
        trailing: isSwitch ? Switch(value: switchValue, onChanged: onSwitchChanged, activeColor: color) : const Icon(Icons.chevron_right, color: FluxGuardColors.textSecondary),
        onTap: isSwitch ? null : () {},
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => Supabase.instance.client.auth.signOut().then((_) => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()))),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: FluxGuardColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: FluxGuardColors.danger.withValues(alpha: 0.2))),
        child: const Center(child: Text('Sign Out', style: TextStyle(color: FluxGuardColors.danger, fontWeight: FontWeight.bold, fontSize: 16))),
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String _userRole = 'user';
  bool _isCheckingRole = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .single();

        if (mounted) {
          setState(() {
            _userRole = response['role'] ?? 'user';
            _isCheckingRole = false;
          });
        }
      } else {
        if (mounted) setState(() => _isCheckingRole = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isCheckingRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show loading while checking role
    if (_isCheckingRole) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF101018) : Colors.grey[50],
        body: const Center(
            child: CircularProgressIndicator(color: Colors.indigo)),
      );
    }

    // If not admin, show access denied
    if (_userRole != 'admin') {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF101018) : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.red),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.lock_rounded, size: 64, color: Colors.red[400]),
              ),
              const SizedBox(height: 24),
              Text(
                'Access Denied',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You do not have admin privileges',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Admin access granted - show tabbed admin panel
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101018) : Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF101018) : Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [Colors.indigo.shade900, const Color(0xFF101018)]
                          : [Colors.indigo.shade300, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.admin_panel_settings,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Admin Console',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.cyanAccent,
                indicatorWeight: 3,
                labelColor: isDark ? Colors.white : Colors.indigo[900],
                unselectedLabelColor:
                    isDark ? Colors.white54 : Colors.grey[600],
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Users'),
                  Tab(text: 'Meters'),
                  Tab(text: 'Settings'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            const AdminDashboardTab(),
            const AdminUsersTab(),
            const AdminMetersTab(),
            const AdminSettingsTab(),
          ],
        ),
      ),
    );
  }
}

// Dashboard Tab
class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder(
            stream: supabase.from('profiles').stream(primaryKey: ['id']),
            builder: (context, profileSnapshot) {
              return StreamBuilder(
                stream: supabase.from('meters').stream(primaryKey: ['id']),
                builder: (context, meterSnapshot) {
                  int totalUsers = 0;
                  int totalMeters = 0;
                  double totalCredits = 0.0;
                  double totalUsageM3 = 0.0;
                  double totalAmountLiters = 0.0;
                  int activeMeters = 0;

                  if (profileSnapshot.hasData) {
                    totalUsers = profileSnapshot.data!.length;
                  }

                  if (meterSnapshot.hasData && meterSnapshot.data!.isNotEmpty) {
                    totalMeters = meterSnapshot.data!.length;
                    for (var meter in meterSnapshot.data!) {
                      totalCredits += double.tryParse(
                              meter['current_credit']?.toString() ?? '0') ??
                          0.0;
                      totalUsageM3 += double.tryParse(
                              meter['current_reading']?.toString() ?? '0') ??
                          0.0;
                      totalAmountLiters += double.tryParse(
                              meter['total_volume']?.toString() ?? '0') ??
                          0.0;
                      if (meter['valve_status'] == true) activeMeters++;
                    }
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Users',
                              totalUsers.toString(),
                              Icons.people_outline,
                              Colors.blueAccent,
                              isDark,
                              0,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Total Meters',
                              totalMeters.toString(),
                              Icons.gas_meter_outlined,
                              Colors.purpleAccent,
                              isDark,
                              100,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Active',
                              activeMeters.toString(),
                              Icons.check_circle_outline,
                              Colors.greenAccent,
                              isDark,
                              200,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Credits',
                              '${totalCredits.toStringAsFixed(0)} TZS',
                              Icons.account_balance_wallet_outlined,
                              Colors.orangeAccent,
                              isDark,
                              300,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total (m³)',
                              '${totalUsageM3.toStringAsFixed(2)}',
                              Icons.analytics_outlined,
                              Colors.indigoAccent,
                              isDark,
                              400,
                            ),
                          ),
                          Expanded(
                            child: _buildStatCard(
                              'Total (Liters)',
                              '${totalAmountLiters.toStringAsFixed(0)}',
                              Icons.gas_meter,
                              Colors.orangeAccent,
                              isDark,
                              500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Recent Top-up Activity',
            style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.indigo[900]),
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: supabase
                .from('top_ups')
                .stream(primaryKey: ['id'])
                .order('timestamp', ascending: false)
                .limit(10),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('No recent activity',
                        style: GoogleFonts.inter(color: Colors.grey)),
                  ),
                );
              }
              return Column(
                children: snapshot.data!.map((topUp) {
                  final amount =
                      double.tryParse(topUp['amount']?.toString() ?? '0') ??
                          0.0;
                  final timestamp =
                      DateTime.parse(topUp['timestamp']).toLocal();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2336) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_circle_outline,
                            color: Colors.green, size: 24),
                      ),
                      title: Text(
                        '+${amount.toStringAsFixed(2)} TZS',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      subtitle: Text(
                        topUp['method'] ?? 'Unknown method',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      trailing: Text(
                        '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}\n${timestamp.day}/${timestamp.month}',
                        textAlign: TextAlign.right,
                        style:
                            GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
    int delay, {
    bool fullWidth = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutBack,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Container(
            width: fullWidth ? double.infinity : null,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2336) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: fullWidth
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Users Tab
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase().trim();
                  });
                },
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.grey,
                  ),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.indigoAccent),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          // Users List
          Expanded(
            child: StreamBuilder(
              stream: supabase.from('profiles').stream(primaryKey: ['id']),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Something went wrong',
                            style: GoogleFonts.inter(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.indigo),
                  );
                }

                // Filter users based on search query
                final allUsers = snapshot.data!;
                final users = allUsers.where((user) {
                  final email = (user['email'] ?? '').toString().toLowerCase();
                  final name =
                      (user['full_name'] ?? '').toString().toLowerCase();
                  return email.contains(_searchQuery) ||
                      name.contains(_searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No users found'
                              : 'No matches found',
                          style: GoogleFonts.inter(
                              fontSize: 16, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                  physics: const BouncingScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userId = user['id'];
                    final email = user['email'] ?? 'No email';
                    final fullName = user['full_name'] ?? 'No name';
                    final meterId = user['meter_id'];

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 400 + (index * 100)),
                      curve: Curves.easeOutQuart,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E2336) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withValues(alpha: 0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.indigo.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserDetailPage(
                                      userId: userId, meterId: meterId),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Avatar
                                  Hero(
                                    tag: 'avatar_$userId',
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.indigo.shade400,
                                            Colors.indigo.shade800,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.indigo.withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        fullName.isNotEmpty
                                            ? fullName[0].toUpperCase()
                                            : 'U',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 20),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 18,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          email,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),

                                        // Credit Pill
                                        FutureBuilder(
                                          future: meterId != null
                                              ? supabase
                                                  .from('meters')
                                                  .select('current_credit')
                                                  .eq('id', meterId)
                                                  .single()
                                              : null,
                                          builder: (context, meterSnapshot) {
                                            double credit = 0.0;
                                            if (meterSnapshot.hasData) {
                                              credit = double.tryParse(
                                                      meterSnapshot.data![
                                                                  'current_credit']
                                                              ?.toString() ??
                                                          '0') ??
                                                  0.0;
                                            }

                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.green
                                                        .withValues(alpha: 0.2)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .account_balance_wallet,
                                                    size: 14,
                                                    color: Colors.green,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${credit.toStringAsFixed(2)} TZS',
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Arrow
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterUserPage()),
          );
        },
        backgroundColor: Colors.indigoAccent,
        elevation: 8,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(
          'Add User',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

// User Detail Page
class UserDetailPage extends StatefulWidget {
  final String userId;
  final String? meterId;

  const UserDetailPage({super.key, required this.userId, this.meterId});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  final supabase = Supabase.instance.client;
  String? _currentMeterId; // Track the current meter ID in state

  @override
  void initState() {
    super.initState();
    _currentMeterId = widget.meterId;
  }

  Future<void> _changeMeter() async {
    try {
      // Fetch all available meters
      final meters = await supabase.from('meters').select();

      if (!mounted) return;

      String? selectedMeterId = _currentMeterId;
      String searchQuery = '';

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter meters based on search query
            final filteredMeters = meters.where((meter) {
              final meterId = meter['id'].toString().toLowerCase();
              final credit = meter['current_credit']?.toString() ?? '0';
              return meterId.contains(searchQuery.toLowerCase()) ||
                  credit.contains(searchQuery);
            }).toList();

            return AlertDialog(
              title: Text('Change Meter Assignment',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select a meter to assign to this user',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Search Meter',
                        hintText: 'Search by ID or credit...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Scrollable meter list
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: filteredMeters.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'No meters found',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: [
                                // Option to remove meter
                                RadioListTile<String?>(
                                  title: const Text(
                                      'No Meter (Remove Assignment)'),
                                  subtitle: Text(
                                    'User will have no meter assigned',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  value: null,
                                  groupValue: selectedMeterId,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedMeterId = value;
                                    });
                                  },
                                ),
                                const Divider(),
                                // List of meters
                                 ...filteredMeters.map((meter) {
                                  final meterId = meter['id'];
                                  final credit = double.tryParse(
                                          meter['current_credit']?.toString() ??
                                              '0') ??
                                      0.0;
                                  final valveStatus =
                                      meter['valve_status'] == true;

                                  return RadioListTile<String>(
                                    title: Text(
                                      '${meterId.toString().substring(0, 20)}...',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Credit: ${credit.toStringAsFixed(2)} TZS',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                        Text(
                                          'Status: ${valveStatus ? "Open" : "Closed"}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: valveStatus
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    value: meterId,
                                    groupValue: selectedMeterId,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        selectedMeterId = value;
                                      });
                                    },
                                  );
                                }),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Note: Multiple users can share the same meter.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    try {
                      await supabase.from('profiles').update({
                        'meter_id': selectedMeterId,
                      }).eq('id', widget.userId);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Meter assignment updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Update the state with the new meter ID
                        setState(() {
                          _currentMeterId = selectedMeterId;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  child: const Text('Update',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meters: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete this user? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete user profile (Supabase auth will cascade delete)
      await supabase.from('profiles').delete().eq('id', widget.userId);

      // Try to delete auth user (requires service role key in production)
      // For now, just delete the profile which will prevent login

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to users list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _topUpUser(double currentCredit) async {
    final TextEditingController amountCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Top-Up User',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Credit: ${currentCredit.toStringAsFixed(2)} TZS'),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (TZS)',
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

              Navigator.pop(context);

              try {
                await supabase.from('top_ups').insert({
                  'meter_id': _currentMeterId,
                  'amount': amount,
                  'method': 'Admin Manual',
                  'timestamp': DateTime.now().toIso8601String(),
                });

                final newCredit = currentCredit + amount;
                await supabase.from('meters').update(
                    {'current_credit': newCredit}).eq('id', _currentMeterId!);

                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Top-up of $amount TZS successful!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
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

  Future<void> _toggleValve(bool currentStatus) async {
    try {
      await supabase
          .from('meters')
          .update({'valve_status': !currentStatus}).eq('id', _currentMeterId!);
      setState(() {});
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Details',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete User',
            onPressed: _deleteUser,
          ),
        ],
      ),
      body: FutureBuilder(
        future:
            supabase.from('profiles').select().eq('id', widget.userId).single(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnapshot.data!;
          final email = user['email'] ?? 'No email';
          final fullName = user['full_name'] ?? 'No name';

          if (_currentMeterId == null) {
            // Show user details with option to assign meter
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Information Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User Information',
                              style: GoogleFonts.inter(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person),
                            title: const Text('Full Name'),
                            subtitle: Text(fullName),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.email),
                            title: const Text('Email'),
                            subtitle: Text(email),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // No Meter Card
                  Card(
                    elevation: 4,
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.gas_meter_outlined,
                            size: 80,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Meter Assigned',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This user currently has no gas meter assigned.\nAssign a meter to enable gas monitoring and control.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _changeMeter,
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 24),
                              label: Text(
                                'Assign Meter',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[700],
                                foregroundColor: Colors.white,
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Info Card
                  Card(
                    elevation: 2,
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[700], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Multiple users can share the same meter for shared facilities.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder(
            stream: supabase
                .from('meters')
                .stream(primaryKey: ['id']).eq('id', _currentMeterId!),
            builder: (context, meterSnapshot) {
              double credit = 0.0;
              bool valveStatus = true;
              double velocity = 0.0;
              double totalLiters = 0.0;

              if (meterSnapshot.hasData && meterSnapshot.data!.isNotEmpty) {
                final meter = meterSnapshot.data![0];
                credit = double.tryParse(
                        meter['current_credit']?.toString() ?? '0') ??
                    0.0;
                valveStatus = meter['valve_status'] == true;
                velocity = double.tryParse(
                        meter['current_reading']?.toString() ?? '0') ??
                    0.0;
                totalLiters =
                    double.tryParse(meter['total_volume']?.toString() ?? '0') ??
                        0.0;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('User Information',
                                style: GoogleFonts.inter(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person),
                              title: const Text('Full Name'),
                              subtitle: Text(fullName),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.email),
                              title: const Text('Email'),
                              subtitle: Text(email),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.gas_meter),
                              title: const Text('Meter ID'),
                              subtitle: SelectableText(
                                  _currentMeterId ?? 'Not assigned'),
                              trailing: ElevatedButton.icon(
                                onPressed: _changeMeter,
                                icon: const Icon(Icons.swap_horiz, size: 16),
                                label: const Text('Change'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Credit Balance',
                                    style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                ElevatedButton.icon(
                                  onPressed: () => _topUpUser(credit),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Top Up'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${credit.toStringAsFixed(2)} TZS',
                              style: GoogleFonts.inter(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sensor Real-time Data',
                                style: GoogleFonts.inter(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading:
                                  const Icon(Icons.speed, color: Colors.blue),
                              title: const Text('Flow Velocity'),
                              subtitle:
                                  Text('${velocity.toStringAsFixed(2)} L/min'),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.gas_meter,
                                  color: Colors.orange),
                              title: const Text('Total Gas Amount'),
                              subtitle: Text(
                                  '${totalLiters.toStringAsFixed(2)} Liters'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text('Valve Control',
                                style: GoogleFonts.inter(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Meter Valve'),
                              subtitle: Text(
                                valveStatus ? 'Valve OPEN' : 'Valve CLOSED',
                                style: TextStyle(
                                    color:
                                        valveStatus ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                              value: valveStatus,
                              activeThumbColor: Colors.green,
                              inactiveThumbColor: Colors.red,
                              onChanged: (val) => _toggleValve(valveStatus),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Register User Page
class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({super.key});

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final supabase = Supabase.instance.client;
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  String selectedRole = 'user'; // Default role
  bool loading = false;

  Future<void> _registerUser() async {
    if (emailCtrl.text.isEmpty ||
        passwordCtrl.text.isEmpty ||
        nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await supabase.auth.signUp(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
      );

      if (response.user != null) {
        // Use upsert to handle cases where profile already exists from trigger
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'email': emailCtrl.text.trim(),
          'full_name': nameCtrl.text,
          'role': selectedRole,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User registered successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register New User',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'User Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.admin_panel_settings),
                ),
                value: selectedRole,
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedRole = value);
                }
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : _registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register User',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Meters Tab
class AdminMetersTab extends StatelessWidget {
  const AdminMetersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      body: StreamBuilder(
        stream: supabase.from('meters').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No meters registered'));
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
                  double.tryParse(meter['current_credit']?.toString() ?? '0') ??
                      0.0;
              final velocity = double.tryParse(
                      meter['current_reading']?.toString() ?? '0') ??
                  0.0;
              final totalLiters =
                  double.tryParse(meter['total_volume']?.toString() ?? '0') ??
                      0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    Icons.gas_meter,
                    color: valveStatus ? Colors.green : Colors.red,
                    size: 40,
                  ),
                  title: Text(
                    'Meter ${meterId.toString().substring(0, 8)}...',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Credit: ${currentCredit.toStringAsFixed(2)} TZS',
                          style: GoogleFonts.inter()),
                      Text(
                        valveStatus ? 'Active' : 'Shutoff',
                        style: GoogleFonts.inter(
                          color: valveStatus ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Velocity: ${velocity.toStringAsFixed(2)} L/min | Total: ${totalLiters.toStringAsFixed(1)} L',
                        style:
                            GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MeterDetailPage(meterId: meterId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterMeterPage()),
          );
        },
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add Meter'),
      ),
    );
  }
}

// Meter Detail Page
class MeterDetailPage extends StatelessWidget {
  final String meterId;

  const MeterDetailPage({super.key, required this.meterId});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: Text('Meter Details',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: supabase
            .from('meters')
            .stream(primaryKey: ['id']).eq('id', meterId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final meter = snapshot.data![0];
          final valveStatus = meter['valve_status'] == true;
          final currentCredit =
              double.tryParse(meter['current_credit']?.toString() ?? '0') ??
                  0.0;
          final usageRate =
              double.tryParse(meter['usage_rate']?.toString() ?? '0') ?? 0.0;
          final velocity =
              double.tryParse(meter['current_reading']?.toString() ?? '0') ??
                  0.0;
          final totalLiters =
              double.tryParse(meter['total_volume']?.toString() ?? '0') ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Meter Information',
                            style: GoogleFonts.inter(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Meter ID'),
                          subtitle: SelectableText(meterId),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Valve Status'),
                          subtitle: Text(
                            valveStatus ? 'OPEN' : 'CLOSED',
                            style: TextStyle(
                              color: valveStatus ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Current Credit'),
                          subtitle: Text(
                            '${currentCredit.toStringAsFixed(2)} TZS',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Usage Rate'),
                          subtitle:
                              Text('${usageRate.toStringAsFixed(2)} TZS/m³'),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Real-time Velocity'),
                          subtitle:
                              Text('${velocity.toStringAsFixed(2)} L/min'),
                          leading: const Icon(Icons.speed, color: Colors.blue),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Total Gas Amount'),
                          subtitle:
                              Text('${totalLiters.toStringAsFixed(2)} Liters'),
                          leading:
                              const Icon(Icons.gas_meter, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Register Meter Page
class RegisterMeterPage extends StatefulWidget {
  const RegisterMeterPage({super.key});

  @override
  State<RegisterMeterPage> createState() => _RegisterMeterPageState();
}

class _RegisterMeterPageState extends State<RegisterMeterPage> {
  final supabase = Supabase.instance.client;
  String? selectedUserId;
  bool loading = false;

  Future<void> _registerMeter() async {
    if (selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // Create new meter
      final meterResponse = await supabase
          .from('meters')
          .insert({
            'user_id': selectedUserId,
            'current_credit': 0.0,
            'usage_rate': 0.05,
            'valve_status': true,
          })
          .select()
          .single();

      final newMeterId = meterResponse['id'];

      // Update user profile with meter_id
      await supabase
          .from('profiles')
          .update({'meter_id': newMeterId}).eq('id', selectedUserId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meter registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register New Meter',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign meter to user:',
              style:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: supabase.from('profiles').stream(primaryKey: ['id']),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No users available');
                }

                final users = snapshot.data!;

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Select User',
                  ),
                  initialValue: selectedUserId,
                  items: users.map<DropdownMenuItem<String>>((user) {
                    final fullName = user['full_name'] ?? 'No name';
                    final email = user['email'] ?? '';
                    return DropdownMenuItem<String>(
                      value: user['id'],
                      child: Text('$fullName ($email)'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedUserId = value);
                  },
                );
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : _registerMeter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register Meter',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Settings Tab
class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Settings',
              style:
                  GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Account Information'),
                  subtitle:
                      Text(supabase.auth.currentUser?.email ?? 'No email'),
                  trailing: const Icon(Icons.chevron_right),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  subtitle: const Text('Manage alert preferences'),
                  trailing: Switch(
                    value: true,
                    onChanged: (val) {},
                  ),
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.attach_money),
                  title: Text('Default Usage Rate'),
                  subtitle: Text('50 TZS per Liter'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('System Information'),
                  subtitle: Text('FluxGuard v1.0.0'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.red[50],
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text('Sign Out',
                  style: GoogleFonts.inter(
                      color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                await supabase.auth.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
