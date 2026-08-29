@echo off
rem 双击启动游戏本体(窗口模式,从第一关开始,日记桌翻页进下一关)
rem 注意:%~dp0 自带末尾反斜杠,放进引号参数会吞掉引号,故用 pushd 取无尾杠路径
pushd %~dp0
start "" "D:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" --path "%CD%" "res://src/MainGame.tscn"
popd
