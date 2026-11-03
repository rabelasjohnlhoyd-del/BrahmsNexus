/*
 * =====================================================================================
 * BRAHMS SISIG & BAGNET — ESP32 BASE RFID READER (COMMISSARY / BODEGA NI OWNER)
 * =====================================================================================
 * Microcontroller: ESP32 DOIT DevKit V1 (30-Pin)
 * RFID Reader:     RC522 (13.56MHz SPI)
 * Display:         SSD1306 OLED 128x64 (I2C — SDA=D21, SCL=D22)
 * Feedback:        Active Buzzer (D13), Green LED (D2), Red LED (D15)
 * Backend:         Supabase REST API (Direct HTTPS via process_rfid_tap RPC)
 *
 * DEVICE ROLE:
 * Commissary Base Reader (Bahay / Bodega ni Owner)
 * 1. Production Staff DTR (Meat Cutters, Production Cooks, Commissary Helpers)
 * 2. Admin Web Card Enrollment ("Scan on Base Reader" sa Add/Edit Staff)
 *
 * NOTE: Ang mga Branch Cooks ay HINDI tatanggapin dito — sila ay mag-ta-time in
 *       sa Driver Portable Reader habang nasa biyahe papunta sa branch.
 * =====================================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// =====================================================================================
// 1. OLED CONFIGURATION
// =====================================================================================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

#define I2C_SDA 21  // D21 - OLED SDA
#define I2C_SCL 22  // D22 - OLED SCL

// =====================================================================================
// 2. CONFIGURATION & DEVICE IDENTITY
// =====================================================================================
#define DEVICE_ID "esp32_commissary_base"

// WiFi Credentials sa Bahay / Bodega ni Owner:
const char* WIFI_SSID     = "GlobeAtHome_21066_2.4";
const char* WIFI_PASSWORD = "gThC4ACN";

// Supabase API Configuration:
const char* SUPABASE_URL      = "https://kumasxtsfkjjvlkptsyz.supabase.co";
const char* SUPABASE_ANON_KEY = "sb_publishable_Q20Rci63zBGFfU8BhB-Vnw_Fa1kWWYT";

// =====================================================================================
// 3. PIN DEFINITIONS (EXACT MATCH SA BRAHMS NEXUS WIRING DIAGRAM)
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

// Debounce Tracking (3 seconds — para hindi madoble ang tap ng iisang tao)
String lastCardUid = "";
unsigned long lastTapTime = 0;
const unsigned long DEBOUNCE_MS = 3000;

// =====================================================================================
// 4. RC522 FULL HARDWARE RECOVERY
// =====================================================================================
// PINAKA-IMPORTANTENG FUNCTION:
// Kapag nag-WiFi HTTP ang ESP32, sinisira niya ang SPI bus ng RC522.
// Ang physical RST pulse sa D4 ang nag-re-restart sa RC522 chip para
// laging handa sa susunod na tap nang hindi nagha-hang.
void recoverRC522() {
  SPI.end();
  delay(10);

  pinMode(RST_PIN, OUTPUT);
  digitalWrite(RST_PIN, LOW);   // Physical RST pulse
  delay(30);
  digitalWrite(RST_PIN, HIGH);
  delay(50);

  SPI.begin(SCK_PIN, MISO_PIN, MOSI_PIN, SS_PIN);
  delay(10);
  mfrc522.PCD_Init();
  delay(50);
}

// =====================================================================================
// 5. OLED DISPLAY HELPER FUNCTIONS (CENTERED)
// =====================================================================================
void centerPrint(const String &text, int y, int size = 1) {
  int16_t x1, y1;
  uint16_t w, h;
  display.setTextSize(size);
  display.getTextBounds(text, 0, 0, &x1, &y1, &w, &h);
  int x = (SCREEN_WIDTH - w) / 2;
  if (x < 0) x = 0;
  display.setCursor(x, y);
  display.print(text);
}

void drawHeader(const String &title) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  centerPrint(title, 2, 1);
  display.drawFastHLine(0, 11, SCREEN_WIDTH, SSD1306_WHITE);
}

void showReadyScreen() {
  drawHeader("BRAHMS ATTENDANCE");
  centerPrint("PRODUCTION UNIT", 18, 1);
  centerPrint("TAP CARD", 30, 2);

  display.drawFastHLine(0, 52, SCREEN_WIDTH, SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(4, 55);
  if (WiFi.status() == WL_CONNECTED) {
    display.print("System: Online");
  } else {
    display.print("System: Offline");
  }
  display.setCursor(92, 55);
  display.print("READY");
  display.display();
}

void showProcessingScreen() {
  drawHeader("BRAHMS ATTENDANCE");
  centerPrint("PROCESSING TAP", 20, 1);
  centerPrint("Verifying Staff...", 34, 1);
  centerPrint("Please wait a moment", 48, 1);
  display.display();
}

void showSuccessScreen(String staffName, String type, String cardUid = "") {
  // Kapag Card Registration / Enrollment
  if (type == "enrollment_scan") {
    drawHeader("CARD REGISTRATION");
    centerPrint("CARD SCANNED", 18, 2);
    centerPrint(cardUid, 38, 1);
    display.drawFastHLine(0, 52, SCREEN_WIDTH, SSD1306_WHITE);
    centerPrint("Ready to Save in Admin", 55, 1);
    display.display();
    return;
  }

  // Kapag Attendance (Time-In / Time-Out)
  drawHeader("ATTENDANCE CONFIRMED");

  if (type == "time_in") {
    centerPrint("TIME IN", 18, 2);
  } else if (type == "time_out") {
    centerPrint("TIME OUT", 18, 2);
  } else {
    centerPrint("RECORDED", 18, 2);
  }

  if (staffName.length() > 18) {
    staffName = staffName.substring(0, 18);
  }
  centerPrint(staffName, 38, 1);

  display.drawFastHLine(0, 52, SCREEN_WIDTH, SSD1306_WHITE);
  centerPrint("Attendance Verified", 55, 1);
  display.display();
}

void showUnregisteredCardScreen(String cardUid) {
  drawHeader("CARD REGISTRATION");
  centerPrint("UNKNOWN CARD", 18, 2);
  if (cardUid.length() > 0) {
    centerPrint(cardUid, 38, 1);
  } else {
    centerPrint("Not Found in System", 38, 1);
  }
  display.drawFastHLine(0, 52, SCREEN_WIDTH, SSD1306_WHITE);
  centerPrint("Ready to Enroll in Admin", 55, 1);
  display.display();
}

void showErrorScreen(String code) {
  drawHeader("ATTENDANCE NOTICE");
  centerPrint("[ NOT RECORDED ]", 16, 1);

  String cleanNotice = "Please Tap Again";
  String footerNote  = "Please tap again";

  if (code == "NO_TIME_IN") {
    cleanNotice = "No Morning Time-In";
    footerNote  = "Cannot record shift";
  } else if (code == "ALREADY_TIMED_IN") {
    cleanNotice = "Already Timed-In Today";
    footerNote  = "Shift currently active";
  } else if (code == "ALREADY_COMPLETED") {
    cleanNotice = "Shift Already Ended";
    footerNote  = "Attendance complete";
  } else if (code == "DEBOUNCED") {
    cleanNotice = "Please Wait A Moment";
    footerNote  = "Card recently scanned";
  } else if (code == "UNREGISTERED") {
    cleanNotice = "Unregistered Card";
    footerNote  = "Enroll in Admin Web";
  } else if (code == "WRONG_LOCATION") {
    // Branch Cook ang nag-tap dito — dapat sa Driver Reader sila
    cleanNotice = "Use Driver Terminal";
    footerNote  = "For Branch Cook Only";
  } else if (code == "PRODUCTION_NOT_OPEN") {
    // Hindi pa binuksan ni owner ang production shift ngayon
    cleanNotice = "Shift Not Yet Open";
    footerNote  = "Wait for Admin to open";
  } else if (code == "TIMEOUT_NOT_ALLOWED") {
    // Hindi pa authorized ang time-out — hinihintay ang clearance ni admin
    cleanNotice = "Timeout Not Authorized";
    footerNote  = "Wait for clearance";
  } else if (code == "OFFLINE") {
    cleanNotice = "No WiFi Connection";
    footerNote  = "Checking connection...";
  } else if (code == "CONN_ERR" || code == "SERVER_ERR" || code == "SERVER_ERROR") {
    cleanNotice = "Server Unavailable";
    footerNote  = "Please retry shortly";
  } else if (code == "PARSE_ERR") {
    cleanNotice = "System Busy - Retry";
    footerNote  = "Please tap again";
  }

  if (cleanNotice.length() > 20) {
    cleanNotice = cleanNotice.substring(0, 20);
  }
  centerPrint(cleanNotice, 33, 1);

  display.drawFastHLine(0, 52, SCREEN_WIDTH, SSD1306_WHITE);
  centerPrint(footerNote, 55, 1);
  display.display();
}

// =====================================================================================
// 6. AUDIO-VISUAL FEEDBACK FUNCTIONS
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
  delay(200);
  digitalWrite(LED_GREEN, LOW);
}

void playErrorTone() {
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_GREEN, LOW);
  beep(400, 350);
  digitalWrite(LED_RED, LOW);
}

void playChirp() {
  beep(2000, 50);
}

// =====================================================================================
// 7. SETUP
// =====================================================================================
void setup() {
  Serial.begin(115200);
  delay(500);
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

  // Initialize I2C OLED
  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(400000);

  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("[WARNING] SSD1306 OLED not responding at 0x3C!");
  } else {
    drawHeader("BRAHMS LOGISTICS");
    centerPrint("STARTING SYSTEM...", 28, 1);
    centerPrint("Connecting WiFi...", 44, 1);
    display.display();
  }

  // Initialize RC522
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
  delay(100);

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
  showReadyScreen();
  Serial.println("\n[READY] Commissary Base Reader is ready for taps...");
}

// =====================================================================================
// 8. WIFI CONNECTION
// =====================================================================================
void connectWiFi() {
  Serial.print("[WiFi] Connecting to: ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);

  // PROTEKSYON SA BREADBOARD POWER:
  // Ibaba sa 15dBm ang WiFi TX power para maiwasan ang voltage drop sa breadboard 3.3V rail
  WiFi.setTxPower(WIFI_POWER_15dBm);

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
    Serial.println("\n[WiFi] Connected successfully!");
    Serial.print("[WiFi] IP Address: ");
    Serial.println(WiFi.localIP());
    delay(500);
    digitalWrite(LED_GREEN, LOW);
  } else {
    Serial.println("\n[WiFi] Failed to connect! Running in offline mode.");
    playErrorTone();
  }
}

// Function declaration
bool sendTapToSupabase(String uid);

// =====================================================================================
// 9. MAIN LOOP
// =====================================================================================
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastReconnectAttempt = 0;
    if (millis() - lastReconnectAttempt > 10000) {
      Serial.println("[WiFi] Reconnecting...");
      lastReconnectAttempt = millis();
      WiFi.reconnect();
    }
  }

  if (!mfrc522.PICC_IsNewCardPresent()) {
    delay(40);
    return;
  }

  if (!mfrc522.PICC_ReadCardSerial()) {
    delay(40);
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

  // Debounce check — para hindi madoble-record ang isang tap sa loob ng 3 segundo
  unsigned long now = millis();
  if (cardUid == lastCardUid && (now - lastTapTime < DEBOUNCE_MS)) {
    Serial.println("[TAP] Debounce active - ignored");
    mfrc522.PICC_HaltA();
    mfrc522.PCD_StopCrypto1();
    delay(40);
    return;
  }

  lastCardUid = cardUid;
  lastTapTime = now;

  Serial.println("\n----------------------------------------------");
  Serial.print("[BASE RFID DETECTED] UID: ");
  Serial.println(cardUid);

  // HALT CARD AGAD bago mag-WiFi HTTP para hindi ma-block ang reader
  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();

  // Immediate feedback
  playChirp();
  showProcessingScreen();

  // Send to Supabase
  sendTapToSupabase(cardUid);

  // Show result for 1.8 seconds then go back to ready
  delay(1800);
  showReadyScreen();
}

// =====================================================================================
// 10. SUPABASE HTTP POST
// =====================================================================================
bool sendTapToSupabase(String uid) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[ERROR] No WiFi connection!");
    showErrorScreen("OFFLINE");
    playErrorTone();
    recoverRC522();
    return false;
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

  bool isSuccessResult = false;

  if (httpCode == 200 || httpCode == 201) {
    StaticJsonDocument<512> resDoc;
    DeserializationError error = deserializeJson(resDoc, response);

    if (!error) {
      bool isSuccess   = resDoc["success"]    | false;
      String type      = resDoc["type"]       | "";
      String code      = resDoc["code"]       | "";
      String staffName = resDoc["staff_name"] | "Staff";
      String message   = resDoc["message"]    | "";

      // GREEN: Time-In, Time-Out, o Card Enrollment
      if (isSuccess && (type == "time_in" || type == "time_out" || type == "enrollment_scan")) {
        Serial.print("[SUCCESS] ");
        Serial.print(staffName);
        Serial.print(" -> ");
        Serial.println(type == "enrollment_scan" ? "CARD ENROLLED" : type);
        showSuccessScreen(staffName, type, uid);
        playSuccessChime();
        isSuccessResult = true;
      }
      // UNREGISTERED CARD fallback
      else if (code == "UNREGISTERED") {
        Serial.print("[NOTICE] Unregistered Card: ");
        Serial.println(uid);
        showUnregisteredCardScreen(uid);
        playErrorTone();
        isSuccessResult = false;
      }
      // RED: Rejected o may notice (Shift Not Open, Timeout Not Authorized, etc.)
      else {
        Serial.print("[NOTICE] ");
        if (message.length() > 0) {
          Serial.println(message);
        } else {
          Serial.println(code);
        }
        showErrorScreen(code);
        playErrorTone();
        isSuccessResult = false;
      }
    } else {
      Serial.println("[ERROR] System response error.");
      showErrorScreen("PARSE_ERR");
      playErrorTone();
      isSuccessResult = false;
    }
  } else {
    Serial.print("[ERROR] Server communication failed (Code ");
    Serial.print(httpCode);
    Serial.println(")");
    showErrorScreen("CONN_ERR");
    playErrorTone();
    isSuccessResult = false;
  }

  // Physical RST pulse sa D4 para ma-recover ang RC522 pagkatapos ng WiFi HTTP
  http.end();
  recoverRC522();

  return isSuccessResult;
}
