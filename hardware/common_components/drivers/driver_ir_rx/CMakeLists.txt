idf_component_register(SRCS "driver_ir_rx.c"
                    INCLUDE_DIRS "include"
                    REQUIRES esp_driver_gpio esp_timer hal_log)
