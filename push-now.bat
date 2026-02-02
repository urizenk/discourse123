@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ========================================
echo 正在提交并推送到GitHub...
echo ========================================
echo.

echo [1/4] 检查Git状态...
git status
echo.

echo [2/4] 添加所有修改...
git add .
echo.

echo [3/4] 提交修改...
git commit -m "Fix 500 error: Add nil checks and error handling for serializers and user extensions"
if %errorlevel% neq 0 (
    echo 警告: 提交失败或没有需要提交的更改
    pause
    exit /b 1
)
echo.

echo [4/4] 推送到GitHub...
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
pause
