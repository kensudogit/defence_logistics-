-- 防衛省ロジスティクス基盤セットアップスクリプト（エラー修正版）
-- Defense Logistics Infrastructure Setup Script (Fixed Version)

-- 1. 基本テーブル作成
CREATE TABLE IF NOT EXISTS security_levels (
    level_id SERIAL PRIMARY KEY,
    level_name VARCHAR(50) NOT NULL UNIQUE,
    clearance_required VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS logistics_materials (
    material_id SERIAL PRIMARY KEY,
    material_code VARCHAR(50) NOT NULL UNIQUE,
    material_name VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    current_stock INTEGER DEFAULT 0,
    min_stock_level INTEGER DEFAULT 0,
    max_stock_level INTEGER DEFAULT 0,
    security_level_id INTEGER REFERENCES security_levels(level_id),
    location_code VARCHAR(50),
    supplier_info TEXT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transportation_orders (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    priority_level INTEGER DEFAULT 3 CHECK (priority_level BETWEEN 1 AND 5),
    origin_location VARCHAR(100) NOT NULL,
    destination_location VARCHAR(100) NOT NULL,
    material_id INTEGER REFERENCES logistics_materials(material_id),
    quantity INTEGER NOT NULL,
    required_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    assigned_vehicle VARCHAR(50),
    assigned_driver VARCHAR(100),
    security_clearance VARCHAR(50),
    created_by INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS security_audit_logs (
    audit_id SERIAL PRIMARY KEY,
    user_id INTEGER,
    action_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(50),
    record_id INTEGER,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),
    security_level VARCHAR(50),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS emergency_incidents (
    incident_id SERIAL PRIMARY KEY,
    incident_code VARCHAR(50) NOT NULL UNIQUE,
    incident_type VARCHAR(100) NOT NULL,
    severity_level INTEGER CHECK (severity_level BETWEEN 1 AND 5),
    location VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    affected_materials TEXT,
    response_team VARCHAR(100),
    status VARCHAR(50) DEFAULT 'active',
    reported_by INTEGER,
    reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    resolution_notes TEXT
);

-- 2. インデックス作成
CREATE INDEX IF NOT EXISTS idx_logistics_materials_code ON logistics_materials(material_code);
CREATE INDEX IF NOT EXISTS idx_logistics_materials_category ON logistics_materials(category);
CREATE INDEX IF NOT EXISTS idx_transportation_orders_status ON transportation_orders(status);
CREATE INDEX IF NOT EXISTS idx_transportation_orders_priority ON transportation_orders(priority_level);
CREATE INDEX IF NOT EXISTS idx_security_audit_logs_user ON security_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_security_audit_logs_timestamp ON security_audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_emergency_incidents_status ON emergency_incidents(status);
CREATE INDEX IF NOT EXISTS idx_emergency_incidents_severity ON emergency_incidents(severity_level);

-- 3. 初期データ挿入
INSERT INTO security_levels (level_name, clearance_required, description) VALUES
('一般', '一般', '一般職員向け'),
('機密', '機密', '機密情報取扱者向け'),
('極秘', '極秘', '極秘情報取扱者向け'),
('最重要機密', '最重要機密', '最重要機密情報取扱者向け')
ON CONFLICT (level_name) DO NOTHING;

INSERT INTO logistics_materials (material_code, material_name, category, unit, current_stock, min_stock_level, max_stock_level, security_level_id, location_code, supplier_info) VALUES
('MAT001', '燃料（軽油）', '燃料', 'リットル', 10000, 2000, 15000, 1, 'LOC001', '燃料供給会社A'),
('MAT002', '食糧（缶詰）', '食糧', '缶', 5000, 1000, 8000, 1, 'LOC002', '食糧供給会社B'),
('MAT003', '通信機器', '電子機器', '台', 100, 20, 200, 2, 'LOC003', '通信機器会社C'),
('MAT004', '医療用品', '医療', 'セット', 200, 50, 300, 2, 'LOC004', '医療用品会社D'),
('MAT005', '武器部品', '武器', '個', 50, 10, 100, 4, 'LOC005', '武器部品会社E')
ON CONFLICT (material_code) DO NOTHING;

-- 4. セキュリティ強化ユーザー管理プロシージャー
CREATE OR REPLACE FUNCTION create_defense_user(
    p_username VARCHAR(50),
    p_email VARCHAR(100),
    p_full_name VARCHAR(100),
    p_department VARCHAR(100),
    p_security_clearance VARCHAR(50),
    p_rank VARCHAR(50),
    p_phone VARCHAR(20),
    p_created_by INTEGER DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_user_id INTEGER;
BEGIN
    IF p_security_clearance NOT IN ('一般', '機密', '極秘', '最重要機密') THEN
        RAISE EXCEPTION '無効なセキュリティクリアランス: %', p_security_clearance;
    END IF;
    
    INSERT INTO m_user (name, status, last_login_at)
    VALUES (p_username, 'active', CURRENT_TIMESTAMP)
    RETURNING id INTO v_user_id;
    
    INSERT INTO security_audit_logs (user_id, action_type, table_name, record_id, new_values, security_level)
    VALUES (p_created_by, 'CREATE_USER', 'm_user', v_user_id, 
            jsonb_build_object('username', p_username, 'security_clearance', p_security_clearance, 'rank', p_rank),
            p_security_clearance);
    
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;

-- 5. ロジスティクス資材管理プロシージャー
CREATE OR REPLACE FUNCTION manage_logistics_material(
    p_action VARCHAR(20),
    p_material_code VARCHAR(50),
    p_material_name VARCHAR(200),
    p_category VARCHAR(100),
    p_unit VARCHAR(20),
    p_current_stock INTEGER,
    p_min_stock_level INTEGER,
    p_max_stock_level INTEGER,
    p_security_level VARCHAR(50),
    p_location_code VARCHAR(50),
    p_supplier_info TEXT,
    p_user_id INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_material_id INTEGER;
    v_old_values JSONB;
    v_new_values JSONB;
BEGIN
    IF p_security_level NOT IN ('一般', '機密', '極秘', '最重要機密') THEN
        RAISE EXCEPTION '無効なセキュリティレベル: %', p_security_level;
    END IF;
    
    CASE p_action
        WHEN 'CREATE' THEN
            INSERT INTO logistics_materials (
                material_code, material_name, category, unit, current_stock,
                min_stock_level, max_stock_level, security_level_id, location_code, supplier_info
            )
            SELECT p_material_code, p_material_name, p_category, p_unit, p_current_stock,
                   p_min_stock_level, p_max_stock_level, sl.level_id, p_location_code, p_supplier_info
            FROM security_levels sl WHERE sl.level_name = p_security_level
            RETURNING material_id INTO v_material_id;
            
            v_new_values := jsonb_build_object(
                'material_code', p_material_code,
                'material_name', p_material_name,
                'security_level', p_security_level
            );
            
        WHEN 'UPDATE' THEN
            SELECT material_id INTO v_material_id FROM logistics_materials WHERE material_code = p_material_code;
            
            IF v_material_id IS NULL THEN
                RAISE EXCEPTION '資材が見つかりません: %', p_material_code;
            END IF;
            
            SELECT to_jsonb(lm.*) INTO v_old_values FROM logistics_materials lm WHERE lm.material_id = v_material_id;
            
            UPDATE logistics_materials SET
                material_name = p_material_name,
                category = p_category,
                unit = p_unit,
                current_stock = p_current_stock,
                min_stock_level = p_min_stock_level,
                max_stock_level = p_max_stock_level,
                security_level_id = (SELECT level_id FROM security_levels WHERE level_name = p_security_level),
                location_code = p_location_code,
                supplier_info = p_supplier_info,
                last_updated = CURRENT_TIMESTAMP
            WHERE material_id = v_material_id;
            
            v_new_values := jsonb_build_object(
                'material_code', p_material_code,
                'material_name', p_material_name,
                'current_stock', p_current_stock
            );
            
        WHEN 'DELETE' THEN
            SELECT material_id INTO v_material_id FROM logistics_materials WHERE material_code = p_material_code;
            
            IF v_material_id IS NULL THEN
                RAISE EXCEPTION '資材が見つかりません: %', p_material_code;
            END IF;
            
            DELETE FROM logistics_materials WHERE material_id = v_material_id;
            
        ELSE
            RAISE EXCEPTION '無効なアクション: %', p_action;
    END CASE;
    
    INSERT INTO security_audit_logs (user_id, action_type, table_name, record_id, old_values, new_values, security_level)
    VALUES (p_user_id, p_action || '_MATERIAL', 'logistics_materials', v_material_id, v_old_values, v_new_values, p_security_level);
    
    RETURN v_material_id;
END;
$$ LANGUAGE plpgsql;

-- 6. 輸送オーダー管理プロシージャー
CREATE OR REPLACE FUNCTION create_transportation_order(
    p_priority_level INTEGER,
    p_origin_location VARCHAR(100),
    p_destination_location VARCHAR(100),
    p_material_code VARCHAR(50),
    p_quantity INTEGER,
    p_required_date DATE,
    p_assigned_vehicle VARCHAR(50),
    p_assigned_driver VARCHAR(100),
    p_created_by INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_order_id INTEGER;
    v_material_id INTEGER;
    v_security_level VARCHAR(50);
BEGIN
    SELECT lm.material_id, sl.level_name INTO v_material_id, v_security_level
    FROM logistics_materials lm
    JOIN security_levels sl ON lm.security_level_id = sl.level_id
    WHERE lm.material_code = p_material_code;
    
    IF v_material_id IS NULL THEN
        RAISE EXCEPTION '資材が見つかりません: %', p_material_code;
    END IF;
    
    IF (SELECT current_stock FROM logistics_materials WHERE material_id = v_material_id) < p_quantity THEN
        RAISE EXCEPTION '在庫不足: 要求数量 % に対して在庫 %', 
            p_quantity, (SELECT current_stock FROM logistics_materials WHERE material_id = v_material_id);
    END IF;
    
    INSERT INTO transportation_orders (
        order_number, priority_level, origin_location, destination_location,
        material_id, quantity, required_date, assigned_vehicle, assigned_driver,
        security_clearance, created_by
    )
    VALUES (
        'TO-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD') || '-' || nextval('transportation_orders_order_id_seq'),
        p_priority_level, p_origin_location, p_destination_location,
        v_material_id, p_quantity, p_required_date, p_assigned_vehicle, p_assigned_driver,
        v_security_level, p_created_by
    )
    RETURNING order_id INTO v_order_id;
    
    UPDATE logistics_materials 
    SET current_stock = current_stock - p_quantity,
        last_updated = CURRENT_TIMESTAMP
    WHERE material_id = v_material_id;
    
    INSERT INTO security_audit_logs (user_id, action_type, table_name, record_id, new_values, security_level)
    VALUES (p_created_by, 'CREATE_TRANSPORT_ORDER', 'transportation_orders', v_order_id,
            jsonb_build_object('order_number', 'TO-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD') || '-' || v_order_id,
                              'material_code', p_material_code, 'quantity', p_quantity),
            v_security_level);
    
    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

-- 7. 緊急事態管理プロシージャー
CREATE OR REPLACE FUNCTION report_emergency_incident(
    p_incident_type VARCHAR(100),
    p_severity_level INTEGER,
    p_location VARCHAR(200),
    p_description TEXT,
    p_affected_materials TEXT,
    p_response_team VARCHAR(100),
    p_reported_by INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_incident_id INTEGER;
    v_incident_code VARCHAR(50);
BEGIN
    IF p_severity_level NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION '無効な重大度レベル: % (1-5の範囲で指定してください)', p_severity_level;
    END IF;
    
    v_incident_code := 'EI-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD-HH24MISS');
    
    INSERT INTO emergency_incidents (
        incident_code, incident_type, severity_level, location, description,
        affected_materials, response_team, reported_by
    )
    VALUES (
        v_incident_code, p_incident_type, p_severity_level, p_location, p_description,
        p_affected_materials, p_response_team, p_reported_by
    )
    RETURNING incident_id INTO v_incident_id;
    
    INSERT INTO security_audit_logs (user_id, action_type, table_name, record_id, new_values, security_level)
    VALUES (p_reported_by, 'REPORT_EMERGENCY', 'emergency_incidents', v_incident_id,
            jsonb_build_object('incident_code', v_incident_code, 'severity_level', p_severity_level),
            '極秘');
    
    IF p_severity_level >= 4 THEN
        PERFORM send_emergency_alert(v_incident_id, p_severity_level, p_location);
    END IF;
    
    RETURN v_incident_id;
END;
$$ LANGUAGE plpgsql;

-- 8. 緊急アラート送信プロシージャー
CREATE OR REPLACE FUNCTION send_emergency_alert(
    p_incident_id INTEGER,
    p_severity_level INTEGER,
    p_location VARCHAR(200)
) RETURNS VOID AS $$
BEGIN
    INSERT INTO security_audit_logs (user_id, action_type, table_name, record_id, new_values, security_level)
    VALUES (1, 'EMERGENCY_ALERT', 'emergency_incidents', p_incident_id,
            jsonb_build_object('severity_level', p_severity_level, 'location', p_location),
            '最重要機密');
    
    RAISE NOTICE '緊急アラート発行: インシデントID %, 重大度レベル %, 場所 %', 
        p_incident_id, p_severity_level, p_location;
END;
$$ LANGUAGE plpgsql;

-- 9. 在庫監視プロシージャー
CREATE OR REPLACE FUNCTION monitor_inventory_levels() RETURNS TABLE(
    material_code VARCHAR(50),
    material_name VARCHAR(200),
    current_stock INTEGER,
    min_stock_level INTEGER,
    max_stock_level INTEGER,
    stock_status VARCHAR(20),
    security_level VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        lm.material_code,
        lm.material_name,
        lm.current_stock,
        lm.min_stock_level,
        lm.max_stock_level,
        CASE 
            WHEN lm.current_stock <= lm.min_stock_level THEN '在庫不足'::VARCHAR(20)
            WHEN lm.current_stock >= lm.max_stock_level THEN '在庫過多'::VARCHAR(20)
            ELSE '正常'::VARCHAR(20)
        END as stock_status,
        sl.level_name as security_level
    FROM logistics_materials lm
    JOIN security_levels sl ON lm.security_level_id = sl.level_id
    ORDER BY 
        CASE 
            WHEN lm.current_stock <= lm.min_stock_level THEN 1
            WHEN lm.current_stock >= lm.max_stock_level THEN 2
            ELSE 3
        END,
        lm.material_name;
END;
$$ LANGUAGE plpgsql;

-- 10. セキュリティ監査レポート生成プロシージャー
CREATE OR REPLACE FUNCTION generate_security_audit_report(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_security_level VARCHAR(50) DEFAULT NULL
) RETURNS TABLE(
    user_name VARCHAR(100),
    action_type VARCHAR(50),
    table_name VARCHAR(50),
    record_count BIGINT,
    last_action TIMESTAMP,
    security_level VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.name as user_name,
        sal.action_type,
        sal.table_name,
        COUNT(*) as record_count,
        MAX(sal.timestamp) as last_action,
        sal.security_level
    FROM security_audit_logs sal
    LEFT JOIN m_user u ON sal.user_id = u.id
    WHERE sal.timestamp::date BETWEEN p_start_date AND p_end_date
        AND (p_security_level IS NULL OR sal.security_level = p_security_level)
    GROUP BY u.name, sal.action_type, sal.table_name, sal.security_level
    ORDER BY record_count DESC, last_action DESC;
END;
$$ LANGUAGE plpgsql;

-- 11. 輸送効率分析プロシージャー（エイリアス名修正）
CREATE OR REPLACE FUNCTION analyze_transportation_efficiency(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE(
    origin_location VARCHAR(100),
    destination_location VARCHAR(100),
    total_orders BIGINT,
    total_quantity BIGINT,
    avg_priority DECIMAL(3,2),
    completion_rate DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t_order.origin_location,
        t_order.destination_location,
        COUNT(*) as total_orders,
        SUM(t_order.quantity) as total_quantity,
        AVG(t_order.priority_level::DECIMAL) as avg_priority,
        (COUNT(CASE WHEN t_order.status = 'completed' THEN 1 END) * 100.0 / COUNT(*)) as completion_rate
    FROM transportation_orders t_order
    WHERE t_order.created_at::date BETWEEN p_start_date AND p_end_date
    GROUP BY t_order.origin_location, t_order.destination_location
    ORDER BY total_orders DESC;
END;
$$ LANGUAGE plpgsql;

-- 12. システムヘルスチェック（カラム名明示）
CREATE OR REPLACE FUNCTION defense_system_health_check() RETURNS TABLE(
    check_item VARCHAR(100),
    status VARCHAR(20),
    details TEXT,
    severity VARCHAR(20)
) AS $$
DECLARE
    v_low_stock_count INTEGER;
    v_pending_orders_count INTEGER;
    v_active_incidents_count INTEGER;
    v_recent_audit_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_low_stock_count
    FROM logistics_materials 
    WHERE current_stock <= min_stock_level;
    
    IF v_low_stock_count > 0 THEN
        RETURN QUERY SELECT 
            '在庫不足資材'::VARCHAR(100),
            '警告'::VARCHAR(20),
            (v_low_stock_count || '件の資材が在庫不足です')::TEXT,
            '中'::VARCHAR(20);
    END IF;
    
    SELECT COUNT(*) INTO v_pending_orders_count
    FROM transportation_orders 
    WHERE transportation_orders.status = 'pending' AND required_date < CURRENT_DATE;
    
    IF v_pending_orders_count > 0 THEN
        RETURN QUERY SELECT 
            '期限超過輸送オーダー'::VARCHAR(100),
            '緊急'::VARCHAR(20),
            (v_pending_orders_count || '件の輸送オーダーが期限超過です')::TEXT,
            '高'::VARCHAR(20);
    END IF;
    
    SELECT COUNT(*) INTO v_active_incidents_count
    FROM emergency_incidents 
    WHERE emergency_incidents.status = 'active' AND severity_level >= 4;
    
    IF v_active_incidents_count > 0 THEN
        RETURN QUERY SELECT 
            '重大緊急事態'::VARCHAR(100),
            '緊急'::VARCHAR(20),
            (v_active_incidents_count || '件の重大な緊急事態が発生中です')::TEXT,
            '最高'::VARCHAR(20);
    END IF;
    
    SELECT COUNT(*) INTO v_recent_audit_count
    FROM security_audit_logs 
    WHERE timestamp > CURRENT_TIMESTAMP - INTERVAL '1 hour';
    
    IF v_recent_audit_count = 0 THEN
        RETURN QUERY SELECT 
            'セキュリティ監査ログ'::VARCHAR(100),
            '警告'::VARCHAR(20),
            '過去1時間にセキュリティ監査ログが記録されていません'::TEXT,
            '中'::VARCHAR(20);
    END IF;
    
    RETURN QUERY SELECT 
        'システム全体'::VARCHAR(100),
        '正常'::VARCHAR(20),
        'すべてのシステムが正常に動作しています'::TEXT,
        '低'::VARCHAR(20);
END;
$$ LANGUAGE plpgsql;

-- 13. データエクスポート機能（エイリアス名修正）
CREATE OR REPLACE FUNCTION export_secure_data(
    p_data_type VARCHAR(50),
    p_security_level VARCHAR(50),
    p_user_id INTEGER
) RETURNS TEXT AS $$
DECLARE
    v_export_data TEXT;
    v_filename VARCHAR(100);
BEGIN
    IF p_security_level NOT IN ('一般', '機密', '極秘', '最重要機密') THEN
        RAISE EXCEPTION '無効なセキュリティレベル: %', p_security_level;
    END IF;
    
    CASE p_data_type
        WHEN 'logistics_materials' THEN
            SELECT string_agg(
                material_code || ',' || material_name || ',' || category || ',' || 
                current_stock || ',' || security_level, E'\n'
            ) INTO v_export_data
            FROM logistics_materials lm
            JOIN security_levels sl ON lm.security_level_id = sl.level_id
            WHERE sl.level_name <= p_security_level;
            
        WHEN 'transportation_orders' THEN
            SELECT string_agg(
                order_number || ',' || origin_location || ',' || destination_location || ',' ||
                quantity || ',' || status, E'\n'
            ) INTO v_export_data
            FROM transportation_orders t_order
            WHERE t_order.security_clearance <= p_security_level;
            
        WHEN 'security_audit' THEN
            SELECT string_agg(
                timestamp::text || ',' || action_type || ',' || table_name || ',' ||
                security_level, E'\n'
            ) INTO v_export_data
            FROM security_audit_logs sal
            WHERE sal.security_level <= p_security_level
            AND sal.timestamp > CURRENT_TIMESTAMP - INTERVAL '7 days';
            
        ELSE
            RAISE EXCEPTION '無効なデータタイプ: %', p_data_type;
    END CASE;
    
    INSERT INTO security_audit_logs (user_id, action_type, table_name, new_values, security_level)
    VALUES (p_user_id, 'EXPORT_DATA', p_data_type, 
            jsonb_build_object('data_type', p_data_type, 'security_level', p_security_level),
            p_security_level);
    
    v_filename := p_data_type || '_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS') || '.csv';
    
    RETURN 'ファイル名: ' || v_filename || E'\n\n' || v_export_data;
END;
$$ LANGUAGE plpgsql;

-- 14. 自動メンテナンスプロシージャー
CREATE OR REPLACE FUNCTION auto_maintenance_defense_system() RETURNS VOID AS $$
DECLARE
    v_old_records_count INTEGER;
    v_cleaned_records_count INTEGER;
BEGIN
    DELETE FROM security_audit_logs 
    WHERE timestamp < CURRENT_TIMESTAMP - INTERVAL '1 year';
    
    GET DIAGNOSTICS v_cleaned_records_count = ROW_COUNT;
    
    UPDATE emergency_incidents 
    SET status = 'archived'
    WHERE status = 'resolved' 
    AND resolved_at < CURRENT_TIMESTAMP - INTERVAL '30 days';
    
    INSERT INTO security_audit_logs (user_id, action_type, table_name, new_values, security_level)
    VALUES (1, 'AUTO_MAINTENANCE', 'system', 
            jsonb_build_object('cleaned_audit_logs', v_cleaned_records_count),
            '一般');
    
    RAISE NOTICE '自動メンテナンス完了: %件の古い監査ログを削除しました', v_cleaned_records_count;
END;
$$ LANGUAGE plpgsql; 