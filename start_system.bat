@echo off
chcp 65001 >nul
echo ========================================
echo 防衛省ロジスティクスシステム 起動スクリプト
echo ========================================
echo.

echo [1/5] Docker コンテナ起動中...
docker-compose up -d
if %errorlevel% neq 0 (
    echo エラー: Docker コンテナの起動に失敗しました。
    pause
    exit /b 1
)
echo ✓ Docker コンテナ起動完了
echo.

echo [2/5] データベース接続確認中...
timeout /t 10 /nobreak >nul
docker exec postgres_procedures pg_isready -U postgres -d defense_logistics
if %errorlevel% neq 0 (
    echo エラー: データベース接続に失敗しました。
    pause
    exit /b 1
)
echo ✓ データベース接続確認完了
echo.

echo [3/5] システムヘルスチェック実行中...
docker exec -i postgres_procedures psql -U postgres -d defense_logistics -c "SELECT * FROM check_system_health();"
if %errorlevel% neq 0 (
    echo 警告: システムヘルスチェックで問題が検出されました。
) else (
    echo ✓ システムヘルスチェック完了
)
echo.

echo [4/5] システム統計確認中...
docker exec -i postgres_procedures psql -U postgres -d defense_logistics -c "
SELECT 
    'Total Users' as metric,
    COUNT(*) as value
FROM users
WHERE deleted = FALSE
UNION ALL
SELECT 
    'Total Materials',
    COUNT(*)
FROM logistics_materials
UNION ALL
SELECT 
    'Active Orders',
    COUNT(*)
FROM transport_orders
WHERE status IN ('PENDING', 'IN_TRANSIT')
UNION ALL
SELECT 
    'Active Incidents',
    COUNT(*)
FROM emergency_incidents
WHERE status = 'ACTIVE';"
echo ✓ システム統計確認完了
echo.

echo [5/5] システム起動完了
echo ========================================
echo 防衛省ロジスティクスシステムが正常に起動しました。
echo.
echo データベース接続情報:
echo - ホスト: localhost
echo - ポート: 5432
echo - データベース: defense_logistics
echo - ユーザー: postgres
echo - パスワード: postgres
echo.
echo 接続コマンド:
echo docker exec -it postgres_procedures psql -U postgres -d defense_logistics
echo.
echo システム停止:
echo docker-compose down
echo ========================================
echo.
pause 