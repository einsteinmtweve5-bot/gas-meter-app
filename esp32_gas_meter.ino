/**
 * FluxGuard - Final Debug Firmware
 * -------------------------------
 * This version includes:
 * 1. Startup Hardware Test (Relay should click twice)
 * 2. Manual Serial Overrides (Type 'ON' or 'OFF' in Serial Monitor)
 * 3. Supabase Real-time Sync (Velocity & Total Volume)
 * 4. Valve Status Polling
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// --- Configuration ---
const char* ssid = "Director WiFi";
const char* password = "africacademy2025";
const char* meter_id = "955afea6-0e6e-43c3-88af-b7bf3d4a8485";

// Supabase API details
const char* supabase_url = "https://hugqwdfledpcsbupoagc.supabase.co";
const char* supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1Z3F3ZGZsZWRwY3NidXBvYWdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MTcyMzIsImV4cCI6MjA4MDQ5MzIzMn0.ZWdUiYZaRLa0HZvzGVl2SBSkgkzBUrYXMjknp7rWYRM";

// Hardware Pins
const int sensorPin = 4;    // YSF-201 (Flow Sensor)
const int relayPin = 26;    // Updated to GPIO 26
const bool RELAY_INVERTED = false; // Set to 'true' if your relay is active-low (ON when LOW)
const int mq5Pin = 34;      // MQ-5 (Gas Sensor - Analog)

// Constants for YSF-201 and Physics
const float PULSES_PER_LITER = 400.0;
const float PIPE_DIAMETER_METERS = 0.015; // 15mm pipe example (Adjust to your pipe size)
const float CROSS_SECTION_AREA = 3.14159 * sq(PIPE_DIAMETER_METERS / 2.0);

// Gas Leak Threshold (Raw ADC 0-4095)
const int GAS_THRESHOLD = 500;
const int GAS_BASELINE_OFFSET = 200;  // Amount above baseline to trigger leak detection

// Variables
volatile long pulseCount = 0;
float flowRate = 0.0;     // L/min
float totalVolume = 0.0;  // L
float gasVelocity = 0.0;  // m/s
int rawGasValue = 0;
int gasBaseline = 0;
bool isLeakDetected = false;

unsigned long lastUpdate = 0;
unsigned long lastValveCheck = 0;
bool currentValveState = false;
bool bypassLeakDetection = false; // Disable bypass by default for safety
unsigned long lastPulseTime = 0;
long lastCheckedPulses = 0;

void IRAM_ATTR pulseCounter() {
  pulseCount++;
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\n=== FLUXGUARD ESP32 v2.0 ===");
  
  // Initialize Pins
  pinMode(sensorPin, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(sensorPin), pulseCounter, FALLING);
  
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, RELAY_INVERTED ? HIGH : LOW); // Start with valve closed
  pinMode(mq5Pin, INPUT);
  
  // --- Calibration / Warmup ---
  Serial.println("Warming up MQ-5 (3 seconds)...");
  long sum = 0;
  for(int i=0; i<30; i++) {
    sum += analogRead(mq5Pin);
    delay(100);
    if(i%10 == 0) Serial.print(".");
  }
  gasBaseline = sum / 30;
  Serial.printf("\nBaseline Set: %d\n", gasBaseline);

  // --- HARDWARE TEST ---
  Serial.println("TEST: Toggling relay ON for 2 seconds...");
  digitalWrite(relayPin, RELAY_INVERTED ? LOW : HIGH); 
  delay(2000);
  digitalWrite(relayPin, RELAY_INVERTED ? HIGH : LOW);
  Serial.println("TEST: Hardware test complete.");

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
}

void loop() {
  // Read MQ-5 Gas Sensor
  rawGasValue = analogRead(mq5Pin);
  // Improved leak detection: Use dynamic threshold based on baseline with safety margin
  int dynamicThreshold = max(GAS_THRESHOLD, gasBaseline + GAS_BASELINE_OFFSET);
  isLeakDetected = rawGasValue > dynamicThreshold;
  
  // Log gas detection values periodically for debugging
  static unsigned long lastGasLog = 0;
  if (millis() - lastGasLog > 5000) { // Log every 5 seconds
    Serial.printf("Gas: %d | Baseline: %d | Threshold: %d | Leak: %s\n", 
                  rawGasValue, gasBaseline, dynamicThreshold, isLeakDetected ? "YES" : "NO");
    lastGasLog = millis();
  }

  if (isLeakDetected && currentValveState && !bypassLeakDetection) {
    // Safety Force-Close Valve if leak detected
    Serial.printf("!!! SHUTDOWN: Gas %d (Baseline %d) !!!\n", rawGasValue, gasBaseline);
    digitalWrite(relayPin, RELAY_INVERTED ? HIGH : LOW);
    currentValveState = false;
  }

  // 3. Manual Override (Type 'ON' or 'OFF' in Serial Monitor)
  // MOVED OUTSIDE WiFi block to ensure it always works
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.equalsIgnoreCase("ON")) {
      digitalWrite(relayPin, RELAY_INVERTED ? LOW : HIGH);
      currentValveState = true;
      Serial.println(">>> MANUAL OVERRIDE: RELAY ON");
    } else if (input.equalsIgnoreCase("OFF")) {
      digitalWrite(relayPin, RELAY_INVERTED ? HIGH : LOW);
      currentValveState = false;
      Serial.println(">>> MANUAL OVERRIDE: RELAY OFF");
    } else if (input.equalsIgnoreCase("BYPASS")) {
      bypassLeakDetection = !bypassLeakDetection;
      Serial.printf(">>> LEAK BYPASS: %s\n", bypassLeakDetection ? "ENABLED (DANGEROUS)" : "DISABLED");
    }
  }

  // WiFi Maintenance
  if (WiFi.status() == WL_CONNECTED) {
    
    // 1. Every 1 second: Process Sensors
    if (millis() - lastUpdate > 1000) {
      detachInterrupt(sensorPin);
      long pulses = pulseCount;
      pulseCount = 0;
      attachInterrupt(digitalPinToInterrupt(sensorPin), pulseCounter, FALLING);
      
      // Calculate Flow Rate (L/min)
      flowRate = (float(pulses) / PULSES_PER_LITER) * 60.0;
      totalVolume += (float(pulses) / PULSES_PER_LITER);
      
      // Calculate Real Velocity (m/s)
      // Velocity = FlowRate(m3/s) / Area(m2)
      float flowRateM3s = (flowRate / 60000.0); // Convert L/min to m3/s
      gasVelocity = flowRateM3s / CROSS_SECTION_AREA;
      
      lastUpdate = millis();
      
      updateSupabase(flowRate, totalVolume, gasVelocity, isLeakDetected, rawGasValue);
      
      Serial.printf("Speed: %.2f L/min | Vel: %.2f m/s | Total: %.2f L | Gas: %d %s %s | Pulses: %ld\n", 
                    flowRate, gasVelocity, totalVolume, rawGasValue, 
                    isLeakDetected ? "[LEAK!]" : "[OK]",
                    bypassLeakDetection ? "[BYPASS]" : "",
                    pulses);
    }

    // DEBUG: Print when pulses are occurring
    if (pulseCount != lastCheckedPulses) {
       // Serial.println("Pulse!"); // Uncomment if you want to see every pulse
       lastCheckedPulses = pulseCount;
    }

    // 2. Every 2 seconds: Check Valve Status from App (unless override by leak)
    if (millis() - lastValveCheck > 2000 && (!isLeakDetected || bypassLeakDetection)) {
      checkValveStatus();
      lastValveCheck = millis();
    }
  } else {
    // Attempt reconnect every 10 seconds without spamming
    static unsigned long lastReconnectAttempt = 0;
    if (millis() - lastReconnectAttempt > 10000) {
        Serial.println("\nWiFi Lost. Retrying...");
        WiFi.disconnect();
        WiFi.begin(ssid, password);
        lastReconnectAttempt = millis();
    }
  }
}

void checkValveStatus() {
  if (strcmp(meter_id, "955afea6-0e6e-43c3-88af-b7bf3d4a8485") != 0 && strcmp(meter_id, "YOUR_METER_ID_HERE") == 0) return;

  HTTPClient http;
  String url = String(supabase_url) + "/rest/v1/meters?id=eq." + meter_id + "&select=valve_status";
  
  http.begin(url);
  http.addHeader("apikey", supabase_key);
  http.addHeader("Authorization", "Bearer " + String(supabase_key));
  
  int code = http.GET();
  if (code == 200) {
    String payload = http.getString();
    DynamicJsonDocument doc(512);
    deserializeJson(doc, payload);
    
    if (doc.size() > 0) {
      bool statusFromServer = doc[0]["valve_status"];
      if (statusFromServer != currentValveState) {
        currentValveState = statusFromServer;
        digitalWrite(relayPin, currentValveState ? (RELAY_INVERTED ? LOW : HIGH) : (RELAY_INVERTED ? HIGH : LOW));
        Serial.print("APP UPDATE: Valve is now ");
        Serial.println(currentValveState ? "OPEN" : "CLOSED");
      }
    }
  }
  http.end();
}

void updateSupabase(float flow, float total, float velocity, bool leak, int gasLevel) {
  if (strcmp(meter_id, "955afea6-0e6e-43c3-88af-b7bf3d4a8485") != 0 && strcmp(meter_id, "YOUR_METER_ID_HERE") == 0) return;

  HTTPClient http;
  String url = String(supabase_url) + "/rest/v1/meters?id=eq." + meter_id;
  
  http.begin(url);
  http.addHeader("apikey", supabase_key);
  http.addHeader("Authorization", "Bearer " + String(supabase_key));
  http.addHeader("Content-Type", "application/json");
  
  StaticJsonDocument<256> doc;
  doc["current_reading"] = flow;
  doc["total_volume"] = total;
  doc["velocity"] = velocity;
  doc["gas_leak"] = leak;
  doc["gas_level"] = gasLevel;
  
  // If a leak is detected, we also sync the valve status back to closed in Supabase
  if (leak) {
      doc["valve_status"] = false;
  }
  
  String json;
  serializeJson(doc, json);
  http.PATCH(json);
  http.end();
}
