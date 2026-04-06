idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS "."
                    REQUIRES driver_rc522 service_mqtt hal_actuators hal_sensors hal_interactive hal_audio hal_infrared driver_oled service_network config_global)
