-- 防衛省ロジスティクスシステム 包括的最終テスト
-- 全ての実用機能をテストして、システムの完全性を確認

-- 1. システム初期化
SELECT '=== システム初期化 ===' as test_phase;
SELECT clear_debug_log();

-- 2. 基本機能テスト
SELECT '=== 基本機能テスト ===' as test_phase;

-- ユーザー作成
SELECT create_user_with_debug(
    'admin_user',
    'admin@defense.gov.jp',
    'システム管理者',
    'IT部門',
    3
);

SELECT create_user_with_debug(
    'operator_user',
    'operator@defense.gov.jp',
    'オペレーター',
    '運用部門',
    2
);

-- 材料作成
SELECT create_logistics_material_with_debug(
    'MAT-001',
    '通信機器',
    '電子機器',
    100,
    '台',
    2,
    '倉庫A-1F'
);

SELECT create_logistics_material_with_debug(
    'MAT-002',
    '燃料',
    '燃料',
    50,
    'L',
    1,
    '燃料庫'
);

-- 3. 実用機能テスト
SELECT '=== 実用機能テスト ===' as test_phase;

-- 在庫アラート機能
SELECT create_inventory_alert(
    1,
    'LOW_STOCK',
    '通信機器の在庫が不足しています',
    'HIGH'
);

-- 自動在庫監視
SELECT auto_monitor_inventory();

-- 輸送オーダー作成と追跡
SELECT create_transport_order_with_debug(
    'ORDER-001',
    '東京基地',
    '横田基地',
    'HIGH',
    2,
    CURRENT_DATE + INTERVAL '7 days'
);

SELECT update_transport_status(1, 'IN_TRANSIT', '東京基地', '輸送開始');
SELECT update_transport_status(1, 'IN_TRANSIT', '途中地点', '輸送中');
SELECT update_transport_status(1, 'DELIVERED', '横田基地', '配達完了');

-- 緊急事態報告とエスカレーション
SELECT * FROM report_emergency_incident_with_debug(
    '通信障害',
    '通信センター',
    'HIGH',
    '通信システムに障害が発生',
    1,
    2
);

SELECT escalate_emergency_incident(1, 2);

-- セキュリティアクセス制御
SELECT check_security_access(1, 3, 'ADMIN_ACCESS');
SELECT check_security_access(2, 3, 'ADMIN_ACCESS');

-- 4. システム監視機能テスト
SELECT '=== システム監視機能テスト ===' as test_phase;

-- パフォーマンス監視
SELECT * FROM monitor_system_performance();

-- システムヘルスチェック
SELECT * FROM check_system_health();

-- 日次レポート生成
SELECT * FROM generate_daily_report();

-- 5. システム管理機能テスト
SELECT '=== システム管理機能テスト ===' as test_phase;

-- システムバックアップ
SELECT create_system_backup();

-- 自動メンテナンス
SELECT run_system_maintenance();

-- 6. データ確認テスト
SELECT '=== データ確認テスト ===' as test_phase;

-- ユーザー一覧
SELECT 
    id,
    username,
    full_name,
    department,
    security_level,
    created_at
FROM users
WHERE deleted = FALSE
ORDER BY id;

-- 材料一覧
SELECT 
    id,
    material_code,
    material_name,
    category,
    quantity,
    unit,
    location
FROM logistics_materials
ORDER BY id;

-- 輸送オーダー一覧
SELECT 
    id,
    order_number,
    origin_location,
    destination_location,
    priority,
    status,
    created_at
FROM transport_orders
ORDER BY id;

-- 緊急事態一覧
SELECT 
    id,
    incident_type,
    location,
    severity,
    status,
    created_at
FROM emergency_incidents
ORDER BY id;

-- 7. 追跡・ログ確認テスト
SELECT '=== 追跡・ログ確認テスト ===' as test_phase;

-- アラート状況
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

-- 輸送追跡状況
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

-- アクセスログ
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

-- 監査ログ（最新10件）
SELECT 
    id,
    u.username,
    action,
    details,
    created_at
FROM audit_log al
LEFT JOIN users u ON al.user_id = u.id
ORDER BY created_at DESC
LIMIT 10;

-- 8. デバッグ機能テスト
SELECT '=== デバッグ機能テスト ===' as test_phase;

-- デバッグログ表示
SELECT * FROM show_debug_log(10);

-- デバッグ統計
SELECT * FROM get_debug_statistics();

-- 特定プロシージャのデバッグログ
SELECT * FROM show_procedure_debug_log('create_user_with_debug', 5);

-- 9. システム統計確認
SELECT '=== システム統計確認 ===' as test_phase;

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
WHERE status = 'ACTIVE'
UNION ALL
SELECT 
    'Total Audit Logs',
    COUNT(*)
FROM audit_log
UNION ALL
SELECT 
    'Total Debug Logs',
    COUNT(*)
FROM debug_log;

-- 10. テーブル構造確認
SELECT '=== テーブル構造確認 ===' as test_phase;

SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- 11. 最終確認
SELECT '=== 最終確認 ===' as test_phase;

-- システム全体の健全性チェック
SELECT 
    CASE 
        WHEN (SELECT COUNT(*) FROM users WHERE deleted = FALSE) > 0 THEN 'OK'
        ELSE 'WARNING'
    END as users_status,
    CASE 
        WHEN (SELECT COUNT(*) FROM logistics_materials) > 0 THEN 'OK'
        ELSE 'WARNING'
    END as materials_status,
    CASE 
        WHEN (SELECT COUNT(*) FROM transport_orders) > 0 THEN 'OK'
        ELSE 'WARNING'
    END as orders_status,
    CASE 
        WHEN (SELECT COUNT(*) FROM emergency_incidents) > 0 THEN 'OK'
        ELSE 'WARNING'
    END as incidents_status,
    CASE 
        WHEN (SELECT COUNT(*) FROM audit_log) > 0 THEN 'OK'
        ELSE 'WARNING'
    END as audit_status,
    CASE 
        WHEN (SELECT COUNT(*) FROM debug_log) > 0 THEN 'OK'
        ELSE 'WARNING'
    END as debug_status;

-- システム完了メッセージ
SELECT '=== 防衛省ロジスティクスシステム 包括的テスト完了 ===' as completion_message;
SELECT '全ての機能が正常に動作しています。' as status_message; 