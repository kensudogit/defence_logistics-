-- デバッグ機能テストスクリプト
-- 防衛省ロジスティクスシステムのデバッグ機能をテスト

-- 1. デバッグログをクリア
SELECT clear_debug_log();

-- 2. デバッグ版ユーザー作成テスト
SELECT '=== デバッグ版ユーザー作成テスト ===' as test_name;

SELECT create_user_with_debug(
    'debug_user1',
    'debug1@defense.gov.jp',
    'デバッグユーザー1',
    'IT部門',
    2
);

-- 3. デバッグ版ロジスティクス材料作成テスト
SELECT '=== デバッグ版材料作成テスト ===' as test_name;

SELECT create_logistics_material_with_debug(
    'DEBUG-MAT-001',
    'デバッグテスト材料1',
    '電子機器',
    50,
    '個',
    2,
    '倉庫A-1F'
);

-- 4. デバッグ版輸送オーダー作成テスト
SELECT '=== デバッグ版輸送オーダー作成テスト ===' as test_name;

SELECT create_transport_order_with_debug(
    'DEBUG-ORDER-001',
    '東京基地',
    '横田基地',
    'HIGH',
    2,
    CURRENT_DATE + INTERVAL '7 days'
);

-- 5. デバッグ版緊急事態報告テスト
SELECT '=== デバッグ版緊急事態報告テスト ===' as test_name;

SELECT report_emergency_incident_with_debug(
    'システム障害',
    'データセンター',
    'MEDIUM',
    'デバッグテスト用の緊急事態報告',
    1,
    2
);

-- 6. デバッグ版在庫監視テスト
SELECT '=== デバッグ版在庫監視テスト ===' as test_name;

SELECT * FROM monitor_inventory_with_debug(100);

-- 7. デバッグ版セキュリティ監査レポートテスト
SELECT '=== デバッグ版セキュリティ監査レポートテスト ===' as test_name;

SELECT * FROM generate_security_audit_report_with_debug(
    CURRENT_DATE - INTERVAL '7 days',
    CURRENT_DATE
);

-- 8. デバッグログ表示テスト
SELECT '=== デバッグログ表示テスト ===' as test_name;

-- 全デバッグログを表示
SELECT * FROM show_debug_log(20);

-- 9. 特定プロシージャのデバッグログ表示テスト
SELECT '=== 特定プロシージャのデバッグログ表示テスト ===' as test_name;

SELECT * FROM show_procedure_debug_log('create_user_with_debug', 10);

-- 10. デバッグ統計取得テスト
SELECT '=== デバッグ統計取得テスト ===' as test_name;

SELECT * FROM get_debug_statistics();

-- 11. デバッグログCSVエクスポートテスト
SELECT '=== デバッグログCSVエクスポートテスト ===' as test_name;

SELECT export_debug_log_to_csv('debug_test_export.csv');

-- 12. エラーケースのデバッグテスト
SELECT '=== エラーケースのデバッグテスト ===' as test_name;

-- 無効なパラメータでユーザー作成（エラーを発生させる）
DO $$
BEGIN
    PERFORM create_user_with_debug(NULL, 'test@test.com', 'Test User', 'IT', 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '期待されるエラーが発生: %', SQLERRM;
END $$;

-- 13. デバッグログの詳細分析
SELECT '=== デバッグログ詳細分析 ===' as test_name;

-- プロシージャ別のログ数
SELECT 
    procedure_name,
    COUNT(*) as log_count,
    COUNT(CASE WHEN message LIKE '%ERROR%' THEN 1 END) as error_count,
    MIN(created_at) as first_log,
    MAX(created_at) as last_log
FROM debug_log
GROUP BY procedure_name
ORDER BY log_count DESC;

-- ステップ別のログ数
SELECT 
    step_name,
    COUNT(*) as step_count
FROM debug_log
WHERE step_name IS NOT NULL
GROUP BY step_name
ORDER BY step_count DESC;

-- 14. パフォーマンステスト（デバッグログ付き）
SELECT '=== パフォーマンステスト（デバッグログ付き） ===' as test_name;

-- 複数の材料を一括作成
DO $$
DECLARE
    i INTEGER;
    v_material_id INTEGER;
BEGIN
    FOR i IN 1..5 LOOP
        SELECT create_logistics_material_with_debug(
            'PERF-MAT-' || i::TEXT,
            'パフォーマンステスト材料' || i::TEXT,
            'テストカテゴリ',
            100 + i,
            '個',
            1,
            'テスト倉庫'
        ) INTO v_material_id;
        
        RAISE NOTICE '材料作成完了: ID = %', v_material_id;
    END LOOP;
END $$;

-- 15. 最終デバッグ統計
SELECT '=== 最終デバッグ統計 ===' as test_name;

SELECT * FROM get_debug_statistics();

-- 16. デバッグログのクリーンアップ確認
SELECT '=== デバッグログクリーンアップ確認 ===' as test_name;

-- 現在のログ数を確認
SELECT COUNT(*) as current_log_count FROM debug_log;

-- クリーンアップ実行
SELECT clear_debug_log();

-- クリーンアップ後のログ数を確認
SELECT COUNT(*) as after_cleanup_log_count FROM debug_log;

SELECT '=== デバッグ機能テスト完了 ===' as test_completion; 