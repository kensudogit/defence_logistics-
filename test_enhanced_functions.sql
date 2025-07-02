-- 実用性向上機能テストスクリプト
-- 防衛省ロジスティクスシステムの実用機能をテスト

-- 1. 在庫アラート機能テスト
SELECT '=== 在庫アラート機能テスト ===' as test_name;

-- 低在庫材料を作成
SELECT create_logistics_material_with_debug(
    'ALERT-MAT-001',
    'アラートテスト材料1',
    'テストカテゴリ',
    5,  -- 低在庫
    '個',
    1,
    'テスト倉庫'
);

-- アラート作成
SELECT create_inventory_alert(
    1,  -- material_id
    'LOW_STOCK',
    '材料「アラートテスト材料1」の在庫が不足しています。現在在庫: 5 個',
    'HIGH'
);

-- 2. 自動在庫監視テスト
SELECT '=== 自動在庫監視テスト ===' as test_name;

SELECT auto_monitor_inventory();

-- 3. 輸送オーダー追跡機能テスト
SELECT '=== 輸送オーダー追跡機能テスト ===' as test_name;

-- 輸送オーダーを作成
SELECT create_transport_order_with_debug(
    'TRACK-ORDER-001',
    '東京基地',
    '横田基地',
    'HIGH',
    2,
    CURRENT_DATE + INTERVAL '7 days'
);

-- ステータス更新
SELECT update_transport_status(1, 'IN_TRANSIT', '東京基地', '輸送開始');

-- 4. 緊急事態エスカレーション機能テスト
SELECT '=== 緊急事態エスカレーション機能テスト ===' as test_name;

-- 緊急事態を作成
SELECT * FROM report_emergency_incident_with_debug(
    'システム障害',
    'データセンター',
    'MEDIUM',
    'エスカレーションテスト用の緊急事態報告',
    1,
    2
);

-- エスカレーション実行
SELECT escalate_emergency_incident(1, 2);

-- 5. セキュリティアクセス制御テスト
SELECT '=== セキュリティアクセス制御テスト ===' as test_name;

-- アクセス権限チェック
SELECT check_security_access(1, 2, 'VIEW_SENSITIVE_DATA');

-- 6. システムバックアップ機能テスト
SELECT '=== システムバックアップ機能テスト ===' as test_name;

SELECT create_system_backup();

-- 7. パフォーマンス監視機能テスト
SELECT '=== パフォーマンス監視機能テスト ===' as test_name;

SELECT * FROM monitor_system_performance();

-- 8. 日次レポート生成機能テスト
SELECT '=== 日次レポート生成機能テスト ===' as test_name;

SELECT * FROM generate_daily_report();

-- 9. システムヘルスチェック機能テスト
SELECT '=== システムヘルスチェック機能テスト ===' as test_name;

SELECT * FROM check_system_health();

-- 10. 自動メンテナンス機能テスト
SELECT '=== 自動メンテナンス機能テスト ===' as test_name;

SELECT run_system_maintenance();

-- 11. 作成されたテーブルの確認
SELECT '=== 作成されたテーブル確認 ===' as test_name;

SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('inventory_alerts', 'transport_tracking', 'emergency_escalations', 'access_log', 'system_backups', 'daily_reports')
ORDER BY table_name;

-- 12. アラート状況確認
SELECT '=== アラート状況確認 ===' as test_name;

SELECT 
    ia.id,
    lm.material_name,
    ia.alert_type,
    ia.priority,
    ia.status,
    ia.created_at
FROM inventory_alerts ia
JOIN logistics_materials lm ON ia.material_id = lm.id
ORDER BY ia.created_at DESC;

-- 13. 輸送追跡状況確認
SELECT '=== 輸送追跡状況確認 ===' as test_name;

SELECT 
    tt.id,
    to2.order_number,
    tt.status,
    tt.location,
    tt.notes,
    tt.created_at
FROM transport_tracking tt
JOIN transport_orders to2 ON tt.order_id = to2.id
ORDER BY tt.created_at DESC;

-- 14. アクセスログ確認
SELECT '=== アクセスログ確認 ===' as test_name;

SELECT 
    al.id,
    u.username,
    al.action,
    al.required_level,
    al.user_level,
    al.access_granted,
    al.created_at
FROM access_log al
LEFT JOIN users u ON al.user_id = u.id
ORDER BY al.created_at DESC;

-- 15. 最終統計確認
SELECT '=== 最終統計確認 ===' as test_name;

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
WHERE status = 'ACTIVE'
UNION ALL
SELECT 
    'Active Alerts',
    COUNT(*)
FROM inventory_alerts
WHERE status = 'ACTIVE';

SELECT '=== 実用機能テスト完了 ===' as test_completion; 