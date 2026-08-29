@echo off
rem 双击启动地图编辑器(窗口模式)
rem 注意:%~dp0 自带末尾反斜杠,放进引号参数会吞掉引号,故用 pushd 取无尾杠路径
pushd %~dp0
start "" "D:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" --path "%CD%" "res://src/editor/MapEditor.tscn"
popd
