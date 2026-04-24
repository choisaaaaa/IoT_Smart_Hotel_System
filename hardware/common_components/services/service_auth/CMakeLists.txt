idf_component_register(SRCS "service_auth.c"
                    INCLUDE_DIRS "include"
                    REQUIRES espressif__cjson esp_http_client nvs_flash mbedtls)
