idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS "."
                    REQUIRES driver_rc522 service_mqtt hal_interactive service_network config_global esp_timer)
