idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS "."
                    REQUIRES service_mqtt hal_sensors hal_actuators hal_interactive hal_canopy service_network config_global)
