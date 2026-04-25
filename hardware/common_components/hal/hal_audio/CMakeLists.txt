idf_component_register(SRCS "hal_audio.c"
                    INCLUDE_DIRS "include"
                    REQUIRES driver_ns4168 driver_lmd2718_mic config_global freertos hal_interactive)
