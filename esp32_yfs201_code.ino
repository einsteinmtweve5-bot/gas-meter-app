/*
 * ESP32 YFS201 Water/Gas Flow Sensor with Relay Control
 * For FluxGuard Gas Meter Application
 * 
 * Hardware Connections:
 * - YFS201 Sensor Signal Pin -> GPIO 14 (D14)
 * - Relay Control Pin -> GPIO 5 (D5)
 * - MQ5 Gas Sensor Analog Pin -> A0
 * - Power Supply: 5V for relay, 3.3V for ESP32
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// WiFi Configuration
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Supabase Configuration
const char* supabase_url = "https://hugqwdfledpcsbupoagc.supabase.co";
const char* supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1Z3F3ZGZsZWRwY3NidXBvYWdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MTcyMzIsImV4cCI6MjA4MDQ5MzIzMn0.ZWdUiYZaRLa0HZvzGVl2SBSkgkzBUrYXMjknp7rWYRM";

// Meter Configuration
const char* meter_id = "955afea6-0e6e-43c3-88af-b7bf3d4a8485"; // Update with your meter ID

// Pin Definitions
const int SENSOR_PIN = 14;  // YFS201 sensor signal pin
const int RELAY_PIN = 5;    // Relay control pin
const int MQ5_SENSOR_PIN = A0; // MQ5 gas sensor analog pin

// Gas Detection Threshold
const int GAS_THRESHOLD = 4000; // Adjust based on your environment

// Flow Calculation Constants
const float CALIBRATION_FACTOR = 4.8; // Pulses per liter (adjust based on your sensor)
const unsigned long MEASURE_INTERVAL = 1000; // Measure every 1 second

// Global Variables
volatile unsigned long pulseCount = 0;
unsigned long lastMeasureTime = 0;
float flowRate = 0.0;    // L/min
float totalVolume = 0.0; // Liters
float velocity = 0.0;    // m/s (calculated from flow rate)
bool valveStatus = false;
bool lastValveStatus = false;
bool sensorConnected = true;  // Track if sensor is physically connected
int sensorErrorCount = 0;     // Count consecutive zero readings
const int MAX_ERROR_COUNT = 5; // Max consecutive zero readings before declaring sensor disconnected
bool gasDetected = false;     // Track gas detection status
int gasReading = 0;           // Store current gas sensor reading
bool lastGasDetected = false; // Track previous gas detection status

// Interrupt Service Routine for flow sensor
void IRAM_ATTR pulseCounter() {
  pulseCount++;
}

String getCurrentTimestamp() {
  // This is a simplified timestamp - in practice, you'd use NTP for accurate time
  return String(millis()/1000);
}

void connectWiFi() {
  Serial.print("Connecting to WiFi");
  
  // Ensure we're not trying to set config while connecting
  if (WiFi.status() == WL_CONNECTED) {
    WiFi.disconnect();
    delay(1000);
  }
  
  WiFi.begin(ssid, password);
  
  // Set WiFi mode before connecting
  WiFi.mode(WIFI_STA);
  
  int attempts = 0;
  const int maxAttempts = 30; // 30 seconds timeout
  
  while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("WiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println();
    Serial.println("WiFi Connection Failed!");
    Serial.println("Please check your WiFi credentials.");
  }
}

void checkGasLevel() {
  // Read gas sensor value (0-4095 for ESP32 ADC)
  gasReading = analogRead(MQ5_SENSOR_PIN);
  
  // Check if gas is detected (above threshold)
  gasDetected = (gasReading > GAS_THRESHOLD);
  
  // Log gas status changes
  if (gasDetected && !lastGasDetected) {
    Serial.printf("GAS DETECTED! Level: %d - EMERGENCY SHUTDOWN!\n", gasReading);
    // In emergency situation, close valve regardless of user command
    valveStatus = false; // Force close valve
    controlRelay();
  } else if (!gasDetected && lastGasDetected) {
    Serial.printf("GAS LEVEL NORMAL. Level: %d\n", gasReading);
  }
  
  // Update last gas detection status
  lastGasDetected = gasDetected;
  
  // Print gas sensor reading periodically
  static unsigned long lastGasPrint = 0;
  if (millis() - lastGasPrint > 5000) { // Print every 5 seconds
    Serial.printf("Gas Sensor: %d | Threshold: %d | Status: %s\n", 
                  gasReading, GAS_THRESHOLD, gasDetected ? "HIGH" : "NORMAL");
    lastGasPrint = millis();
  }
}

void checkValveStatus() {
  HTTPClient http;
  String url = String(supabase_url) + "/rest/v1/meters?id=eq." + meter_id;
  
  http.begin(url);
  http.addHeader("apikey", supabase_key);
  http.addHeader("Authorization", "Bearer " + String(supabase_key));
  http.addHeader("Content-Type", "application/json");
  
  int httpResponseCode = http.GET();
  
  if (httpResponseCode == 200) {
    String payload = http.getString();
    DynamicJsonDocument doc(1024);
    deserializeJson(doc, payload);
    
    if (doc.size() > 0) {
      JsonObject meter = doc[0];
      
      // Get valve status from database
      bool newValveStatus = meter["valve_status"];
      
      // Only update valve status if gas is not detected (safety override)
      if (!gasDetected) {
        valveStatus = newValveStatus;
        
        // Control relay if valve status changed
        if (valveStatus != lastValveStatus) {
          controlRelay();
          lastValveStatus = valveStatus;
        }
      } else {
        // If gas detected, force valve closed and update database
        if (valveStatus) {
          valveStatus = false;
          lastValveStatus = valveStatus;
          controlRelay();
          updateSupabase(); // Update database to reflect forced closure
          Serial.println("VALVE FORCED CLOSED DUE TO GAS DETECTION!");
        }
      }
      
      Serial.printf("Valve Status: %s | Gas: %s | Flow: %.2f L/min\n", 
                    valveStatus ? "OPEN" : "CLOSED", 
                    gasDetected ? "DETECTED" : "NORMAL", 
                    flowRate);
    }
  } else {
    Serial.printf("Error getting valve status: %d\n", httpResponseCode);
  }
  
  http.end();
}

void controlRelay() {
  if (valveStatus && !gasDetected) {
    digitalWrite(RELAY_PIN, HIGH);  // Turn relay ON (valve OPEN)
    Serial.println("Relay: ON (Valve OPEN)");
  } else {
    digitalWrite(RELAY_PIN, LOW);   // Turn relay OFF (valve CLOSED)
    Serial.println("Relay: OFF (Valve CLOSED)");
  }
}

void calculateFlow() {
  // Calculate flow rate (L/min)
  flowRate = ((1000.0 / MEASURE_INTERVAL) * pulseCount) / CALIBRATION_FACTOR;
  
  // Check if sensor is disconnected (consecutive zero readings)
  if (pulseCount == 0) {
    sensorErrorCount++;
    if (sensorErrorCount >= MAX_ERROR_COUNT) {
      sensorConnected = false;
      flowRate = 0.0;
      velocity = 0.0;
      Serial.println("WARNING: Gas sensor appears to be disconnected!");
    }
  } else {
    // Reset error count when we get readings
    sensorErrorCount = 0;
    sensorConnected = true;
    
    // Calculate total volume
    totalVolume += flowRate / 60.0; // Add volume for this interval
    
    // Calculate velocity (assuming pipe diameter of 15mm)
    // Velocity = Flow Rate / Cross-sectional Area
    // For 15mm pipe: Area = π * (0.015/2)^2 = 0.0001767 m²
    const float PIPE_AREA = 0.0001767; // m²
    velocity = (flowRate / 1000.0) / PIPE_AREA; // m/s
  }
  
  // Reset pulse counter for next measurement
  pulseCount = 0;
  
  // Print readings to serial monitor
  if (sensorConnected) {
    Serial.printf("Flow Rate: %.2f L/min | ", flowRate);
    Serial.printf("Total Volume: %.2f L | ", totalVolume);
    Serial.printf("Velocity: %.3f m/s\n", velocity);
  } else {
    Serial.println("Sensor Disconnected - No flow data available");
  }
}

void updateSupabase() {
  HTTPClient http;
  String url = String(supabase_url) + "/rest/v1/meters?id=eq." + meter_id;
  
  http.begin(url);
  http.addHeader("apikey", supabase_key);
  http.addHeader("Authorization", "Bearer " + String(supabase_key));
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "resolution=merge-duplicates");
  
  // Create JSON payload
  String jsonPayload = "{";
  jsonPayload += "\"current_reading\":" + String(flowRate, 2) + ",";
  jsonPayload += "\"total_volume\":" + String(totalVolume, 2) + ",";
  jsonPayload += "\"velocity\":" + String(velocity, 3) + ",";
  jsonPayload += "\"sensor_connected\":" + String(sensorConnected ? "true" : "false") + ",";
  jsonPayload += "\"leak_detected\":" + String(gasDetected ? "true" : "false") + ",";
  jsonPayload += "\"gas_level\":" + String(gasReading) + ",";
  jsonPayload += "\"last_updated\":\"" + getCurrentTimestamp() + "\"}";
  
  Serial.println("Updating Supabase: " + jsonPayload);
  
  int httpResponseCode = http.PATCH(jsonPayload);
  
  if (httpResponseCode == 200 || httpResponseCode == 204) {
    Serial.println("Supabase Update Successful!");
  } else {
    Serial.printf("Supabase Update Failed: %d\n", httpResponseCode);
    Serial.println("Payload: " + jsonPayload);
  }
  
  http.end();
}

void setup() {
  Serial.begin(115200);
  
  // Initialize pins
  pinMode(SENSOR_PIN, INPUT_PULLUP);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(MQ5_SENSOR_PIN, INPUT);  // MQ5 sensor pin
  digitalWrite(RELAY_PIN, LOW); // Start with relay OFF
  
  // Initialize sensor connection tracking
  sensorConnected = true;
  sensorErrorCount = 0;
  gasDetected = false;
  lastGasDetected = false;

  // Attach interrupt to flow sensor
  attachInterrupt(digitalPinToInterrupt(SENSOR_PIN), pulseCounter, FALLING);
  
  // Connect to WiFi
  connectWiFi();
  
  Serial.println("ESP32 YFS201 Flow Sensor & MQ5 Gas Detector Ready!");
  Serial.println("Monitoring flow, gas levels, and controlling relay...");
}

void loop() {
  unsigned long currentTime = millis();
  
  // Check valve status from Supabase every 2 seconds
  static unsigned long lastValveCheck = 0;
  if (WiFi.status() == WL_CONNECTED && (currentTime - lastValveCheck > 2000)) {
    checkValveStatus();
    lastValveCheck = currentTime;
  }
  
  // Check gas level every 1 second (only if WiFi connected to save power)
  if (WiFi.status() == WL_CONNECTED) {
    checkGasLevel();
  }
  
  // Calculate flow every second
  if (currentTime - lastMeasureTime >= MEASURE_INTERVAL) {
    calculateFlow();
    lastMeasureTime = currentTime;
    
    // Update Supabase with current readings (only if WiFi connected)
    if (WiFi.status() == WL_CONNECTED) {
      updateSupabase();
    }
  }
  
  // Small delay to prevent watchdog timer issues
  delay(10);
}