idf_component_register(SRCS "hal_interactive.c"
                    INCLUDE_DIRS "include"
                    REQUIRES esp_driver_gpio freertos config_global driver_buzzer_active driver_rgb_led)
