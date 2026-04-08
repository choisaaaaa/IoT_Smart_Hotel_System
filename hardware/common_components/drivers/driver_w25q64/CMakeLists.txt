idf_component_register(SRCS "driver_w25q64.c"
                    INCLUDE_DIRS "include"
                    REQUIRES esp_driver_spi freertos hal_log)
