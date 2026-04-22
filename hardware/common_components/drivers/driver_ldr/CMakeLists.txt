idf_component_register(SRCS "driver_ldr.c"
                    INCLUDE_DIRS "include"
                    REQUIRES esp_adc hal_log driver_adc_shared)
