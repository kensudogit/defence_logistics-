-- 防衛省ロジスティクス基盤テストスクリプト（エラー修正版）
-- Defense Logistics Infrastructure Test Script (Fixed Version)

-- 1. セキュリティレベル確認
SELECT level_id, level_name, clearance_required, description FROM security_levels ORDER BY level_id;

-- 2. 初期資材データ確認
SELECT 
    lm.material_code,
    lm.material_name,
    lm.category,
    lm.current_stock,
    lm.min_stock_level,
    lm.max_stock_level,
    sl.level_name as security_level
FROM logistics_materials lm
JOIN security_levels sl ON lm.security_level_id = sl.level_id
ORDER BY lm.material_code;

-- 3. セキュリティ強化ユーザー作成テスト
SELECT create_defense_user(
    'defense_admin',
    'admin@defense.gov.jp',
    '防衛省管理者',
    'ロジスティクス部',
    '極秘',
    '課長',
    '03-1234-5678',
    1
) as new_user_id;

-- 4. 資材管理テスト
-- 新規資材作成
SELECT manage_logistics_material(
    'CREATE',
    'MAT006',
    '通信衛星機器',
    '通信機器',
    'セット',
    10,
    2,
    20,
    '極秘',
    'LOC006',
    '通信衛星会社F',
    1
) as new_material_id;

-- 資材更新
SELECT manage_logistics_material(
    'UPDATE',
    'MAT001',
    '燃料（軽油）',
    '燃料',
    'リットル',
    12000,
    2000,
    15000,
    '一般',
    'LOC001',
    '燃料供給会社A（更新）',
    1
) as updated_material_id;

-- 5. 在庫監視テスト
SELECT * FROM monitor_inventory_levels();

-- 6. 輸送オーダー作成テスト
SELECT create_transportation_order(
    1, -- 最高優先度
    '東京基地',
    '横田基地',
    'MAT001',
    1000,
    CURRENT_DATE + INTERVAL '3 days',
    'TRUCK-001',
    '田中太郎',
    1
) as new_order_id;

-- 7. 緊急事態報告テスト
SELECT report_emergency_incident(
    '燃料漏洩',
    4, -- 重大度レベル4
    '東京基地 燃料タンクA',
    '燃料タンクから軽油が漏洩している。緊急対応が必要。',
    'MAT001: 燃料（軽油）',
    '緊急対応チームA',
    1
) as new_incident_id;

-- 8. セキュリティ監査レポート生成テスト
SELECT * FROM generate_security_audit_report(
    (CURRENT_DATE - INTERVAL '7 days')::DATE,
    CURRENT_DATE::DATE,
    '極秘'
);

-- 9. 輸送効率分析テスト
SELECT * FROM analyze_transportation_efficiency(
    (CURRENT_DATE - INTERVAL '30 days')::DATE,
    CURRENT_DATE::DATE
);

-- 10. システムヘルスチェックテスト
SELECT * FROM defense_system_health_check();

-- 11. セキュアデータエクスポートテスト
SELECT export_secure_data('logistics_materials', '一般', 1) as export_result;

-- 12. 追加の輸送オーダー作成（効率分析用）
-- 複数の輸送オーダーを作成
SELECT create_transportation_order(
    2,
    '横田基地',
    '佐世保基地',
    'MAT002',
    500,
    CURRENT_DATE + INTERVAL '5 days',
    'TRUCK-002',
    '佐藤次郎',
    1
);

SELECT create_transportation_order(
    3,
    '佐世保基地',
    '沖縄基地',
    'MAT003',
    5,
    CURRENT_DATE + INTERVAL '7 days',
    'TRUCK-003',
    '鈴木三郎',
    1
);

-- 13. 緊急事態の解決テスト
UPDATE emergency_incidents 
SET status = 'resolved', 
    resolved_at = CURRENT_TIMESTAMP,
    resolution_notes = '燃料漏洩を修復し、安全確認完了'
WHERE incident_type = '燃料漏洩';

-- 14. 輸送オーダー完了テスト（サブクエリ対応）
UPDATE transportation_orders 
SET status = 'completed',
    updated_at = CURRENT_TIMESTAMP
WHERE id IN (
    SELECT id FROM transportation_orders 
    WHERE order_number LIKE 'TO-%' AND status = 'pending' 
    LIMIT 1
);

-- 15. 最終システムヘルスチェック
SELECT * FROM defense_system_health_check();

-- 16. セキュリティ監査ログ確認
SELECT 
    action_type,
    table_name,
    security_level,
    timestamp
FROM security_audit_logs 
ORDER BY timestamp DESC 
LIMIT 10;

-- 17. 緊急事態一覧確認
SELECT 
    incident_code,
    incident_type,
    severity_level,
    location,
    status,
    reported_at
FROM emergency_incidents 
ORDER BY reported_at DESC;

-- 18. 輸送オーダー一覧確認（エイリアス名修正）
SELECT 
    t_order.order_number,
    t_order.priority_level,
    t_order.origin_location,
    t_order.destination_location,
    lm.material_name,
    t_order.quantity,
    t_order.status,
    t_order.required_date
FROM transportation_orders t_order
JOIN logistics_materials lm ON t_order.material_id = lm.material_id
ORDER BY t_order.created_at DESC;

-- 19. 自動メンテナンス実行テスト
SELECT auto_maintenance_defense_system();

-- 20. 最終確認
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
FROM security_audit_logs; 