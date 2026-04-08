idf_component_register(SRCS "driver_rgb_led.c"
                    INCLUDE_DIRS "include"
                    REQUIRES esp_driver_ledc hal_log)
