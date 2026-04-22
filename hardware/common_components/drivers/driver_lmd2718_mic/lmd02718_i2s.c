#include "lmd02718_i2s.h"
#include "esp_log.h"
#include "driver/i2s_std.h"
#include "driver/i2s_pdm.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "LMD02718_I2S";

/* MIC：I2S1 + PDM RX；SPK：I2S0 + STD TX。两者完全独立，各用各的 GPIO。 */
static i2s_chan_handle_t s_rx;
static i2s_chan_handle_t s_tx;
static bool s_rx_inited;
static bool s_tx_inited;

static int map_i2s_port_id(int p)
{
    return (p == 0) ? I2S_NUM_0 : I2S_NUM_1;
}

esp_err_t lmd02718_i2s_init_pdm_rx(int i2s_port, int pin_pdm_clk, int pin_pdm_din, uint32_t sample_rate_hz)
{
    if (s_rx_inited) {
        return ESP_OK;
    }
    if (pin_pdm_clk < 0 || pin_pdm_din < 0 || sample_rate_hz == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    int port_id = map_i2s_port_id(i2s_port);
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(port_id, I2S_ROLE_MASTER);
    esp_err_t err = i2s_new_channel(&chan_cfg, NULL, &s_rx);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s_new_channel PDM RX failed: %s", esp_err_to_name(err));
        return err;
    }

    /* LMD2718T 是 PDM MEMS：单比特脉冲密度输出，IDF PDM RX 驱动内部做 CIC 抽取，
     * 直接给我们 16-bit 线性 PCM。MONO 模式只在 CLK 的一个相位采样。 */
    i2s_pdm_rx_config_t pdm_cfg = {
        .clk_cfg = I2S_PDM_RX_CLK_DEFAULT_CONFIG(sample_rate_hz),
        .slot_cfg = I2S_PDM_RX_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .clk = (gpio_num_t)pin_pdm_clk,
            .din = (gpio_num_t)pin_pdm_din,
            .invert_flags = {
                .clk_inv = false,
            },
        },
    };
    err = i2s_channel_init_pdm_rx_mode(s_rx, &pdm_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s_channel_init_pdm_rx_mode: %s", esp_err_to_name(err));
        return err;
    }

    err = i2s_channel_enable(s_rx);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s_channel_enable RX: %s", esp_err_to_name(err));
        return err;
    }

    s_rx_inited = true;
    ESP_LOGI(TAG, "I2S PDM RX ok port=%d clk=%d din=%d fs=%luHz (PDM CLK≈fs*64)",
             port_id, pin_pdm_clk, pin_pdm_din, (unsigned long)sample_rate_hz);
    return ESP_OK;
}

esp_err_t lmd02718_i2s_init_tx(int i2s_port, int pin_bclk, int pin_ws, int pin_dout, uint32_t sample_rate_hz)
{
    if (s_tx_inited) {
        return ESP_OK;
    }
    if (pin_bclk < 0 || pin_ws < 0 || pin_dout < 0 || sample_rate_hz == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    int port_id = map_i2s_port_id(i2s_port);
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(port_id, I2S_ROLE_MASTER);
    chan_cfg.auto_clear = true; /* 发送结束后 DMA 描述符自动清零，避免欠载时重播尾音 */
    esp_err_t err = i2s_new_channel(&chan_cfg, &s_tx, NULL);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s_new_channel TX failed: %s", esp_err_to_name(err));
        return err;
    }

    /* NS4168 是 I2S 串行数字输入 D 类功放，支持 16/24/32-bit。
     * 这里用 16-bit mono slot（I2S 标准 Philips 帧，BCLK = fs × 16 × 2 = fs×32）即可，
     * 波特率最低、兼容性最好。样本直接以 int16 写入，无需拓宽。 */
    i2s_std_config_t std_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(sample_rate_hz),
        .slot_cfg = I2S_STD_PHILIP_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = (gpio_num_t)pin_bclk,
            .ws = (gpio_num_t)pin_ws,
            .dout = (gpio_num_t)pin_dout,
            .din = I2S_GPIO_UNUSED,
            .invert_flags = {
                .mclk_inv = false,
                .bclk_inv = false,
                .ws_inv = false,
            },
        },
    };
    err = i2s_channel_init_std_mode(s_tx, &std_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s_channel_init_std_mode TX: %s", esp_err_to_name(err));
        return err;
    }
    err = i2s_channel_enable(s_tx);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s_channel_enable TX: %s", esp_err_to_name(err));
        return err;
    }

    s_tx_inited = true;
    ESP_LOGI(TAG, "I2S STD TX ok port=%d bclk=%d ws=%d dout=%d fs=%luHz",
             port_id, pin_bclk, pin_ws, pin_dout, (unsigned long)sample_rate_hz);
    return ESP_OK;
}

esp_err_t lmd02718_i2s_read(int16_t *samples, size_t max_samples, size_t *out_read_samples)
{
    if (!s_rx_inited || samples == NULL || out_read_samples == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    const size_t want_bytes = max_samples * sizeof(int16_t);
    size_t bytes_read = 0;
    esp_err_t err = i2s_channel_read(s_rx, samples, want_bytes, &bytes_read, pdMS_TO_TICKS(120));
    if (err != ESP_OK) {
        *out_read_samples = 0;
        return err;
    }
    *out_read_samples = bytes_read / sizeof(int16_t);

    /* 诊断：每 ~1s 打一次前 4 个 s16 样本 + peak/avg，便于判断 PDM 抽取是否正常工作 */
    static TickType_t s_last_log = 0;
    TickType_t now = xTaskGetTickCount();
    if (*out_read_samples >= 4 && (now - s_last_log) >= pdMS_TO_TICKS(1000)) {
        s_last_log = now;
        int32_t peak = 0;
        int64_t sum_abs = 0;
        for (size_t i = 0; i < *out_read_samples; i++) {
            int32_t a = samples[i] < 0 ? -samples[i] : samples[i];
            if (a > peak) peak = a;
            sum_abs += a;
        }
        uint32_t avg = (uint32_t)(sum_abs / (int64_t)*out_read_samples);
        ESP_LOGI(TAG, "PDM s16[0..3]=%d %d %d %d peak=%ld avg=%lu n=%u",
                 (int)samples[0], (int)samples[1], (int)samples[2], (int)samples[3],
                 (long)peak, (unsigned long)avg, (unsigned)*out_read_samples);
    }
    return ESP_OK;
}

esp_err_t lmd02718_i2s_write(const int16_t *samples, size_t sample_count)
{
    if (!s_tx_inited || samples == NULL || sample_count == 0) {
        return ESP_ERR_INVALID_STATE;
    }
    /* 16-bit mono slot 下可直接写 int16 数组；DMA 会自动串行化到 BCLK/WS 上。 */
    const size_t want_bytes = sample_count * sizeof(int16_t);
    size_t bytes_written = 0;
    esp_err_t err = i2s_channel_write(s_tx, samples, want_bytes, &bytes_written,
                                       pdMS_TO_TICKS(200));
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "i2s_channel_write TX: %s", esp_err_to_name(err));
        return err;
    }
    return ESP_OK;
}
