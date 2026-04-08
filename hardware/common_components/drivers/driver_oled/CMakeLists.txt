idf_component_register(SRCS "driver_oled.c" "driver_oled_font.c"
                    INCLUDE_DIRS "include"
                    REQUIRES esp_driver_i2c esp_lcd hal_log config_global)
