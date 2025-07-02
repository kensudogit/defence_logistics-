-- デバッグログテーブルの作成
CREATE TABLE IF NOT EXISTS debug_log (
    id SERIAL PRIMARY KEY,
    procedure_name VARCHAR(100) NOT NULL,
    step_name VARCHAR(100),
    message TEXT,
    variable_name VARCHAR(100),
    variable_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- デバッグログを記録する関数
CREATE OR REPLACE FUNCTION log_debug(
    p_procedure_name VARCHAR(100),
    p_step_name VARCHAR(100) DEFAULT NULL,
    p_message TEXT DEFAULT NULL,
    p_variable_name VARCHAR(100) DEFAULT NULL,
    p_variable_value TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO debug_log (procedure_name, step_name, message, variable_name, variable_value)
    VALUES (p_procedure_name, p_step_name, p_message, p_variable_name, p_variable_value);
    
    -- コンソールにも出力（PostgreSQLのログに表示）
    RAISE NOTICE 'DEBUG: % - % - % - % = %', 
        p_procedure_name, 
        COALESCE(p_step_name, 'N/A'), 
        COALESCE(p_message, 'N/A'),
        COALESCE(p_variable_name, 'N/A'),
        COALESCE(p_variable_value, 'N/A');
END;
$$ LANGUAGE plpgsql;

-- デバッグログをクリアする関数
CREATE OR REPLACE FUNCTION clear_debug_log() RETURNS VOID AS $$
BEGIN
    DELETE FROM debug_log;
    RAISE NOTICE 'デバッグログをクリアしました';
END;
$$ LANGUAGE plpgsql;

-- デバッグログを表示する関数
CREATE OR REPLACE FUNCTION show_debug_log(
    p_limit INTEGER DEFAULT 50
) RETURNS TABLE (
    id INTEGER,
    procedure_name VARCHAR(100),
    step_name VARCHAR(100),
    message TEXT,
    variable_name VARCHAR(100),
    variable_value TEXT,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dl.id,
        dl.procedure_name,
        dl.step_name,
        dl.message,
        dl.variable_name,
        dl.variable_value,
        dl.created_at
    FROM debug_log dl
    ORDER BY dl.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 特定のプロシージャのデバッグログを表示する関数
CREATE OR REPLACE FUNCTION show_procedure_debug_log(
    p_procedure_name VARCHAR(100),
    p_limit INTEGER DEFAULT 50
) RETURNS TABLE (
    id INTEGER,
    procedure_name VARCHAR(100),
    step_name VARCHAR(100),
    message TEXT,
    variable_name VARCHAR(100),
    variable_value TEXT,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dl.id,
        dl.procedure_name,
        dl.step_name,
        dl.message,
        dl.variable_name,
        dl.variable_value,
        dl.created_at
    FROM debug_log dl
    WHERE dl.procedure_name = p_procedure_name
    ORDER BY dl.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 既存のプロシージャにデバッグログを追加

-- ユーザー作成プロシージャ（デバッグ版）
CREATE OR REPLACE FUNCTION create_user_with_debug(
    p_username VARCHAR(50),
    p_email VARCHAR(100),
    p_full_name VARCHAR(100),
    p_department VARCHAR(50),
    p_security_level INTEGER DEFAULT 1
) RETURNS INTEGER AS $$
DECLARE
    v_user_id INTEGER;
    v_audit_id INTEGER;
BEGIN
    -- デバッグ開始
    PERFORM log_debug('create_user_with_debug', 'START', 'ユーザー作成プロシージャ開始');
    PERFORM log_debug('create_user_with_debug', 'PARAMS', 'パラメータ確認', 'username', p_username);
    PERFORM log_debug('create_user_with_debug', 'PARAMS', 'パラメータ確認', 'email', p_email);
    PERFORM log_debug('create_user_with_debug', 'PARAMS', 'パラメータ確認', 'security_level', p_security_level::TEXT);
    
    -- 入力値検証
    IF p_username IS NULL OR p_email IS NULL OR p_full_name IS NULL THEN
        PERFORM log_debug('create_user_with_debug', 'VALIDATION', '入力値検証エラー', 'error', '必須項目がNULL');
        RAISE EXCEPTION '必須項目がNULLです';
    END IF;
    
    PERFORM log_debug('create_user_with_debug', 'VALIDATION', '入力値検証完了');
    
    -- ユーザー作成
    INSERT INTO users (username, email, full_name, department, security_level, created_at)
    VALUES (p_username, p_email, p_full_name, p_department, p_security_level, CURRENT_TIMESTAMP)
    RETURNING id INTO v_user_id;
    
    PERFORM log_debug('create_user_with_debug', 'INSERT', 'ユーザー作成完了', 'user_id', v_user_id::TEXT);
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (v_user_id, 'CREATE_USER', 'ユーザー作成: ' || p_username, CURRENT_TIMESTAMP)
    RETURNING id INTO v_audit_id;
    
    PERFORM log_debug('create_user_with_debug', 'AUDIT', '監査ログ作成完了', 'audit_id', v_audit_id::TEXT);
    
    -- 完了
    PERFORM log_debug('create_user_with_debug', 'END', 'ユーザー作成プロシージャ完了', 'user_id', v_user_id::TEXT);
    
    RETURN v_user_id;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('create_user_with_debug', 'ERROR', 'エラー発生', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- ロジスティクス材料作成プロシージャ（デバッグ版）
CREATE OR REPLACE FUNCTION create_logistics_material_with_debug(
    p_material_code VARCHAR(50),
    p_material_name VARCHAR(100),
    p_category VARCHAR(50),
    p_quantity INTEGER,
    p_unit VARCHAR(20),
    p_security_level INTEGER DEFAULT 1,
    p_location VARCHAR(100) DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_material_id INTEGER;
    v_audit_id INTEGER;
BEGIN
    -- デバッグ開始
    PERFORM log_debug('create_logistics_material_with_debug', 'START', 'ロジスティクス材料作成プロシージャ開始');
    PERFORM log_debug('create_logistics_material_with_debug', 'PARAMS', 'パラメータ確認', 'material_code', p_material_code);
    PERFORM log_debug('create_logistics_material_with_debug', 'PARAMS', 'パラメータ確認', 'quantity', p_quantity::TEXT);
    PERFORM log_debug('create_logistics_material_with_debug', 'PARAMS', 'パラメータ確認', 'security_level', p_security_level::TEXT);
    
    -- 入力値検証
    IF p_material_code IS NULL OR p_material_name IS NULL OR p_quantity <= 0 THEN
        PERFORM log_debug('create_logistics_material_with_debug', 'VALIDATION', '入力値検証エラー', 'error', '無効な入力値');
        RAISE EXCEPTION '無効な入力値です';
    END IF;
    
    PERFORM log_debug('create_logistics_material_with_debug', 'VALIDATION', '入力値検証完了');
    
    -- 材料作成
    INSERT INTO logistics_materials (material_code, material_name, category, quantity, unit, security_level, location, created_at)
    VALUES (p_material_code, p_material_name, p_category, p_quantity, p_unit, p_security_level, p_location, CURRENT_TIMESTAMP)
    RETURNING id INTO v_material_id;
    
    PERFORM log_debug('create_logistics_material_with_debug', 'INSERT', '材料作成完了', 'material_id', v_material_id::TEXT);
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'CREATE_MATERIAL', '材料作成: ' || p_material_code || ' - ' || p_material_name, CURRENT_TIMESTAMP)
    RETURNING id INTO v_audit_id;
    
    PERFORM log_debug('create_logistics_material_with_debug', 'AUDIT', '監査ログ作成完了', 'audit_id', v_audit_id::TEXT);
    
    -- 完了
    PERFORM log_debug('create_logistics_material_with_debug', 'END', '材料作成プロシージャ完了', 'material_id', v_material_id::TEXT);
    
    RETURN v_material_id;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('create_logistics_material_with_debug', 'ERROR', 'エラー発生', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 輸送オーダー作成プロシージャ（デバッグ版）
DROP FUNCTION IF EXISTS create_transport_order_with_debug(VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER, DATE);
CREATE OR REPLACE FUNCTION create_transport_order_with_debug(
    p_order_number VARCHAR(50),
    p_origin_location VARCHAR(100),
    p_destination_location VARCHAR(100),
    p_priority VARCHAR(20) DEFAULT 'NORMAL',
    p_security_level INTEGER DEFAULT 1,
    p_estimated_delivery_date DATE DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_order_id INTEGER;
    v_audit_id INTEGER;
BEGIN
    PERFORM log_debug('create_transport_order_with_debug', 'START', '輸送オーダー作成プロシージャ開始');
    PERFORM log_debug('create_transport_order_with_debug', 'PARAMS', 'パラメータ確認', 'order_number', p_order_number);
    PERFORM log_debug('create_transport_order_with_debug', 'PARAMS', 'パラメータ確認', 'priority', p_priority);
    PERFORM log_debug('create_transport_order_with_debug', 'PARAMS', 'パラメータ確認', 'security_level', p_security_level::TEXT);
    IF p_order_number IS NULL OR p_origin_location IS NULL OR p_destination_location IS NULL THEN
        PERFORM log_debug('create_transport_order_with_debug', 'VALIDATION', '入力値検証エラー', 'error', '必須項目がNULL');
        RAISE EXCEPTION '必須項目がNULLです';
    END IF;
    PERFORM log_debug('create_transport_order_with_debug', 'VALIDATION', '入力値検証完了');
    INSERT INTO transport_orders (order_number, origin_location, destination_location, priority, security_level, estimated_delivery_date, status, created_at)
    VALUES (p_order_number, p_origin_location, p_destination_location, p_priority, p_security_level, p_estimated_delivery_date, 'PENDING', CURRENT_TIMESTAMP)
    RETURNING id INTO v_order_id;
    PERFORM log_debug('create_transport_order_with_debug', 'INSERT', '輸送オーダー作成完了', 'order_id', v_order_id::TEXT);
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'CREATE_TRANSPORT_ORDER', '輸送オーダー作成: ' || p_order_number, CURRENT_TIMESTAMP)
    RETURNING id INTO v_audit_id;
    PERFORM log_debug('create_transport_order_with_debug', 'AUDIT', '監査ログ作成完了', 'audit_id', v_audit_id::TEXT);
    PERFORM log_debug('create_transport_order_with_debug', 'END', '輸送オーダー作成プロシージャ完了', 'order_id', v_order_id::TEXT);
    RETURN v_order_id;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('create_transport_order_with_debug', 'ERROR', 'エラー発生', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 緊急事態報告プロシージャ（デバッグ版）
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
    RETURN QUERY SELECT id, incident_type, location, severity, description, reported_by, security_level, status, created_at FROM emergency_incidents WHERE id = v_incident_id;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('report_emergency_incident_with_debug', 'ERROR', 'エラー発生', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 在庫監視プロシージャ（デバッグ版）
DROP FUNCTION IF EXISTS monitor_inventory_with_debug(INTEGER);
CREATE OR REPLACE FUNCTION monitor_inventory_with_debug(
    p_threshold INTEGER DEFAULT 10
) RETURNS TABLE (
    material_id INTEGER,
    material_code VARCHAR(50),
    material_name VARCHAR(100),
    current_quantity INTEGER,
    threshold INTEGER,
    status VARCHAR(20)
) AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    PERFORM log_debug('monitor_inventory_with_debug', 'START', '在庫監視プロシージャ開始');
    PERFORM log_debug('monitor_inventory_with_debug', 'PARAMS', 'パラメータ確認', 'threshold', p_threshold::TEXT);
    RETURN QUERY
    SELECT 
        lm.id,
        lm.material_code,
        lm.material_name,
        lm.quantity,
        p_threshold,
        CASE 
            WHEN lm.quantity <= p_threshold THEN 'LOW_STOCK'
            ELSE 'NORMAL'
        END as status
    FROM logistics_materials lm
    WHERE lm.quantity <= p_threshold;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    PERFORM log_debug('monitor_inventory_with_debug', 'QUERY', '在庫監視クエリ実行完了', 'low_stock_count', v_count::TEXT);
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'MONITOR_INVENTORY', '在庫監視実行: ' || v_count || '個の材料が低在庫', CURRENT_TIMESTAMP);
    PERFORM log_debug('monitor_inventory_with_debug', 'AUDIT', '監査ログ作成完了');
    PERFORM log_debug('monitor_inventory_with_debug', 'END', '在庫監視プロシージャ完了', 'total_low_stock', v_count::TEXT);
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('monitor_inventory_with_debug', 'ERROR', 'エラー発生', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- セキュリティ監査レポート生成プロシージャ（デバッグ版）
DROP FUNCTION IF EXISTS generate_security_audit_report_with_debug(DATE, DATE);
CREATE OR REPLACE FUNCTION generate_security_audit_report_with_debug(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
    user_id INTEGER,
    username VARCHAR(50),
    action_count INTEGER,
    last_action TIMESTAMP,
    security_level INTEGER
) AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    PERFORM log_debug('generate_security_audit_report_with_debug', 'START', 'セキュリティ監査レポート生成プロシージャ開始');
    PERFORM log_debug('generate_security_audit_report_with_debug', 'PARAMS', 'パラメータ確認', 'start_date', p_start_date::TEXT);
    PERFORM log_debug('generate_security_audit_report_with_debug', 'PARAMS', 'パラメータ確認', 'end_date', p_end_date::TEXT);
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        COUNT(al.id)::INTEGER as action_count,
        MAX(al.created_at) as last_action,
        u.security_level
    FROM users u
    LEFT JOIN audit_log al ON u.id = al.user_id 
        AND al.created_at BETWEEN p_start_date AND p_end_date
    GROUP BY u.id, u.username, u.security_level
    ORDER BY action_count DESC;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    PERFORM log_debug('generate_security_audit_report_with_debug', 'QUERY', 'レポート生成クエリ実行完了', 'user_count', v_count::TEXT);
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'GENERATE_SECURITY_REPORT', 'セキュリティ監査レポート生成: ' || v_count || 'ユーザー', CURRENT_TIMESTAMP);
    PERFORM log_debug('generate_security_audit_report_with_debug', 'AUDIT', '監査ログ作成完了');
    PERFORM log_debug('generate_security_audit_report_with_debug', 'END', 'セキュリティ監査レポート生成プロシージャ完了', 'total_users', v_count::TEXT);
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('generate_security_audit_report_with_debug', 'ERROR', 'エラー発生', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- デバッグログエクスポート関数
DROP FUNCTION IF EXISTS export_debug_log_to_csv(VARCHAR);
CREATE OR REPLACE FUNCTION export_debug_log_to_csv(
    p_filename VARCHAR(100) DEFAULT 'debug_log.csv'
) RETURNS TEXT AS $$
DECLARE
    v_result TEXT;
BEGIN
    PERFORM log_debug('export_debug_log_to_csv', 'START', 'デバッグログエクスポート開始');
    PERFORM log_debug('export_debug_log_to_csv', 'PARAMS', 'パラメータ確認', 'filename', p_filename);
    SELECT string_agg(rowstr, E'\n') INTO v_result
    FROM (
        SELECT id || ',' || procedure_name || ',' || COALESCE(step_name, '') || ',' || COALESCE(message, '') || ',' || COALESCE(variable_name, '') || ',' || COALESCE(variable_value, '') || ',' || created_at::TEXT as rowstr
        FROM debug_log
        ORDER BY created_at DESC
    ) t;
    PERFORM log_debug('export_debug_log_to_csv', 'EXPORT', 'CSVエクスポート完了', 'record_count', (SELECT COUNT(*) FROM debug_log)::TEXT);
    PERFORM log_debug('export_debug_log_to_csv', 'END', 'デバッグログエクスポート完了');
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('export_debug_log_to_csv', 'ERROR', 'エラー発生', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- デバッグログ統計関数
CREATE OR REPLACE FUNCTION get_debug_statistics() RETURNS TABLE (
    total_logs INTEGER,
    procedures_count INTEGER,
    error_count INTEGER,
    latest_log TIMESTAMP
) AS $$
BEGIN
    -- デバッグ開始
    PERFORM log_debug('get_debug_statistics', 'START', 'デバッグ統計取得開始');
    
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_logs,
        COUNT(DISTINCT procedure_name)::INTEGER as procedures_count,
        COUNT(CASE WHEN message LIKE '%ERROR%' THEN 1 END)::INTEGER as error_count,
        MAX(created_at) as latest_log
    FROM debug_log;
    
    PERFORM log_debug('get_debug_statistics', 'END', 'デバッグ統計取得完了');
    
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('get_debug_statistics', 'ERROR', 'エラー発生', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 実用性向上のための追加機能

-- 1. 在庫アラート機能（自動通知）
CREATE OR REPLACE FUNCTION create_inventory_alert(
    p_material_id INTEGER,
    p_alert_type VARCHAR(20), -- 'LOW_STOCK', 'OUT_OF_STOCK', 'EXPIRING'
    p_message TEXT,
    p_priority VARCHAR(20) DEFAULT 'MEDIUM'
) RETURNS INTEGER AS $$
DECLARE
    v_alert_id INTEGER;
    v_material_name VARCHAR(100);
BEGIN
    -- 材料名を取得
    SELECT material_name INTO v_material_name FROM logistics_materials WHERE id = p_material_id;
    
    -- アラートテーブルが存在しない場合は作成
    CREATE TABLE IF NOT EXISTS inventory_alerts (
        id SERIAL PRIMARY KEY,
        material_id INTEGER REFERENCES logistics_materials(id),
        alert_type VARCHAR(20) NOT NULL,
        message TEXT NOT NULL,
        priority VARCHAR(20) DEFAULT 'MEDIUM',
        status VARCHAR(20) DEFAULT 'ACTIVE',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        resolved_at TIMESTAMP,
        resolved_by INTEGER REFERENCES users(id)
    );
    
    -- アラート作成
    INSERT INTO inventory_alerts (material_id, alert_type, message, priority, status)
    VALUES (p_material_id, p_alert_type, p_message, p_priority, 'ACTIVE')
    RETURNING id INTO v_alert_id;
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'CREATE_INVENTORY_ALERT', '在庫アラート作成: ' || v_material_name || ' - ' || p_alert_type, CURRENT_TIMESTAMP);
    
    -- デバッグログ
    PERFORM log_debug('create_inventory_alert', 'ALERT_CREATED', '在庫アラート作成完了', 'alert_id', v_alert_id::TEXT);
    
    RETURN v_alert_id;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('create_inventory_alert', 'ERROR', 'アラート作成エラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 2. 自動在庫監視とアラート生成
CREATE OR REPLACE FUNCTION auto_monitor_inventory() RETURNS VOID AS $$
DECLARE
    v_material RECORD;
    v_alert_id INTEGER;
BEGIN
    PERFORM log_debug('auto_monitor_inventory', 'START', '自動在庫監視開始');
    
    -- 低在庫材料をチェック
    FOR v_material IN 
        SELECT id, material_name, quantity, unit 
        FROM logistics_materials 
        WHERE quantity <= 10
    LOOP
        -- アラート作成
        SELECT create_inventory_alert(
            v_material.id,
            'LOW_STOCK',
            '材料「' || v_material.material_name || '」の在庫が不足しています。現在在庫: ' || v_material.quantity || ' ' || v_material.unit,
            'HIGH'
        ) INTO v_alert_id;
        
        RAISE NOTICE '低在庫アラート作成: % (ID: %)', v_material.material_name, v_alert_id;
    END LOOP;
    
    PERFORM log_debug('auto_monitor_inventory', 'END', '自動在庫監視完了');
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('auto_monitor_inventory', 'ERROR', '自動監視エラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 3. 輸送オーダー追跡機能
CREATE OR REPLACE FUNCTION update_transport_status(
    p_order_id INTEGER,
    p_new_status VARCHAR(20),
    p_location VARCHAR(100) DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_order_number VARCHAR(50);
    v_audit_id INTEGER;
BEGIN
    PERFORM log_debug('update_transport_status', 'START', '輸送ステータス更新開始');
    PERFORM log_debug('update_transport_status', 'PARAMS', 'パラメータ確認', 'order_id', p_order_id::TEXT);
    PERFORM log_debug('update_transport_status', 'PARAMS', 'パラメータ確認', 'new_status', p_new_status);
    
    -- オーダー番号を取得
    SELECT order_number INTO v_order_number FROM transport_orders WHERE id = p_order_id;
    
    IF v_order_number IS NULL THEN
        PERFORM log_debug('update_transport_status', 'ERROR', 'オーダーが見つかりません', 'order_id', p_order_id::TEXT);
        RETURN FALSE;
    END IF;
    
    -- ステータス更新
    UPDATE transport_orders 
    SET status = p_new_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_order_id;
    
    -- 追跡ログテーブルが存在しない場合は作成
    CREATE TABLE IF NOT EXISTS transport_tracking (
        id SERIAL PRIMARY KEY,
        order_id INTEGER REFERENCES transport_orders(id),
        status VARCHAR(20) NOT NULL,
        location VARCHAR(100),
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_by INTEGER REFERENCES users(id)
    );
    
    -- 追跡ログ作成
    INSERT INTO transport_tracking (order_id, status, location, notes)
    VALUES (p_order_id, p_new_status, p_location, p_notes);
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'UPDATE_TRANSPORT_STATUS', '輸送ステータス更新: ' || v_order_number || ' → ' || p_new_status, CURRENT_TIMESTAMP)
    RETURNING id INTO v_audit_id;
    
    PERFORM log_debug('update_transport_status', 'SUCCESS', 'ステータス更新完了', 'order_number', v_order_number);
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('update_transport_status', 'ERROR', 'ステータス更新エラー', 'error_message', SQLERRM);
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 4. 緊急事態エスカレーション機能
CREATE OR REPLACE FUNCTION escalate_emergency_incident(
    p_incident_id INTEGER,
    p_escalation_level INTEGER DEFAULT 1
) RETURNS BOOLEAN AS $$
DECLARE
    v_incident_type VARCHAR(50);
    v_location VARCHAR(100);
    v_severity VARCHAR(20);
    v_audit_id INTEGER;
BEGIN
    PERFORM log_debug('escalate_emergency_incident', 'START', '緊急事態エスカレーション開始');
    PERFORM log_debug('escalate_emergency_incident', 'PARAMS', 'パラメータ確認', 'incident_id', p_incident_id::TEXT);
    PERFORM log_debug('escalate_emergency_incident', 'PARAMS', 'パラメータ確認', 'escalation_level', p_escalation_level::TEXT);
    
    -- インシデント情報を取得
    SELECT incident_type, location, severity 
    INTO v_incident_type, v_location, v_severity
    FROM emergency_incidents 
    WHERE id = p_incident_id;
    
    IF v_incident_type IS NULL THEN
        PERFORM log_debug('escalate_emergency_incident', 'ERROR', 'インシデントが見つかりません', 'incident_id', p_incident_id::TEXT);
        RETURN FALSE;
    END IF;
    
    -- エスカレーションログテーブルが存在しない場合は作成
    CREATE TABLE IF NOT EXISTS emergency_escalations (
        id SERIAL PRIMARY KEY,
        incident_id INTEGER REFERENCES emergency_incidents(id),
        escalation_level INTEGER NOT NULL,
        escalated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        escalated_by INTEGER REFERENCES users(id),
        notes TEXT
    );
    
    -- エスカレーション記録
    INSERT INTO emergency_escalations (incident_id, escalation_level)
    VALUES (p_incident_id, p_escalation_level);
    
    -- インシデントの重要度を更新
    UPDATE emergency_incidents 
    SET severity = CASE 
        WHEN p_escalation_level >= 2 THEN 'CRITICAL'
        WHEN p_escalation_level >= 1 THEN 'HIGH'
        ELSE severity
    END
    WHERE id = p_incident_id;
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'ESCALATE_EMERGENCY', '緊急事態エスカレーション: ' || v_incident_type || ' at ' || v_location || ' (Level: ' || p_escalation_level || ')', CURRENT_TIMESTAMP)
    RETURNING id INTO v_audit_id;
    
    PERFORM log_debug('escalate_emergency_incident', 'SUCCESS', 'エスカレーション完了', 'incident_type', v_incident_type);
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('escalate_emergency_incident', 'ERROR', 'エスカレーションエラー', 'error_message', SQLERRM);
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 5. セキュリティレベル別アクセス制御
CREATE OR REPLACE FUNCTION check_security_access(
    p_user_id INTEGER,
    p_required_level INTEGER,
    p_action VARCHAR(50)
) RETURNS BOOLEAN AS $$
DECLARE
    v_user_level INTEGER;
    v_access_granted BOOLEAN := FALSE;
BEGIN
    PERFORM log_debug('check_security_access', 'START', 'セキュリティアクセスチェック開始');
    PERFORM log_debug('check_security_access', 'PARAMS', 'パラメータ確認', 'user_id', p_user_id::TEXT);
    PERFORM log_debug('check_security_access', 'PARAMS', 'パラメータ確認', 'required_level', p_required_level::TEXT);
    PERFORM log_debug('check_security_access', 'PARAMS', 'パラメータ確認', 'action', p_action);
    
    -- ユーザーのセキュリティレベルを取得
    SELECT security_level INTO v_user_level FROM users WHERE id = p_user_id;
    
    IF v_user_level IS NULL THEN
        PERFORM log_debug('check_security_access', 'ERROR', 'ユーザーが見つかりません', 'user_id', p_user_id::TEXT);
        RETURN FALSE;
    END IF;
    
    -- アクセス権限チェック
    IF v_user_level >= p_required_level THEN
        v_access_granted := TRUE;
        PERFORM log_debug('check_security_access', 'ACCESS_GRANTED', 'アクセス許可', 'user_level', v_user_level::TEXT);
    ELSE
        PERFORM log_debug('check_security_access', 'ACCESS_DENIED', 'アクセス拒否', 'user_level', v_user_level::TEXT);
    END IF;
    
    -- アクセスログテーブルが存在しない場合は作成
    CREATE TABLE IF NOT EXISTS access_log (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        action VARCHAR(50) NOT NULL,
        required_level INTEGER NOT NULL,
        user_level INTEGER NOT NULL,
        access_granted BOOLEAN NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- アクセスログ記録
    INSERT INTO access_log (user_id, action, required_level, user_level, access_granted)
    VALUES (p_user_id, p_action, p_required_level, v_user_level, v_access_granted);
    
    RETURN v_access_granted;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('check_security_access', 'ERROR', 'アクセスチェックエラー', 'error_message', SQLERRM);
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 6. データバックアップ・復元機能
CREATE OR REPLACE FUNCTION create_system_backup() RETURNS TEXT AS $$
DECLARE
    v_backup_id VARCHAR(50);
    v_backup_path TEXT;
    v_timestamp TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
    PERFORM log_debug('create_system_backup', 'START', 'システムバックアップ開始');
    
    -- バックアップID生成
    v_backup_id := 'BACKUP_' || to_char(v_timestamp, 'YYYYMMDD_HH24MISS');
    v_backup_path := '/backup/' || v_backup_id || '.sql';
    
    -- バックアップテーブルが存在しない場合は作成
    CREATE TABLE IF NOT EXISTS system_backups (
        id SERIAL PRIMARY KEY,
        backup_id VARCHAR(50) UNIQUE NOT NULL,
        backup_path TEXT NOT NULL,
        backup_size BIGINT,
        status VARCHAR(20) DEFAULT 'IN_PROGRESS',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        completed_at TIMESTAMP,
        notes TEXT
    );
    
    -- バックアップ記録作成
    INSERT INTO system_backups (backup_id, backup_path, status)
    VALUES (v_backup_id, v_backup_path, 'IN_PROGRESS');
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'CREATE_BACKUP', 'システムバックアップ作成: ' || v_backup_id, CURRENT_TIMESTAMP);
    
    PERFORM log_debug('create_system_backup', 'SUCCESS', 'バックアップ作成完了', 'backup_id', v_backup_id);
    
    -- バックアップステータスを完了に更新
    UPDATE system_backups 
    SET status = 'COMPLETED', completed_at = CURRENT_TIMESTAMP
    WHERE backup_id = v_backup_id;
    
    RETURN v_backup_id;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('create_system_backup', 'ERROR', 'バックアップ作成エラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 7. パフォーマンス監視機能
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

-- 8. レポート自動生成機能
CREATE OR REPLACE FUNCTION generate_daily_report() RETURNS TABLE (
    report_date DATE,
    total_users INTEGER,
    total_materials INTEGER,
    active_orders INTEGER,
    active_incidents INTEGER,
    low_stock_materials INTEGER,
    security_alerts INTEGER
) AS $$
DECLARE
    v_report_date DATE := CURRENT_DATE;
    v_total_users INTEGER;
    v_total_materials INTEGER;
    v_active_orders INTEGER;
    v_active_incidents INTEGER;
    v_low_stock_materials INTEGER;
    v_security_alerts INTEGER;
BEGIN
    PERFORM log_debug('generate_daily_report', 'START', '日次レポート生成開始');
    
    -- 各種統計を取得
    SELECT COUNT(*) INTO v_total_users FROM users WHERE deleted = FALSE;
    SELECT COUNT(*) INTO v_total_materials FROM logistics_materials;
    SELECT COUNT(*) INTO v_active_orders FROM transport_orders WHERE status IN ('PENDING', 'IN_TRANSIT');
    SELECT COUNT(*) INTO v_active_incidents FROM emergency_incidents WHERE status = 'ACTIVE';
    SELECT COUNT(*) INTO v_low_stock_materials FROM logistics_materials WHERE quantity <= 10;
    SELECT COUNT(*) INTO v_security_alerts FROM audit_log WHERE action LIKE '%SECURITY%' AND created_at >= CURRENT_DATE;
    
    -- レポートテーブルが存在しない場合は作成
    CREATE TABLE IF NOT EXISTS daily_reports (
        id SERIAL PRIMARY KEY,
        report_date DATE NOT NULL,
        total_users INTEGER,
        total_materials INTEGER,
        active_orders INTEGER,
        active_incidents INTEGER,
        low_stock_materials INTEGER,
        security_alerts INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- レポート保存
    INSERT INTO daily_reports (report_date, total_users, total_materials, active_orders, active_incidents, low_stock_materials, security_alerts)
    VALUES (v_report_date, v_total_users, v_total_materials, v_active_orders, v_active_incidents, v_low_stock_materials, v_security_alerts);
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'GENERATE_DAILY_REPORT', '日次レポート生成: ' || v_report_date, CURRENT_TIMESTAMP);
    
    PERFORM log_debug('generate_daily_report', 'END', '日次レポート生成完了');
    
    -- レポートデータを返す
    RETURN QUERY
    SELECT v_report_date, v_total_users, v_total_materials, v_active_orders, v_active_incidents, v_low_stock_materials, v_security_alerts;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('generate_daily_report', 'ERROR', 'レポート生成エラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 9. システムヘルスチェック機能
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
    
    -- ヘルスチェック結果を返す
    RETURN QUERY
    SELECT 'database'::VARCHAR(50), v_db_status, v_db_message, CURRENT_TIMESTAMP
    UNION ALL
    SELECT 'user_management'::VARCHAR(50), v_user_status, v_user_message, CURRENT_TIMESTAMP
    UNION ALL
    SELECT 'material_management'::VARCHAR(50), v_material_status, v_material_message, CURRENT_TIMESTAMP
    UNION ALL
    SELECT 'transport_management'::VARCHAR(50), v_order_status, v_order_message, CURRENT_TIMESTAMP
    UNION ALL
    SELECT 'emergency_management'::VARCHAR(50), v_incident_status, v_incident_message, CURRENT_TIMESTAMP;
    
    PERFORM log_debug('check_system_health', 'END', 'システムヘルスチェック完了');
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('check_system_health', 'ERROR', 'ヘルスチェックエラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- 10. 自動メンテナンス機能
CREATE OR REPLACE FUNCTION run_system_maintenance() RETURNS TEXT AS $$
DECLARE
    v_maintenance_id VARCHAR(50);
    v_result TEXT := '';
    v_old_logs_count INTEGER;
    v_old_audit_count INTEGER;
BEGIN
    PERFORM log_debug('run_system_maintenance', 'START', 'システムメンテナンス開始');
    
    -- メンテナンスID生成
    v_maintenance_id := 'MAINT_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    
    -- 古いデバッグログを削除（30日以上前）
    SELECT COUNT(*) INTO v_old_logs_count FROM debug_log WHERE created_at < CURRENT_DATE - INTERVAL '30 days';
    DELETE FROM debug_log WHERE created_at < CURRENT_DATE - INTERVAL '30 days';
    
    -- 古い監査ログを削除（90日以上前）
    SELECT COUNT(*) INTO v_old_audit_count FROM audit_log WHERE created_at < CURRENT_DATE - INTERVAL '90 days';
    DELETE FROM audit_log WHERE created_at < CURRENT_DATE - INTERVAL '90 days';
    
    -- 解決済みアラートをクリーンアップ
    DELETE FROM inventory_alerts WHERE status = 'RESOLVED' AND resolved_at < CURRENT_DATE - INTERVAL '7 days';
    
    -- メンテナンス結果を記録
    v_result := 'メンテナンス完了: ' || v_maintenance_id || 
                ', 削除されたデバッグログ: ' || v_old_logs_count || 
                ', 削除された監査ログ: ' || v_old_audit_count;
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (NULL, 'SYSTEM_MAINTENANCE', v_result, CURRENT_TIMESTAMP);
    
    PERFORM log_debug('run_system_maintenance', 'END', 'システムメンテナンス完了');
    
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('run_system_maintenance', 'ERROR', 'メンテナンスエラー', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql; 