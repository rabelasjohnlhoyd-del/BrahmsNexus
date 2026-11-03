/*
 * =====================================================================================
 * BRAHMS SISIG & BAGNET — ESP32 BASE RFID READER (BAHAY / BODEGA NI OWNER)
 * =====================================================================================
 * Microcontroller: ESP32 DOIT DevKit V1 (30-Pin)
 * RFID Reader:     RC522 (13.56MHz SPI)
 * Feedback:        Active Buzzer (D13), Green LED (D2), Red LED (D15)
 * Backend:         Supabase REST API (Direct HTTPS via process_rfid_tap RPC)
 *
 * PURPOSE:
 * 1. Production Staff DTR (Meat Cutters, Production Cooks, Commissary Helpers)
 * 2. Admin Web Card Enrollment ("Scan on Base Reader" sa Add/Edit Staff)
 *
 * NOTE: Ang mga Branch Cooks ay HINDI tatanggapin dito (re-reject-in ng Supabase
 *       upang sa biyahe lang ni driver sa branch sila makapag-time in).
 * =====================================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>

// =====================================================================================
// 1. CONFIGURATION & DEVICE IDENTITY
// =====================================================================================

// Naka-set para sa Base Station sa Bahay/Bodega ni Owner
#define DEVICE_ID "esp32_commissary_base" 

// WiFi Credentials sa Bahay / Bodega ni Owner:
const char* WIFI_SSID     = "ARDIZA"; 
const char* WIFI_PASSWORD = "CgFiwLk9";

// Supabase API Configuration:
const char* SUPABASE_URL      = "https://kumasxtsfkjjvlkptsyz.supabase.co";
const char* SUPABASE_ANON_KEY = "sb_publishable_Q20Rci63zBGFfU8BhB-Vnw_Fa1kWWYT";

// =====================================================================================
// 2. PIN DEFINITIONS (EXACT MATCH SA BRAHMS NEXUS WIRING DIAGRAM)
// =====================================================================================
#define RST_PIN    4   // D4  - RC522 RST
#define SS_PIN     5   // D5  - RC522 SDA (SS)
#define SCK_PIN    18  // D18 - RC522 SCK
#define MISO_PIN   19  // D19 - RC522 MISO
#define MOSI_PIN   23  // D23 - RC522 MOSI

#define BUZZER_PIN 13  // D13 - Active Buzzer (+)
#define LED_GREEN  2   // D2  - Green LED (220 ohm)
#define LED_RED    15  // D15 - Red LED (220 ohm)

MFRC522 mfrc522(SS_PIN, RST_PIN);

// Debounce Tracking
String lastCardUid = "";
unsigned long lastTapTime = 0;
const unsigned long DEBOUNCE_MS = 3000;

// =====================================================================================
// 3. AUDIO-VISUAL FEEDBACK FUNCTIONS
// =====================================================================================

void beep(int frequency, int durationMs) {
  tone(BUZZER_PIN, frequency, durationMs);
  delay(durationMs);
  noTone(BUZZER_PIN);
}

void playSuccessChime() {
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_RED, LOW);
  beep(1800, 100);
  delay(80);
  beep(2400, 150);
  delay(400);
  digitalWrite(LED_GREEN, LOW);
}

void playErrorTone() {
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_GREEN, LOW);
  beep(400, 500);
  digitalWrite(LED_RED, LOW);
}

void playChirp() {
  beep(2000, 50);
}

// =====================================================================================
// 4. SETUP
// =====================================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n==============================================");
  Serial.println(" BRAHMS SISIG & BAGNET — COMMISSARY BASE UNIT");
  Serial.print(" Device ID: "); Serial.println(DEVICE_ID);
  Serial.println("==============================================");

  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_RED, OUTPUT);

  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_RED, LOW);

  pinMode(SS_PIN, OUTPUT);
  digitalWrite(SS_PIN, HIGH);
  pinMode(RST_PIN, OUTPUT);
  digitalWrite(RST_PIN, HIGH);

  SPI.begin(SCK_PIN, MISO_PIN, MOSI_PIN, SS_PIN);
  delay(100);

  // Hardware Reset Pulse sa D4
  digitalWrite(RST_PIN, LOW);
  delay(50);
  digitalWrite(RST_PIN, HIGH);
  delay(50);

  // Initialize Reader
  mfrc522.PCD_Init();
  delay(150);

  byte version = mfrc522.PCD_ReadRegister(mfrc522.VersionReg);
  Serial.print("MFRC522 Version: 0x");
  Serial.println(version, HEX);

  if (version == 0x00 || version == 0xFF) {
    Serial.println("[WARNING] RC522 not responding. Retrying reset...");
    digitalWrite(RST_PIN, LOW);
    delay(50);
    digitalWrite(RST_PIN, HIGH);
    delay(50);
    mfrc522.PCD_Init();
    version = mfrc522.PCD_ReadRegister(mfrc522.VersionReg);
    Serial.print("Retried Version: 0x");
    Serial.println(version, HEX);
  } else {
    Serial.println("[SUCCESS] RC522 Hardware initialized properly!");
  }

  connectWiFi();
  playSuccessChime();
  Serial.println("\n[READY] Commissary Base Reader is ready for taps...");
}

// =====================================================================================
// 5. WIFI CONNECTION
// =====================================================================================

void connectWiFi() {
  Serial.print("[WiFi] Connecting to Home WiFi: ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 25) {
    digitalWrite(LED_RED, !digitalRead(LED_RED));
    delay(400);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(LED_RED, LOW);
    digitalWrite(LED_GREEN, HIGH);
    Serial.println("\n[WiFi] Connected successfully to Home WiFi!");
    Serial.print("[WiFi] IP Address: ");
    Serial.println(WiFi.localIP());
    delay(500);
    digitalWrite(LED_GREEN, LOW);
  } else {
    Serial.println("\n[WiFi] Failed to connect! Running in offline mode.");
    playErrorTone();
  }
}

// =====================================================================================
// 6. MAIN LOOP
// =====================================================================================

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastReconnectAttempt = 0;
    if (millis() - lastReconnectAttempt > 10000) {
      Serial.println("[WiFi] Reconnecting to Home WiFi...");
      lastReconnectAttempt = millis();
      WiFi.reconnect();
    }
  }

  if (!mfrc522.PICC_IsNewCardPresent()) {
    delay(50);
    return;
  }

  if (!mfrc522.PICC_ReadCardSerial()) {
    delay(50);
    return;
  }

  // Extract clean Hex UID
  String cardUid = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    if (mfrc522.uid.uidByte[i] < 0x10) cardUid += "0";
    cardUid += String(mfrc522.uid.uidByte[i], HEX);
    if (i < mfrc522.uid.size - 1) cardUid += ":";
  }
  cardUid.toUpperCase();

  // Debounce check
  unsigned long now = millis();
  if (cardUid == lastCardUid && (now - lastTapTime < DEBOUNCE_MS)) {
    Serial.println("[TAP] Debounce active - ignored");
    mfrc522.PICC_HaltA();
    mfrc522.PCD_StopCrypto1();
    return;
  }

  lastCardUid = cardUid;
  lastTapTime = now;

  Serial.println("\n----------------------------------------------");
  Serial.print("[BASE RFID DETECTED] UID: ");
  Serial.println(cardUid);

  playChirp();

  sendTapToSupabase(cardUid);

  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();
  delay(300);
}

// =====================================================================================
// 7. SUPABASE RPC COMMUNICATION
// =====================================================================================

void sendTapToSupabase(String uid) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[ERROR] No WiFi connection!");
    playErrorTone();
    return;
  }

  HTTPClient http;
  String endpoint = String(SUPABASE_URL) + "/rest/v1/rpc/process_rfid_tap";

  http.begin(endpoint);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);

  StaticJsonDocument<256> doc;
  doc["p_rfid_uid"] = uid;
  doc["p_device_id"] = DEVICE_ID;
  doc["p_branch_id"] = "";

  String jsonBody;
  serializeJson(doc, jsonBody);

  Serial.print("[HTTP POST] Sending UID: ");
  Serial.println(uid);

  int httpCode = http.POST(jsonBody);
  String response = http.getString();

  Serial.print("[HTTP CODE] ");
  Serial.println(httpCode);
  Serial.print("[RESPONSE] ");
  Serial.println(response);

  if (httpCode == 200 || httpCode == 201) {
    StaticJsonDocument<512> resDoc;
    DeserializationError error = deserializeJson(resDoc, response);

    if (!error) {
      bool isSuccess = resDoc["success"] | false;
      String type = resDoc["type"] | "";
      String staffName = resDoc["staff_name"] | "Staff";

      // 🟢 GREEN LED: Lalabas kapag Time-In, Time-Out, O NAG-A-ADD NG BAGONG CARD SA STAFF MANAGEMENT!
      if (isSuccess && (type == "time_in" || type == "time_out" || type == "enrollment_scan")) {
        Serial.print("[SUCCESS] ");
        Serial.print(staffName);
        Serial.print(" -> ");
        Serial.println(type);
        playSuccessChime();
      } 
      // 🔴 RED LED: Lalabas kapag tapos na ang shift, debounced, o bawal/rejected!
      else {
        Serial.print("[BLOCKED] ");
        Serial.println(resDoc["message"] | "");
        playErrorTone();
      }
    } else {
      playErrorTone();
    }
  } else {
    Serial.println("[ERROR] Server communication failed!");
    playErrorTone();
  }

  http.end();
}
