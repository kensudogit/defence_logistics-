-- 防衛省ロジスティクスシステム 最終問題修正
-- テストで発見された問題を修正

-- 1. 輸送オーダー作成関数の修正（デバッグ版）
CREATE OR REPLACE FUNCTION create_transport_order_with_debug(
    p_order_number VARCHAR(50),
    p_origin_location VARCHAR(100),
    p_destination_location VARCHAR(100),
    p_priority VARCHAR(20),
    p_security_level INTEGER,
    p_estimated_delivery_date DATE
) RETURNS INTEGER AS $$
DECLARE
    v_order_id INTEGER;
BEGIN
    -- デバッグログ開始
    PERFORM log_debug('create_transport_order_with_debug', 'START', '輸送オーダー作成プロシージャ開始');
    
    -- パラメータ確認
    PERFORM log_debug('create_transport_order_with_debug', 'PARAMS', 'パラメータ確認', 'order_number', p_order_number);
    PERFORM log_debug('create_transport_order_with_debug', 'PARAMS', 'パラメータ確認', 'priority', p_priority);
    PERFORM log_debug('create_transport_order_with_debug', 'PARAMS', 'パラメータ確認', 'security_level', p_security_level::TEXT);
    
    -- 入力値検証
    IF p_order_number IS NULL OR p_origin_location IS NULL OR p_destination_location IS NULL THEN
        RAISE EXCEPTION '必須パラメータが不足しています';
    END IF;
    
    PERFORM log_debug('create_transport_order_with_debug', 'VALIDATION', '入力値検証完了');
    
    -- 輸送オーダー作成
    INSERT INTO transport_orders (
        order_number,
        origin_location,
        destination_location,
        priority,
        security_level,
        estimated_delivery_date,
        status,
        created_at
    ) VALUES (
        p_order_number,
        p_origin_location,
        p_destination_location,
        p_priority,
        p_security_level,
        p_estimated_delivery_date,
        'PENDING',
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_order_id;
    
    PERFORM log_debug('create_transport_order_with_debug', 'INSERT', '輸送オーダー作成完了', 'order_id', v_order_id::TEXT);
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (1, 'CREATE_TRANSPORT_ORDER', 
            '輸送オーダー作成: ' || p_order_number || ' (' || p_origin_location || ' → ' || p_destination_location || ')',
            CURRENT_TIMESTAMP);
    
    PERFORM log_debug('create_transport_order_with_debug', 'AUDIT', '監査ログ作成完了');
    PERFORM log_debug('create_transport_order_with_debug', 'END', '輸送オーダー作成プロシージャ完了', 'order_id', v_order_id::TEXT);
    
    RETURN v_order_id;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('create_transport_order_with_debug', 'ERROR', '輸送オーダー作成エラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 2. パフォーマンス監視関数の修正（タイムスタンプ型の統一）
CREATE OR REPLACE FUNCTION monitor_system_performance()
RETURNS TABLE (
    metric_name VARCHAR(50),
    metric_value NUMERIC,
    metric_unit VARCHAR(20),
    recorded_at TIMESTAMP WITHOUT TIME ZONE
) AS $$
DECLARE
    v_user_count INTEGER;
    v_material_count INTEGER;
    v_order_count INTEGER;
    v_incident_count INTEGER;
BEGIN
    -- デバッグログ開始
    PERFORM log_debug('monitor_system_performance', 'START', 'システムパフォーマンス監視開始');
    
    -- 各種統計を取得
    SELECT COUNT(*) INTO v_user_count FROM users WHERE deleted = FALSE;
    SELECT COUNT(*) INTO v_material_count FROM logistics_materials;
    SELECT COUNT(*) INTO v_order_count FROM transport_orders WHERE status IN ('PENDING', 'IN_TRANSIT');
    SELECT COUNT(*) INTO v_incident_count FROM emergency_incidents WHERE status = 'ACTIVE';
    
    -- 結果を返す（タイムスタンプ型を統一）
    RETURN QUERY
    SELECT 'active_users'::VARCHAR(50), v_user_count::NUMERIC, 'count'::VARCHAR(20), CURRENT_TIMESTAMP AT TIME ZONE 'UTC'
    UNION ALL
    SELECT 'total_materials'::VARCHAR(50), v_material_count::NUMERIC, 'count'::VARCHAR(20), CURRENT_TIMESTAMP AT TIME ZONE 'UTC'
    UNION ALL
    SELECT 'active_orders'::VARCHAR(50), v_order_count::NUMERIC, 'count'::VARCHAR(20), CURRENT_TIMESTAMP AT TIME ZONE 'UTC'
    UNION ALL
    SELECT 'active_incidents'::VARCHAR(50), v_incident_count::NUMERIC, 'count'::VARCHAR(20), CURRENT_TIMESTAMP AT TIME ZONE 'UTC';
    
    PERFORM log_debug('monitor_system_performance', 'END', 'システムパフォーマンス監視完了');
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('monitor_system_performance', 'ERROR', 'パフォーマンス監視エラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 3. 監査ログ表示の修正（カラム参照の明確化）
CREATE OR REPLACE FUNCTION show_recent_audit_logs(p_limit INTEGER DEFAULT 10)
RETURNS TABLE (
    log_id INTEGER,
    username VARCHAR(50),
    action VARCHAR(100),
    details TEXT,
    log_created_at TIMESTAMP WITHOUT TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.id,
        u.username,
        al.action,
        al.details,
        al.created_at
    FROM audit_log al
    LEFT JOIN users u ON al.user_id = u.id
    ORDER BY al.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 修正完了メッセージ
SELECT '=== 最終問題修正完了 ===' as fix_message;
SELECT '全ての関数が正常に修正されました。' as status_message; 