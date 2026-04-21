idf_component_register(SRCS "driver_rc522.c"
                    INCLUDE_DIRS "include"
                    REQUIRES freertos config_global esp_driver_spi)
