#include "esp_camera.h"
#include <WiFi.h>
#include <HTTPClient.h>

// Remplacez par vos identifiants Wi-Fi
const char* ssid = "Redmi";
const char* password = "21594884";

// Adresse du serveur Flask
const char* serverName = "http://192.168.222.213:5000/upload";

void setup() {
  Serial.begin(115200);
  Serial.println("Démarrage de l'ESP32-CAM");

  // Configuration de la caméra
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = 5;
  config.pin_d1 = 18;
  config.pin_d2 = 19;
  config.pin_d3 = 21;
  config.pin_d4 = 36;
  config.pin_d5 = 39;
  config.pin_d6 = 34;
  config.pin_d7 = 35;
  config.pin_xclk = 0;
  config.pin_pclk = 22;
  config.pin_vsync = 25;
  config.pin_href = 23;
  config.pin_sscb_sda = 26;
  config.pin_sscb_scl = 27;
  config.pin_pwdn = 32;
  config.pin_reset = -1;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_SVGA; // 800x600 pour meilleure clarté
  config.jpeg_quality = 12; // Qualité légèrement réduite pour moins de charge
  config.fb_count = 2; // Double buffer pour fluidité

  // Initialisation de la caméra
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Erreur d'initialisation de la caméra : 0x%x", err);
    return;
  }
  Serial.println("Caméra initialisée");

  // Connexion au Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Connexion au Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("Wi-Fi connecté");
  Serial.print("Adresse IP : ");
  Serial.println(WiFi.localIP());
}

void loop() {
  // Capturer une image
  camera_fb_t * fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Échec de la capture d'image");
    return;
  }

  // Vérifier la connexion Wi-Fi
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverName);

    // Définir les en-têtes pour multipart/form-data
    String boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
    String contentType = "multipart/form-data; boundary=" + boundary;
    http.addHeader("Content-Type", contentType);

    // Construire le corps de la requête
    String bodyStart = "--" + boundary + "\r\nContent-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n";
    String bodyEnd = "\r\n--" + boundary + "--\r\n";

    // Envoyer la requête POST
    int httpResponseCode = http.POST(bodyStart + String((char*)fb->buf, fb->len) + bodyEnd);

    if (httpResponseCode > 0) {
      Serial.printf("Code de réponse HTTP : %d\n", httpResponseCode);
      String response = http.getString();
      Serial.println("Réponse : " + response);
    } else {
      Serial.printf("Erreur lors de l'envoi POST : %s\n", http.errorToString(httpResponseCode).c_str());
    }
    http.end();
  } else {
    Serial.println("Wi-Fi déconnecté");
  }

  // Libérer le buffer de l'image
  esp_camera_fb_return(fb);

  // Attendre 250ms avant la prochaine capture (environ 4 FPS)
  delay(250);
}