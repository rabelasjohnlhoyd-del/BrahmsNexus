/*
 * =====================================================================================
 * BRAHMS SISIG & BAGNET — ESP32 RFID ATTENDANCE & BRANCH DISPATCH (BLUETOOTH PORTABLE)
 * =====================================================================================
 * Microcontroller: ESP32 DOIT DevKit V1 (30-Pin)
 * RFID Reader:     RC522 (13.56MHz SPI)
 * Display:         SSD1306 OLED 128x64 (I2C — SDA=D21, SCL=D22)
 * Feedback:        Active Buzzer (D13), Green LED (D2), Red LED (D15)
 * Communication:   Classic Bluetooth Serial (Direct to Driver Android App)
 *
 * DEVICE ROLE:
 * Driver Portable Unit (dala ng delivery driver papunta sa mga branch)
 * Ginagamit para sa TIME-IN at TIME-OUT ng mga Branch Cook habang biyahe.
 *
 * HINDI NA GUMAGAMIT NG WIFI:
 * Diretso itong kumokonekta sa cellphone ng driver gamit ang Bluetooth.
 * Walang kailangang WiFi SSID o password kailanman!
 * =====================================================================================
 */

#include <BluetoothSerial.h>
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
// 2. BLUETOOTH IDENTITY
// =====================================================================================
#define BT_DEVICE_NAME "Brahms_Driver_Reader"
BluetoothSerial SerialBT;

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
// 4. RC522 HARDWARE RECOVERY
// =====================================================================================
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
  centerPrint("DRIVER DISPATCH", 18, 1);
  centerPrint("TAP CARD", 30, 2);
  
  display.drawFastHLine(0, 52, SCREEN_WIDTH, SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(4, 55);

  // Status ng Bluetooth Connection sa Cellphone ni Driver
  if (SerialBT.hasClient()) {
    display.print("App: Connected");
    display.setCursor(92, 55);
    display.print("READY");
  } else {
    display.print("Waiting for App");
    display.setCursor(96, 55);
    display.print("PAIR");
  }
  display.display();
}

void showProcessingScreen() {
  drawHeader("BRAHMS ATTENDANCE");
  centerPrint("PROCESSING TAP", 20, 1);
  centerPrint("Verifying Cook...", 34, 1);
  centerPrint("Please wait a moment", 48, 1);
  display.display();
}

void showSuccessScreen(String staffName, String type, bool isOffline = false) {
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
  if (isOffline) {
    centerPrint("SAVED OFFLINE (SYNC)", 55, 1);
  } else {
    centerPrint("Attendance Verified", 55, 1);
  }
  display.display();
}

void showUnregisteredCardScreen(String cardUid) {
  drawHeader("CARD UNREGISTERED");
  centerPrint("UNKNOWN CARD", 18, 2);
  if (cardUid.length() > 0) {
    centerPrint(cardUid, 38, 1);
  } else {
    centerPrint("Not Found in System", 38, 1);
  }
  display.drawFastHLine(0, 52, SCREEN_WIDTH, SSD1306_WHITE);
  centerPrint("Register in Admin Web", 55, 1);
  display.display();
}

void showErrorScreen(String code) {
  drawHeader("ATTENDANCE NOTICE");
  centerPrint("[ NOT RECORDED ]", 16, 1);
  
  String cleanNotice = "Please Tap Again";
  String footerNote  = "Please tap again";

  if (code == "NO_APP" || code == "DISCONNECTED") {
    cleanNotice = "Phone Not Connected";
    footerNote  = "Open Driver App";
  } else if (code == "TIMEOUT") {
    cleanNotice = "App Not Responding";
    footerNote  = "Check Driver App";
  } else if (code == "NO_TIME_IN") {
    cleanNotice = "No Morning Time-In";
    footerNote  = "Cannot record shift";
  } else if (code == "ALREADY_TIMED_IN") {
    cleanNotice = "Already Timed-In";
    footerNote  = "Shift currently active";
  } else if (code == "DRIVER_NOT_ON_THE_WAY" || code == "WAITING_DRIVER") {
    cleanNotice = "Tap 'On The Way'";
    footerNote  = "Driver route inactive";
  } else if (code == "DEBOUNCED") {
    cleanNotice = "Please Wait A Moment";
    footerNote  = "Card recently scanned";
  } else if (code == "ALREADY_COMPLETED") {
    cleanNotice = "Shift Already Ended";
    footerNote  = "Attendance complete";
  } else if (code == "UNREGISTERED" || code == "UNKNOWN_CARD") {
    cleanNotice = "Unregistered Card";
    footerNote  = "Register in Admin Web";
  } else if (code == "WRONG_COOK" || code == "WRONG_BRANCH") {
    cleanNotice = "Wrong Branch Cook";
    footerNote  = "Not assigned here";
  } else if (code == "WRONG_LOCATION") {
    cleanNotice = "Wrong Branch Cook";
    footerNote  = "Not assigned here";
  } else if (code == "SERVER_ERR" || code == "CONN_ERR") {
    cleanNotice = "Server Unavailable";
    footerNote  = "Saved to offline queue";
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
  Serial.println(" BRAHMS SISIG & BAGNET — DRIVER BLUETOOTH UNIT");
  Serial.print(" Bluetooth Name: "); Serial.println(BT_DEVICE_NAME);
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
    centerPrint("Starting Bluetooth...", 44, 1);
    display.display();
  }

  // RC522 Pin Initialization
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
  delay(100);

  // Start Bluetooth Serial
  SerialBT.begin(BT_DEVICE_NAME);
  Serial.println("[BLUETOOTH] Bluetooth Serial started! Ready to pair with Driver App.");

  playSuccessChime();
  showReadyScreen();
  Serial.println("\n[READY] Driver Bluetooth Reader is ready for taps...");
}

bool processTapViaBluetooth(String uid);

// =====================================================================================
// 8. MAIN LOOP
// =====================================================================================
void loop() {
  static unsigned long lastStatusCheck = 0;
  static bool lastClientState = false;

  bool currentClientState = SerialBT.hasClient();
  if (millis() - lastStatusCheck > 2000 || currentClientState != lastClientState) {
    lastStatusCheck = millis();
    lastClientState = currentClientState;
    showReadyScreen();
  }

  // Detect card
  if (!mfrc522.PICC_IsNewCardPresent()) {
    delay(40);
    return;
  }

  // Select card
  if (!mfrc522.PICC_ReadCardSerial()) {
    delay(40);
    return;
  }

  // Extract Clean Hex UID
  String cardUid = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    if (mfrc522.uid.uidByte[i] < 0x10) cardUid += "0";
    cardUid += String(mfrc522.uid.uidByte[i], HEX);
    if (i < mfrc522.uid.size - 1) cardUid += ":";
  }
  cardUid.toUpperCase();

  // Debounce check — 3 segundo
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
  Serial.print("[DRIVER RFID DETECTED] UID: ");
  Serial.println(cardUid);

  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();

  playChirp(); 
  showProcessingScreen();

  // Send tap to phone app via Bluetooth
  processTapViaBluetooth(cardUid);

  delay(1800);
  showReadyScreen();
}

// =====================================================================================
// 9. BLUETOOTH TRANSMISSION & RESPONSE HANDLER
// =====================================================================================
bool processTapViaBluetooth(String uid) {
  // 1. Suriin kung nakakonekta ang cellphone ni driver
  if (!SerialBT.hasClient()) {
    Serial.println("[ERROR] Driver App not connected via Bluetooth!");
    showErrorScreen("NO_APP");
    playErrorTone();
    recoverRC522();
    return false;
  }

  // 1b. FLUSH SERIAL BUFFER: Linisin ang mga lumang tira-tirang bytes bago magpadala ng bagong tap
  while (SerialBT.available()) {
    SerialBT.read();
  }

  // 2. Ipadala ang Card Tap sa Driver App sa format na JSON
  StaticJsonDocument<128> sendDoc;
  sendDoc["event"]     = "rfid_tap";
  sendDoc["uid"]       = uid;
  sendDoc["device_id"] = "esp32_driver_portable";

  String outgoingMessage;
  serializeJson(sendDoc, outgoingMessage);
  outgoingMessage += "\n";

  Serial.print("[BT SEND] ");
  Serial.println(outgoingMessage);
  SerialBT.print(outgoingMessage);

  // 3. Hintayin ang tugon ng Driver App (Timeout: 5 segundo para hindi magka-false timeout sa offline mode)
  unsigned long sendTime = millis();
  String responseLine = "";
  bool gotResponse = false;

  while (millis() - sendTime < 5000) {
    if (SerialBT.available()) {
      char c = (char)SerialBT.read();
      if (c == '\n' || c == '\r') {
        if (responseLine.length() > 0) {
          gotResponse = true;
          break;
        }
      } else {
        responseLine += c;
      }
    }
    delay(5);
  }

  // 4. Kung nag-timeout at hindi sumagot ang phone
  if (!gotResponse) {
    Serial.println("[ERROR] Driver App response timed out!");
    showErrorScreen("TIMEOUT");
    playErrorTone();
    recoverRC522();
    return false;
  }

  responseLine.trim();
  Serial.print("[BT RECV] ");
  Serial.println(responseLine);

  // 5. I-parse ang tugon mula sa Driver App gamit ang 512-byte doc para ligtas sa mahahabang pangalan
  StaticJsonDocument<512> resDoc;
  DeserializationError parseErr = deserializeJson(resDoc, responseLine);

  if (parseErr) {
    Serial.println("[ERROR] Failed to parse Driver App response.");
    showErrorScreen("PARSE_ERR");
    playErrorTone();
    recoverRC522();
    return false;
  }

  String status    = resDoc["status"]    | "";
  String type      = resDoc["type"]      | "";
  String staffName = resDoc["name"]      | "Staff";
  String code      = resDoc["code"]      | "";
  String message   = resDoc["message"]   | "";
  bool isOffline   = resDoc["offline"]   | false;

  // SUCCESS: Online o Offline Saved
  if (status == "success" || status == "offline_saved") {
    Serial.print("[SUCCESS] ");
    Serial.print(staffName);
    Serial.print(" -> ");
    Serial.println(type);
    showSuccessScreen(staffName, type, isOffline);
    playSuccessChime();
    recoverRC522();
    return true;
  }
  // UNREGISTERED CARD: Ipakita ang UID sa OLED
  else if (code == "UNREGISTERED" || code == "UNKNOWN_CARD") {
    Serial.print("[NOTICE] Unregistered Card: ");
    Serial.println(uid);
    showUnregisteredCardScreen(uid);
    playErrorTone();
    recoverRC522();
    return false;
  }
  // REJECTED / NOTICE
  else {
    Serial.print("[NOTICE] ");
    if (message.length() > 0) {
      Serial.println(message);
    } else {
      Serial.println(code);
    }
    showErrorScreen(code);
    playErrorTone();
    recoverRC522();
    return false;
  }
}
