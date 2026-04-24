idf_component_register(SRCS "voice_session.c" "main.c"
                    INCLUDE_DIRS "."
                    REQUIRES driver_rc522 card_mifare_payload driver_ec11 service_mqtt hal_actuators hal_sensors hal_interactive hal_audio hal_infrared driver_oled service_network service_auth config_global esp_wifi mbedtls)

# 需要更大缓冲可覆盖（默认 128，见 global_config.h），例如 256
# target_compile_definitions(${COMPONENT_LIB} PRIVATE GLOBAL_VOICE_PLAY_QUEUE_DEPTH=256)
