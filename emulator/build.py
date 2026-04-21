"""
打包脚本 - 将三个仿真器打包为独立的exe文件
"""
import os
import sys
import subprocess
import shutil


def clean_build():
    """清理构建目录"""
    dirs_to_remove = ['build', 'dist']
    for dir_name in dirs_to_remove:
        if os.path.exists(dir_name):
            print(f"清理 {dir_name}...")
            shutil.rmtree(dir_name)
    
    # 清理spec文件
    for file in os.listdir('.'):
        if file.endswith('.spec'):
            os.remove(file)
            print(f"删除 {file}")


def build_executable(script_path, name, icon=None):
    """打包单个可执行文件"""
    print(f"\n{'='*50}")
    print(f"正在打包: {name}")
    print(f"{'='*50}")
    
    cmd = [
        'pyinstaller',
        '--onefile',           # 单文件
        '--windowed',          # 无控制台窗口
        '--name', name,        # 输出文件名
        '--add-data', f'common;common',  # 包含common模块
    ]
    
    if icon and os.path.exists(icon):
        cmd.extend(['--icon', icon])
    
    cmd.append(script_path)
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=False)
        print(f"✅ {name} 打包成功!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {name} 打包失败!")
        print(f"错误: {e}")
        return False


def main():
    """主函数"""
    print("智慧酒店硬件仿真器打包工具")
    print("=" * 50)
    
    # 检查pyinstaller
    try:
        import PyInstaller
        print("✅ PyInstaller已安装")
    except ImportError:
        print("❌ PyInstaller未安装，正在安装...")
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'pyinstaller'], check=True)
        print("✅ PyInstaller安装完成")
    
    # 清理旧构建
    clean_build()
    
    # 打包三个仿真器
    builds = [
        ('front_desk/main.py', '前台管理端仿真器'),
        ('floor_controller/main.py', '楼控节点仿真器'),
        ('room_terminal/main.py', '客房终端仿真器'),
    ]
    
    success_count = 0
    for script, name in builds:
        if os.path.exists(script):
            if build_executable(script, name):
                success_count += 1
        else:
            print(f"❌ 找不到文件: {script}")
    
    # 输出结果
    print(f"\n{'='*50}")
    print(f"打包完成: {success_count}/{len(builds)} 成功")
    print(f"{'='*50}")
    
    if success_count > 0:
        print("\n输出文件位置: dist/")
        if os.path.exists('dist'):
            for file in os.listdir('dist'):
                file_path = os.path.join('dist', file)
                size = os.path.getsize(file_path) / (1024 * 1024)  # MB
                print(f"  - {file} ({size:.2f} MB)")


if __name__ == '__main__':
    main()
