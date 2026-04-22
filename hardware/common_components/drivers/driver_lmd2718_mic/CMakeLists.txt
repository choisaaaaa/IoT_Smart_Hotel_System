idf_component_register(SRCS "driver_lmd2718_mic.c" "lmd02718_i2s.c"
                    INCLUDE_DIRS "include"
                    REQUIRES hal_log esp_driver_i2s)
