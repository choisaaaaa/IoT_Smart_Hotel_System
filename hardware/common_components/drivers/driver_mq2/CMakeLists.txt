idf_component_register(SRCS "driver_mq2.c"
                    INCLUDE_DIRS "include"
                    REQUIRES esp_adc esp_driver_gpio hal_log driver_adc_shared)
