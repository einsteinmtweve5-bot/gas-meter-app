import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Service to manage credit reduction based on gas consumption
/// Logic: 0.1 Liters = 5 TZS, which means 1 Liter = 50 TZS
class MeterService extends ChangeNotifier {
  static const double TZS_PER_LITER = 50.0; // 0.1L = 5 TZS => 1L = 50 TZS
  static const String LAST_VOLUME_KEY = 'last_processed_volume';
  
  final String meterId;
  StreamSubscription? _meterSubscription;
  
  double _currentCredit = 0.0;
  double _totalVolume = 0.0;
  double _lastProcessedVolume = 0.0;
  bool _isInitialized = false;
  
  double get currentCredit => _currentCredit;
  double get totalVolume => _totalVolume;
  String get currency => 'TZS';
  bool get isInitialized => _isInitialized;
  
  MeterService(this.meterId) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    try {
      // Load last processed volume from local storage
      final prefs = await SharedPreferences.getInstance();
      _lastProcessedVolume = prefs.getDouble(LAST_VOLUME_KEY) ?? 0.0;
      
      // Start listening to meter updates
      _startListening();
    } catch (e) {
      debugPrint('MeterService initialization error: $e');
    }
  }
  
  void _startListening() {
    final supabase = Supabase.instance.client;
    
    _meterSubscription = supabase
        .from('meters')
        .stream(primaryKey: ['id'])
        .eq('id', meterId)
        .listen((data) {
      if (data.isNotEmpty) {
        _handleMeterUpdate(data[0]);
      }
    });
  }
  
  Future<void> _handleMeterUpdate(Map<String, dynamic> meterData) async {
    try {
      // Parse current values
      final newCredit = double.tryParse(meterData['current_credit']?.toString() ?? '0') ?? 0.0;
      final newVolume = double.tryParse(meterData['total_volume']?.toString() ?? '0') ?? 0.0;
      
      // On first update, just store values without processing
      if (!_isInitialized) {
        _currentCredit = newCredit;
        _totalVolume = newVolume;
        
        // If last processed volume is 0, set it to current volume
        // This prevents charging for historical consumption on first run
        if (_lastProcessedVolume == 0.0) {
          _lastProcessedVolume = newVolume;
          await _saveLastProcessedVolume();
        }
        
        _isInitialized = true;
        notifyListeners();
        return;
      }
      
      // Calculate volume consumed since last processing
      final volumeDelta = newVolume - _lastProcessedVolume;
      
      // Only process if there's a positive volume increase
      if (volumeDelta > 0.0) {
        // Calculate cost in TZS
        final cost = volumeDelta * TZS_PER_LITER;
        
        // Calculate new credit (ensure it doesn't go below 0)
        final updatedCredit = (newCredit - cost).clamp(0.0, double.infinity);
        
        debugPrint('MeterService: Volume increased by ${volumeDelta.toStringAsFixed(3)}L');
        debugPrint('MeterService: Cost = ${cost.toStringAsFixed(2)} TZS');
        debugPrint('MeterService: Credit ${newCredit.toStringAsFixed(2)} -> ${updatedCredit.toStringAsFixed(2)} TZS');
        
        // Update credit in Supabase
        await _updateCredit(updatedCredit);
        
        // Update local tracking
        _lastProcessedVolume = newVolume;
        _currentCredit = updatedCredit;
        _totalVolume = newVolume;
        
        // Save to local storage
        await _saveLastProcessedVolume();
        
        notifyListeners();
      } else {
        // No volume change or volume decreased (reset), just update local state
        _currentCredit = newCredit;
        _totalVolume = newVolume;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('MeterService update error: $e');
    }
  }
  
  Future<void> _updateCredit(double newCredit) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('meters')
          .update({'current_credit': newCredit})
          .eq('id', meterId);
    } catch (e) {
      debugPrint('MeterService credit update error: $e');
      rethrow;
    }
  }
  
  Future<void> _saveLastProcessedVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(LAST_VOLUME_KEY, _lastProcessedVolume);
    } catch (e) {
      debugPrint('MeterService save volume error: $e');
    }
  }
  
  /// Reset the volume tracking (useful when total_volume is reset)
  Future<void> resetVolumeTracking() async {
    _lastProcessedVolume = _totalVolume;
    await _saveLastProcessedVolume();
    debugPrint('MeterService: Volume tracking reset to ${_totalVolume}L');
  }
  
  @override
  void dispose() {
    _meterSubscription?.cancel();
    super.dispose();
  }
}
