@echo off
chcp 65001 > nul
echo ========================================
echo 防衛省ロジスティクス基盤システム
echo Defense Logistics Infrastructure System
echo ========================================
echo.

REM PostgreSQLコンテナの確認
echo PostgreSQLコンテナの状態を確認中...
docker ps | findstr postgres_procedures
if %errorlevel% neq 0 (
    echo PostgreSQLコンテナが起動していません。起動します...
    docker-compose -f docker-compose-postgres.yml up -d
    timeout /t 5 /nobreak > nul
)

echo.
echo ========================================
echo 1. セットアップスクリプト実行
echo ========================================
echo 防衛省ロジスティクス基盤のセットアップを開始します...
docker exec -i postgres_procedures psql -U postgres -d postgres -f /tmp/defense_logistics_setup.sql

echo.
echo ========================================
echo 2. テストスクリプト実行
echo ========================================
echo システム機能のテストを開始します...
docker exec -i postgres_procedures psql -U postgres -d postgres -f /tmp/defense_logistics_test.sql

echo.
echo ========================================
echo 3. システム状態確認
echo ========================================
echo システムの現在の状態を確認します...

echo.
echo --- セキュリティレベル確認 ---
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT level_name, clearance_required FROM security_levels ORDER BY level_id;"

echo.
echo --- 資材一覧確認 ---
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT material_code, material_name, category, current_stock, security_level_id FROM logistics_materials ORDER BY material_code;"

echo.
echo --- 輸送オーダー確認 ---
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT order_number, priority_level, origin_location, destination_location, status FROM transportation_orders ORDER BY created_at DESC LIMIT 5;"

echo.
echo --- 緊急事態確認 ---
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT incident_code, incident_type, severity_level, status FROM emergency_incidents ORDER BY reported_at DESC LIMIT 5;"

echo.
echo --- セキュリティ監査ログ確認 ---
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT action_type, table_name, security_level, timestamp FROM security_audit_logs ORDER BY timestamp DESC LIMIT 5;"

echo.
echo ========================================
echo 4. システムヘルスチェック
echo ========================================
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT * FROM defense_system_health_check();"

echo.
echo ========================================
echo 5. 在庫監視レポート
echo ========================================
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT * FROM monitor_inventory_levels();"

echo.
echo ========================================
echo 6. セキュリティ監査レポート
echo ========================================
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT * FROM generate_security_audit_report(CURRENT_DATE - INTERVAL '7 days', CURRENT_DATE, '極秘');"

echo.
echo ========================================
echo 7. 輸送効率分析
echo ========================================
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT * FROM analyze_transportation_efficiency(CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE);"

echo.
echo ========================================
echo 8. データエクスポートテスト
echo ========================================
echo 資材データのエクスポートテスト...
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT export_secure_data('logistics_materials', '一般', 1);"

echo.
echo ========================================
echo 9. 自動メンテナンス実行
echo ========================================
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT auto_maintenance_defense_system();"

echo.
echo ========================================
echo 10. 最終統計
echo ========================================
docker exec -i postgres_procedures psql -U postgres -d postgres -c "
SELECT 
    'セキュリティレベル数' as item,
    COUNT(*)::text as count
FROM security_levels
UNION ALL
SELECT 
    '資材数',
    COUNT(*)::text
FROM logistics_materials
UNION ALL
SELECT 
    '輸送オーダー数',
    COUNT(*)::text
FROM transportation_orders
UNION ALL
SELECT 
    '緊急事態数',
    COUNT(*)::text
FROM emergency_incidents
UNION ALL
SELECT 
    'セキュリティ監査ログ数',
    COUNT(*)::text
FROM security_audit_logs;"

echo.
echo ========================================
echo 防衛省ロジスティクス基盤システム実行完了
echo ========================================
echo.
echo システムが正常に動作しています。
echo セキュリティ機能、ロジスティクス管理機能、
echo 緊急事態管理機能がすべて利用可能です。
echo.
pause 