@echo off
chcp 65001 >nul
echo ========================================
echo 防衛省ロジスティクスシステム 停止スクリプト
echo ========================================
echo.

echo [1/3] システムバックアップ作成中...
docker exec -i postgres_procedures psql -U postgres -d defense_logistics -c "SELECT create_system_backup();"
if %errorlevel% neq 0 (
    echo 警告: システムバックアップの作成に失敗しました。
) else (
    echo ✓ システムバックアップ作成完了
)
echo.

echo [2/3] システムメンテナンス実行中...
docker exec -i postgres_procedures psql -U postgres -d defense_logistics -c "SELECT run_system_maintenance();"
if %errorlevel% neq 0 (
    echo 警告: システムメンテナンスの実行に失敗しました。
) else (
    echo ✓ システムメンテナンス完了
)
echo.

echo [3/3] Docker コンテナ停止中...
docker-compose down
if %errorlevel% neq 0 (
    echo エラー: Docker コンテナの停止に失敗しました。
    pause
    exit /b 1
)
echo ✓ Docker コンテナ停止完了
echo.

echo ========================================
echo 防衛省ロジスティクスシステムが正常に停止しました。
echo.
echo システム再起動:
echo start_system.bat
echo ========================================
echo.
pause 