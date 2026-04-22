idf_component_register(SRCS "hal_canopy.c"
                    INCLUDE_DIRS "include"
                    REQUIRES driver_sg90 esp_driver_gpio config_global freertos)
