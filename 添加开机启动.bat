@echo off
copy "D:\1Amy\sticky\启动雨然日历.bat" "C:\Users\%USERNAME%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\" > /dev/null
echo 已添加到开机启动
timeout /t 2 > /dev/null
