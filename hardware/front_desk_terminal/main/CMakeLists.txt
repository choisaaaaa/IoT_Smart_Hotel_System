set(PCM_WELCOME "${CMAKE_CURRENT_SOURCE_DIR}/welcome_card.pcm")
set(PCM_INVALID "${CMAKE_CURRENT_SOURCE_DIR}/invalid_card.pcm")

if(EXISTS "${PCM_WELCOME}" AND EXISTS "${PCM_INVALID}")
  idf_component_register(
    SRCS "main.c" "voice_session.c" "card_voice_playback.c"
    INCLUDE_DIRS "."
    REQUIRES driver_rc522 driver_ec11 driver_oled card_mifare_payload service_mqtt hal_actuators hal_interactive hal_audio service_network service_auth config_global esp_timer esp_http_client
    EMBED_FILES "welcome_card.pcm" "invalid_card.pcm"
  )
  target_compile_definitions(${COMPONENT_LIB} PRIVATE HAS_CARD_VOICE_PCM=1)
else()
  idf_component_register(
    SRCS "main.c" "voice_session.c" "card_voice_playback.c"
    INCLUDE_DIRS "."
    REQUIRES driver_rc522 driver_ec11 driver_oled card_mifare_payload service_mqtt hal_actuators hal_interactive hal_audio service_network service_auth config_global esp_timer esp_http_client
  )
endif()
