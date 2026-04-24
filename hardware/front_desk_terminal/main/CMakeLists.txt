idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS "."
                    REQUIRES driver_rc522 card_mifare_payload service_mqtt hal_interactive service_network service_auth config_global esp_timer)
