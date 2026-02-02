@echo off
chcp 65001 >nul
echo ========================================
echo 自动提交并推送到GitHub
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] 检查Git状态...
git status

echo.
echo [2/3] 添加所有修改的文件...
git add .

echo.
echo [3/3] 提交并推送...
set /p commit_msg="请输入提交信息（直接回车使用默认）: "
if "%commit_msg%"=="" set commit_msg=Auto commit: %date% %time%

git commit -m "%commit_msg%"
if %errorlevel% neq 0 (
    echo 警告: 没有需要提交的更改，或提交失败
    pause
    exit /b 1
)

git push origin main
if %errorlevel% neq 0 (
    echo 错误: 推送失败，请检查网络连接和GitHub权限
    pause
    exit /b 1
)

echo.
echo ========================================
echo 成功！代码已推送到GitHub
echo ========================================
echo.
echo 下一步：在服务器上执行以下命令更新插件：
echo   cd /var/discourse
echo   cd plugins/discourse-custom-plugin
echo   git pull origin main
echo   cd /var/discourse
echo   ./launcher rebuild app
echo.
pause
