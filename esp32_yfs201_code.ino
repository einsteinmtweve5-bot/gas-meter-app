/*
 * ESP32 YFS201 Water/Gas Flow Sensor with Relay Control
 * For FluxGuard Gas Meter Application
 * 
 * Hardware Connections:
 * - YFS201 Sensor Signal Pin -> GPIO 14 (D14)
 * - Relay Control Pin -> GPIO 5 (D5)
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

// Interrupt Service Routine for flow sensor
void IRAM_ATTR pulseCounter() {
  pulseCount++;
}

void setup() {
  Serial.begin(115200);
  
  // Initialize pins
  pinMode(SENSOR_PIN, INPUT_PULLUP);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW); // Start with relay OFF
  
  // Initialize sensor connection tracking
  sensorConnected = true;
  sensorErrorCount = 0;
  
  // Attach interrupt to flow sensor
  attachInterrupt(digitalPinToInterrupt(SENSOR_PIN), pulseCounter, FALLING);
  
  // Connect to WiFi
  connectWiFi();
  
  Serial.println("ESP32 YFS201 Flow Sensor Ready!");
  Serial.println("Monitoring flow and controlling relay...");
}

void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println();
  Serial.println("WiFi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  unsigned long currentTime = millis();
  
  // Measure flow every interval
  if (currentTime - lastMeasureTime >= MEASURE_INTERVAL) {
    calculateFlow();
    lastMeasureTime = currentTime;
    
    // Update Supabase with new readings
    updateSupabase();
  }
  
  // Check valve status from Supabase
  checkValveStatus();
  
  // Control relay based on valve status
  controlRelay();
  
  delay(100); // Small delay to prevent excessive CPU usage
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

void checkValveStatus() {
  HTTPClient http;
  String url = String(supabase_url) + "/rest/v1/meters?id=eq." + meter_id + "&select=valve_status";
  
  http.begin(url);
  http.addHeader("apikey", supabase_key);
  http.addHeader("Authorization", "Bearer " + String(supabase_key));
  
  int httpResponseCode = http.GET();
  
  if (httpResponseCode == 200) {
    String payload = http.getString();
    Serial.println("Supabase Response: " + payload);
    
    // Parse JSON response
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, payload);
    
    if (!error && doc.size() > 0) {
      valveStatus = doc[0]["valve_status"];
      
      if (valveStatus != lastValveStatus) {
        Serial.println(valveStatus ? "Valve Status: OPEN" : "Valve Status: CLOSED");
        lastValveStatus = valveStatus;
      }
    }
  } else {
    Serial.printf("Error getting valve status: %d\n", httpResponseCode);
  }
  
  http.end();
}

void controlRelay() {
  if (valveStatus) {
    digitalWrite(RELAY_PIN, HIGH);  // Turn relay ON (valve OPEN)
    Serial.println("Relay: ON (Valve OPEN)");
  } else {
    digitalWrite(RELAY_PIN, LOW);   // Turn relay OFF (valve CLOSED)
    Serial.println("Relay: OFF (Valve CLOSED)");
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
  jsonPayload += "\"last_updated\":\"" + getCurrentTimestamp() + "\"}";
  
  Serial.println("Updating Supabase: " + jsonPayload);
  
  int httpResponseCode = http.PATCH(jsonPayload);
  
  if (httpResponseCode == 200 || httpResponseCode == 204) {
    Serial.println("Supabase updated successfully");
  } else {
    Serial.printf("Error updating Supabase: %d\n", httpResponseCode);
    Serial.println("Response: " + http.getString());
  }
  
  http.end();
}