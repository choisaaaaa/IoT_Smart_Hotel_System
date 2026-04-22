idf_component_register(SRCS "hal_infrared.c"
                    INCLUDE_DIRS "include"
                    REQUIRES esp_timer freertos driver_ir_tx driver_ir_rx config_global)
