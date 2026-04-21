idf_component_register(SRCS "hal_sensors.c"
                    INCLUDE_DIRS "include"
                    REQUIRES driver_dht11 driver_mq2 driver_ldr driver_rd03_simple config_global)
