"""
日志系统模块
"""
import logging
import sys
from datetime import datetime


class Logger:
    """日志管理类"""
    
    def __init__(self, name, level=logging.INFO):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(level)
        
        # 清除已有处理器
        self.logger.handlers.clear()
        
        # 创建控制台处理器
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(level)
        
        # 设置格式
        formatter = logging.Formatter(
            '%(asctime)s [%(name)s] %(levelname)s: %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(formatter)
        
        self.logger.addHandler(console_handler)
    
    def debug(self, msg):
        self.logger.debug(msg)
    
    def info(self, msg):
        self.logger.info(msg)
    
    def warning(self, msg):
        self.logger.warning(msg)
    
    def error(self, msg):
        self.logger.error(msg)
    
    def critical(self, msg):
        self.logger.critical(msg)


class LogBuffer:
    """日志缓冲区，用于GUI显示"""
    
    def __init__(self, max_lines=1000):
        self.max_lines = max_lines
        self.logs = []
        self.callbacks = []
    
    def add_callback(self, callback):
        """添加日志回调函数"""
        self.callbacks.append(callback)
    
    def remove_callback(self, callback):
        """移除日志回调函数"""
        if callback in self.callbacks:
            self.callbacks.remove(callback)
    
    def log(self, level, message):
        """记录日志"""
        timestamp = datetime.now().strftime('%H:%M:%S')
        log_entry = f"[{timestamp}] [{level}] {message}"
        
        self.logs.append(log_entry)
        
        # 限制日志行数
        if len(self.logs) > self.max_lines:
            self.logs = self.logs[-self.max_lines:]
        
        # 通知回调
        for callback in self.callbacks:
            try:
                callback(log_entry)
            except Exception:
                pass
    
    def get_logs(self, count=100):
        """获取最近N条日志"""
        return self.logs[-count:]
    
    def clear(self):
        """清空日志"""
        self.logs.clear()


# 全局日志缓冲区
_global_log_buffer = None


def get_log_buffer():
    """获取全局日志缓冲区"""
    global _global_log_buffer
    if _global_log_buffer is None:
        _global_log_buffer = LogBuffer()
    return _global_log_buffer
