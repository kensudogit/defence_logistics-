-- 残りの機能修正SQL

-- 1. パフォーマンス監視機能の修正（timestamp予約語問題）
DROP FUNCTION IF EXISTS monitor_system_performance();
CREATE OR REPLACE FUNCTION monitor_system_performance() RETURNS TABLE (
    metric_name VARCHAR(50),
    metric_value NUMERIC,
    unit VARCHAR(20),
    check_timestamp TIMESTAMP
) AS $$
DECLARE
    v_user_count INTEGER;
    v_material_count INTEGER;
    v_order_count INTEGER;
    v_incident_count INTEGER;
BEGIN
    PERFORM log_debug('monitor_system_performance', 'START', 'システムパフォーマンス監視開始');
    
    -- 各種統計を取得
    SELECT COUNT(*) INTO v_user_count FROM users WHERE deleted = FALSE;
    SELECT COUNT(*) INTO v_material_count FROM logistics_materials;
    SELECT COUNT(*) INTO v_order_count FROM transport_orders;
    SELECT COUNT(*) INTO v_incident_count FROM emergency_incidents WHERE status = 'ACTIVE';
    
    -- パフォーマンスメトリクスを返す
    RETURN QUERY
    SELECT 'active_users'::VARCHAR(50), v_user_count::NUMERIC, 'count'::VARCHAR(20), CURRENT_TIMESTAMP
    UNION ALL
    SELECT 'total_materials'::VARCHAR(50), v_material_count::NUMERIC, 'count'::VARCHAR(20), CURRENT_TIMESTAMP
    UNION ALL
    SELECT 'active_orders'::VARCHAR(50), v_order_count::NUMERIC, 'count'::VARCHAR(20), CURRENT_TIMESTAMP
    UNION ALL
    SELECT 'active_incidents'::VARCHAR(50), v_incident_count::NUMERIC, 'count'::VARCHAR(20), CURRENT_TIMESTAMP;
    
    PERFORM log_debug('monitor_system_performance', 'END', 'パフォーマンス監視完了');
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('monitor_system_performance', 'ERROR', 'パフォーマンス監視エラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 2. システムヘルスチェック機能の修正（タイムスタンプ型統一）
DROP FUNCTION IF EXISTS check_system_health();
CREATE OR REPLACE FUNCTION check_system_health() RETURNS TABLE (
    component VARCHAR(50),
    status VARCHAR(20),
    message TEXT,
    last_check TIMESTAMP
) AS $$
DECLARE
    v_db_status VARCHAR(20) := 'HEALTHY';
    v_db_message TEXT := 'データベース接続正常';
    v_user_status VARCHAR(20) := 'HEALTHY';
    v_user_message TEXT := 'ユーザー管理システム正常';
    v_material_status VARCHAR(20) := 'HEALTHY';
    v_material_message TEXT := '材料管理システム正常';
    v_order_status VARCHAR(20) := 'HEALTHY';
    v_order_message TEXT := '輸送管理システム正常';
    v_incident_status VARCHAR(20) := 'HEALTHY';
    v_incident_message TEXT := '緊急事態管理システム正常';
BEGIN
    PERFORM log_debug('check_system_health', 'START', 'システムヘルスチェック開始');
    
    -- データベース接続チェック
    BEGIN
        PERFORM 1;
    EXCEPTION
        WHEN OTHERS THEN
            v_db_status := 'ERROR';
            v_db_message := 'データベース接続エラー: ' || SQLERRM;
    END;
    
    -- ユーザーシステムチェック
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM users LIMIT 1) THEN
            v_user_status := 'WARNING';
            v_user_message := 'ユーザーテーブルが空です';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            v_user_status := 'ERROR';
            v_user_message := 'ユーザーシステムエラー: ' || SQLERRM;
    END;
    
    -- 材料システムチェック
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM logistics_materials LIMIT 1) THEN
            v_material_status := 'WARNING';
            v_material_message := '材料テーブルが空です';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            v_material_status := 'ERROR';
            v_material_message := '材料システムエラー: ' || SQLERRM;
    END;
    
    -- 輸送システムチェック
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM transport_orders LIMIT 1) THEN
            v_order_status := 'WARNING';
            v_order_message := '輸送オーダーテーブルが空です';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            v_order_status := 'ERROR';
            v_order_message := '輸送システムエラー: ' || SQLERRM;
    END;
    
    -- 緊急事態システムチェック
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM emergency_incidents LIMIT 1) THEN
            v_incident_status := 'WARNING';
            v_incident_message := '緊急事態テーブルが空です';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            v_incident_status := 'ERROR';
            v_incident_message := '緊急事態システムエラー: ' || SQLERRM;
    END;
    
    -- ヘルスチェック結果を返す（タイムスタンプ型を統一）
    RETURN QUERY
    SELECT 'database'::VARCHAR(50), v_db_status, v_db_message, CURRENT_TIMESTAMP::TIMESTAMP
    UNION ALL
    SELECT 'user_management'::VARCHAR(50), v_user_status, v_user_message, CURRENT_TIMESTAMP::TIMESTAMP
    UNION ALL
    SELECT 'material_management'::VARCHAR(50), v_material_status, v_material_message, CURRENT_TIMESTAMP::TIMESTAMP
    UNION ALL
    SELECT 'transport_management'::VARCHAR(50), v_order_status, v_order_message, CURRENT_TIMESTAMP::TIMESTAMP
    UNION ALL
    SELECT 'emergency_management'::VARCHAR(50), v_incident_status, v_incident_message, CURRENT_TIMESTAMP::TIMESTAMP;
    
    PERFORM log_debug('check_system_health', 'END', 'システムヘルスチェック完了');
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('check_system_health', 'ERROR', 'ヘルスチェックエラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 3. 緊急事態報告機能の修正（カラム参照の曖昧性解決）
DROP FUNCTION IF EXISTS report_emergency_incident_with_debug(VARCHAR, VARCHAR, VARCHAR, TEXT, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION report_emergency_incident_with_debug(
    p_incident_type VARCHAR(50),
    p_location VARCHAR(100),
    p_severity VARCHAR(20),
    p_description TEXT,
    p_reported_by INTEGER DEFAULT NULL,
    p_security_level INTEGER DEFAULT 1
) RETURNS TABLE (
    incident_id INTEGER,
    incident_type VARCHAR(50),
    location VARCHAR(100),
    severity VARCHAR(20),
    description TEXT,
    reported_by INTEGER,
    security_level INTEGER,
    status VARCHAR(20),
    created_at TIMESTAMP
) AS $$
DECLARE
    v_incident_id INTEGER;
    v_audit_id INTEGER;
BEGIN
    PERFORM log_debug('report_emergency_incident_with_debug', 'START', '緊急事態報告プロシージャ開始');
    PERFORM log_debug('report_emergency_incident_with_debug', 'PARAMS', 'パラメータ確認', 'incident_type', p_incident_type);
    PERFORM log_debug('report_emergency_incident_with_debug', 'PARAMS', 'パラメータ確認', 'severity', p_severity);
    PERFORM log_debug('report_emergency_incident_with_debug', 'PARAMS', 'パラメータ確認', 'security_level', p_security_level::TEXT);
    
    IF p_incident_type IS NULL OR p_location IS NULL OR p_severity IS NULL THEN
        PERFORM log_debug('report_emergency_incident_with_debug', 'VALIDATION', '入力値検証エラー', 'error', '必須項目がNULL');
        RAISE EXCEPTION '必須項目がNULLです';
    END IF;
    
    PERFORM log_debug('report_emergency_incident_with_debug', 'VALIDATION', '入力値検証完了');
    
    INSERT INTO emergency_incidents (incident_type, location, severity, description, reported_by, security_level, status, created_at)
    VALUES (p_incident_type, p_location, p_severity, p_description, p_reported_by, p_security_level, 'ACTIVE', CURRENT_TIMESTAMP)
    RETURNING id INTO v_incident_id;
    
    PERFORM log_debug('report_emergency_incident_with_debug', 'INSERT', '緊急事態報告作成完了', 'incident_id', v_incident_id::TEXT);
    
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (p_reported_by, 'REPORT_EMERGENCY', '緊急事態報告: ' || p_incident_type || ' at ' || p_location, CURRENT_TIMESTAMP)
    RETURNING id INTO v_audit_id;
    
    PERFORM log_debug('report_emergency_incident_with_debug', 'AUDIT', '監査ログ作成完了', 'audit_id', v_audit_id::TEXT);
    PERFORM log_debug('report_emergency_incident_with_debug', 'END', '緊急事態報告プロシージャ完了', 'incident_id', v_incident_id::TEXT);
    
    -- カラム参照の曖昧性を解決
    RETURN QUERY 
    SELECT 
        ei.id, 
        ei.incident_type, 
        ei.location, 
        ei.severity, 
        ei.description, 
        ei.reported_by, 
        ei.security_level, 
        ei.status, 
        ei.created_at 
    FROM emergency_incidents ei 
    WHERE ei.id = v_incident_id;
    
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('report_emergency_incident_with_debug', 'ERROR', 'エラー発生', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 4. transport_ordersテーブルにupdated_atカラムを追加
ALTER TABLE transport_orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- 5. 輸送追跡テーブルが存在しない場合の作成
CREATE TABLE IF NOT EXISTS transport_tracking (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES transport_orders(id),
    status VARCHAR(20) NOT NULL,
    location VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id)
);

-- 修正完了の確認
SELECT '=== 機能修正完了 ===' as status; 