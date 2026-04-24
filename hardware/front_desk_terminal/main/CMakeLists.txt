idf_component_register(SRCS "main.c" "voice_session.c"
                    INCLUDE_DIRS "."
                    REQUIRES driver_rc522 driver_ec11 driver_oled card_mifare_payload service_mqtt hal_actuators hal_interactive hal_audio service_network service_auth config_global esp_timer)
