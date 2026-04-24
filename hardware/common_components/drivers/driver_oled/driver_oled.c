#include "driver_oled.h"
#include "driver_oled_font.h"
#include "global_config.h"
#include "hal_log.h"

#include <string.h>

#include "driver/i2c_master.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_panel_ssd1306.h"

static const char *TAG = "DRIVER_OLED";

#define OLED_W 128
#define OLED_H GLOBAL_OLED_HEIGHT
#define OLED_FB_BYTES (OLED_W * (OLED_H / 8))

static uint8_t s_fb[OLED_FB_BYTES];
static i2c_master_bus_handle_t s_i2c_bus;
static esp_lcd_panel_io_handle_t s_io;
static esp_lcd_panel_handle_t s_panel;
static bool s_ready;

static inline size_t fb_index(int x, int y)
{
    return (size_t)(y >> 3) * (size_t)OLED_W + (size_t)x;
}

static void fb_set_pixel(int x, int y, bool on)
{
    if (x < 0 || x >= OLED_W || y < 0 || y >= OLED_H) {
        return;
    }
    size_t i = fb_index(x, y);
    uint8_t mask = (uint8_t)(1u << (y & 7));
    if (on) {
        s_fb[i] |= mask;
    } else {
        s_fb[i] &= (uint8_t)~mask;
    }
}

static void draw_char_5x7(int x, int y, char ch)
{
    size_t uc = (unsigned char)ch;
    size_t base = uc * (size_t)DRIVER_OLED_FONT5_BYTES;
    for (int col = 0; col < 5; col++) {
        uint8_t bits = g_oled_font_5x7[base + (size_t)col];
        for (int row = 0; row < 7; row++, bits >>= 1) {
            if (bits & 1) {
                fb_set_pixel(x + col, y + row, true);
            }
        }
    }
}

static void clear_rect_px(int x0, int y0, int x1, int y1)
{
    for (int y = y0; y < y1 && y < OLED_H; y++) {
        for (int x = x0; x < x1 && x < OLED_W; x++) {
            fb_set_pixel(x, y, false);
        }
    }
}

static esp_err_t flush_fb(void)
{
    if (s_panel == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    return esp_lcd_panel_draw_bitmap(s_panel, 0, 0, OLED_W, OLED_H, s_fb);
}

esp_err_t driver_oled_init(void)
{
    if (s_ready) {
        return ESP_OK;
    }

    if (OLED_H != 32 && OLED_H != 64) {
        HAL_LOGE(TAG, "GLOBAL_OLED_HEIGHT must be 32 or 64");
        return ESP_ERR_NOT_SUPPORTED;
    }

    i2c_master_bus_config_t bus_cfg = {
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .i2c_port = (i2c_port_t)GLOBAL_OLED_I2C_PORT_NUM,
        .sda_io_num = GLOBAL_OLED_PIN_SDA,
        .scl_io_num = GLOBAL_OLED_PIN_SCL,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };
    esp_err_t err = i2c_new_master_bus(&bus_cfg, &s_i2c_bus);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "i2c_new_master_bus failed: %s", esp_err_to_name(err));
        return err;
    }

    esp_lcd_panel_io_i2c_config_t io_cfg = {
        .dev_addr = GLOBAL_OLED_I2C_ADDR,
        .scl_speed_hz = 400 * 1000,
        .control_phase_bytes = 1,
        .lcd_cmd_bits = 8,
        .lcd_param_bits = 8,
        .dc_bit_offset = 6,
    };
    err = esp_lcd_new_panel_io_i2c(s_i2c_bus, &io_cfg, &s_io);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "esp_lcd_new_panel_io_i2c failed: %s", esp_err_to_name(err));
        i2c_del_master_bus(s_i2c_bus);
        s_i2c_bus = NULL;
        return err;
    }

    esp_lcd_panel_dev_config_t panel_cfg = {
        .reset_gpio_num = GLOBAL_OLED_RST_GPIO,
        .bits_per_pixel = 1,
    };
    esp_lcd_panel_ssd1306_config_t ssd1306_cfg = {
        .height = OLED_H,
    };
    panel_cfg.vendor_config = &ssd1306_cfg;

    err = esp_lcd_new_panel_ssd1306(s_io, &panel_cfg, &s_panel);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "esp_lcd_new_panel_ssd1306 failed: %s", esp_err_to_name(err));
        esp_lcd_panel_io_del(s_io);
        s_io = NULL;
        i2c_del_master_bus(s_i2c_bus);
        s_i2c_bus = NULL;
        return err;
    }

    err = esp_lcd_panel_reset(s_panel);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "panel_reset failed: %s", esp_err_to_name(err));
        goto fail_panel;
    }
    err = esp_lcd_panel_init(s_panel);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "panel_init failed: %s", esp_err_to_name(err));
        goto fail_panel;
    }
    err = esp_lcd_panel_disp_on_off(s_panel, true);
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "disp_on_off failed: %s", esp_err_to_name(err));
        goto fail_panel;
    }

    memset(s_fb, 0, sizeof(s_fb));
    err = flush_fb();
    if (err != ESP_OK) {
        HAL_LOGE(TAG, "initial flush failed: %s", esp_err_to_name(err));
    }

    s_ready = true;
    HAL_LOGI(TAG, "SSD1306 %dx%d I2C addr 0x%02X SDA=%d SCL=%d",
             OLED_W, OLED_H, GLOBAL_OLED_I2C_ADDR, GLOBAL_OLED_PIN_SDA, GLOBAL_OLED_PIN_SCL);
    return ESP_OK;

fail_panel:
    esp_lcd_panel_del(s_panel);
    s_panel = NULL;
    esp_lcd_panel_io_del(s_io);
    s_io = NULL;
    i2c_del_master_bus(s_i2c_bus);
    s_i2c_bus = NULL;
    return err;
}

esp_err_t driver_oled_clear_screen(void)
{
    if (!s_ready) {
        return ESP_ERR_INVALID_STATE;
    }
    memset(s_fb, 0, sizeof(s_fb));
    return flush_fb();
}

static void draw_text_line_fb(uint8_t line, const char *text)
{
    if (line > 3) {
        line = 3;
    }

    const int row_h = 16;
    int y0 = (int)line * row_h;
    clear_rect_px(0, y0, OLED_W, y0 + row_h);

    int pen_y = y0 + 4;
    int pen_x = 0;
    for (const char *p = text; *p != '\0' && pen_x + 6 <= OLED_W; p++) {
        unsigned char c = (unsigned char)*p;
        if (c < 32 || c > 126) {
            c = (unsigned char)'.';
        }
        draw_char_5x7(pen_x, pen_y, (char)c);
        pen_x += 6;
    }
}

esp_err_t driver_oled_show_text_line(uint8_t line, const char *text)
{
    if (!s_ready) {
        return ESP_ERR_INVALID_STATE;
    }
    if (text == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    draw_text_line_fb(line, text);
    return flush_fb();
}

esp_err_t driver_oled_show_4_lines(const char *l0, const char *l1, const char *l2, const char *l3)
{
    if (!s_ready) {
        return ESP_ERR_INVALID_STATE;
    }
    if (l0 != NULL) draw_text_line_fb(0, l0);
    if (l1 != NULL) draw_text_line_fb(1, l1);
    if (l2 != NULL) draw_text_line_fb(2, l2);
    if (l3 != NULL) draw_text_line_fb(3, l3);
    return flush_fb();
}
