-- PostgreSQL SQLプロシージャのサンプル（実用性向上版）

-- ログテーブルの作成
CREATE TABLE IF NOT EXISTS t_audit_log (
    id SERIAL PRIMARY KEY,
    operation_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id INTEGER,
    old_values JSONB,
    new_values JSONB,
    user_name VARCHAR(100) DEFAULT current_user,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET DEFAULT inet_client_addr()
);

-- 設定テーブルの作成
CREATE TABLE IF NOT EXISTS t_config (
    config_key VARCHAR(100) PRIMARY KEY,
    config_value TEXT,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 初期設定データ
INSERT INTO t_config (config_key, config_value, description) VALUES 
    ('max_users_per_batch', '100', 'バッチ処理での最大ユーザー数'),
    ('user_cleanup_days', '90', '非アクティブユーザーのクリーンアップ日数'),
    ('error_log_retention_days', '30', 'エラーログの保持日数'),
    ('system_maintenance_mode', 'false', 'システムメンテナンスモード')
ON CONFLICT (config_key) DO NOTHING;

-- 1. 監査ログ付きユーザー作成プロシージャ
CREATE OR REPLACE PROCEDURE create_user_with_audit(
    user_name TEXT,
    user_status TEXT DEFAULT 'active',
    user_email TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_user_id INTEGER;
    config_val TEXT;
BEGIN
    -- 設定値を取得
    SELECT config_value INTO config_val FROM t_config WHERE config_key = 'max_users_per_batch';
    
    -- ユーザー作成
    INSERT INTO m_user (name, status, last_login_at) 
    VALUES (user_name, user_status, CURRENT_TIMESTAMP)
    RETURNING id INTO new_user_id;
    
    -- 監査ログを記録
    INSERT INTO t_audit_log (operation_type, table_name, record_id, new_values)
    VALUES ('INSERT', 'm_user', new_user_id, 
            jsonb_build_object('name', user_name, 'status', user_status, 'email', user_email));
    
    RAISE NOTICE 'ユーザー "%" (ID: %) を作成しました (ステータス: %)', user_name, new_user_id, user_status;
END;
$$;

-- 1-1. 操作ユーザー明示対応版 監査ログ付きユーザー作成
CREATE OR REPLACE PROCEDURE create_user_with_audit_v2(
    user_name TEXT,
    user_status TEXT DEFAULT 'active',
    user_email TEXT DEFAULT NULL,
    operator_name TEXT DEFAULT current_user
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_user_id INTEGER;
BEGIN
    INSERT INTO m_user (name, status, last_login_at)
    VALUES (user_name, user_status, CURRENT_TIMESTAMP)
    RETURNING id INTO new_user_id;

    INSERT INTO t_audit_log (operation_type, table_name, record_id, new_values, user_name)
    VALUES ('INSERT', 'm_user', new_user_id,
            jsonb_build_object('name', user_name, 'status', user_status, 'email', user_email),
            operator_name);

    RAISE NOTICE 'ユーザー "%" (ID: %) を作成しました (ステータス: %) by %', user_name, new_user_id, user_status, operator_name;
END;
$$;

-- 2. バッチユーザー作成プロシージャ（実用性向上）
CREATE OR REPLACE PROCEDURE create_users_batch(
    user_data JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    user_record JSONB;
    created_count INTEGER := 0;
    error_count INTEGER := 0;
    max_users INTEGER;
    cfg_val TEXT;
BEGIN
    -- 設定値を取得
    SELECT config_value INTO cfg_val FROM t_config WHERE config_key = 'max_users_per_batch';
    max_users := COALESCE(cfg_val::INTEGER, 100);
    
    -- バッチサイズチェック
    IF jsonb_array_length(user_data) > max_users THEN
        RAISE EXCEPTION 'バッチサイズが上限 % を超えています', max_users;
    END IF;
    
    -- トランザクション開始
    BEGIN
        FOR user_record IN SELECT * FROM jsonb_array_elements(user_data)
        LOOP
            BEGIN
                INSERT INTO m_user (name, status, last_login_at)
                VALUES (
                    user_record->>'name',
                    COALESCE(user_record->>'status', 'active'),
                    CURRENT_TIMESTAMP
                );
                created_count := created_count + 1;
                
                -- 監査ログ
                INSERT INTO t_audit_log (operation_type, table_name, new_values)
                VALUES ('BATCH_INSERT', 'm_user', user_record);
                
            EXCEPTION
                WHEN OTHERS THEN
                    error_count := error_count + 1;
                    INSERT INTO t_error (created_at, message)
                    VALUES (CURRENT_TIMESTAMP, 'バッチユーザー作成エラー: ' || SQLERRM || ' - データ: ' || user_record);
            END;
        END LOOP;
        
        RAISE NOTICE 'バッチ処理完了: 成功 % 件, エラー % 件', created_count, error_count;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'バッチ処理でエラーが発生: %', SQLERRM;
            RAISE;
    END;
END;
$$;

-- 3. データ検証プロシージャ
CREATE OR REPLACE FUNCTION validate_user_data(user_name TEXT, user_status TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    -- 名前の検証
    IF user_name IS NULL OR length(trim(user_name)) = 0 THEN
        RAISE NOTICE 'ユーザー名が空です';
        RETURN FALSE;
    END IF;
    
    IF length(user_name) > 100 THEN
        RAISE NOTICE 'ユーザー名が長すぎます (最大100文字)';
        RETURN FALSE;
    END IF;
    
    -- ステータスの検証
    IF user_status NOT IN ('active', 'inactive', 'suspended') THEN
        RAISE NOTICE '無効なステータスです: % (有効: active, inactive, suspended)', user_status;
        RETURN FALSE;
    END IF;
    
    -- 重複チェック
    IF EXISTS (SELECT 1 FROM m_user WHERE name = user_name) THEN
        RAISE NOTICE 'ユーザー名 "%" は既に存在します', user_name;
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$;

-- 4. パフォーマンス監視プロシージャ
CREATE OR REPLACE PROCEDURE monitor_performance()
LANGUAGE plpgsql
AS $$
DECLARE
    total_users INTEGER;
    active_users INTEGER;
    inactive_users INTEGER;
    recent_logins INTEGER;
    avg_response_time NUMERIC;
    slow_queries INTEGER;
BEGIN
    -- 基本統計
    SELECT COUNT(*) INTO total_users FROM m_user;
    SELECT COUNT(*) INTO active_users FROM m_user WHERE status = 'active';
    SELECT COUNT(*) INTO inactive_users FROM m_user WHERE status = 'inactive';
    SELECT COUNT(*) INTO recent_logins FROM m_user 
    WHERE last_login_at > CURRENT_TIMESTAMP - INTERVAL '7 days';
    
    -- パフォーマンス情報（サブクエリで分離）
    SELECT COALESCE(avg_time, 0) INTO avg_response_time
    FROM (
        SELECT ROUND(AVG(EXTRACT(EPOCH FROM (created_at - LAG(created_at) OVER (ORDER BY created_at)))), 3) as avg_time
        FROM t_audit_log 
        WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour'
    ) subq;
    
    SELECT COUNT(*) INTO slow_queries
    FROM t_error 
    WHERE message LIKE '%timeout%' OR message LIKE '%slow%'
    AND created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour';
    
    -- 結果表示
    RAISE NOTICE '=== パフォーマンス監視レポート ===';
    RAISE NOTICE '総ユーザー数: %', total_users;
    RAISE NOTICE 'アクティブユーザー数: %', active_users;
    RAISE NOTICE '非アクティブユーザー数: %', inactive_users;
    RAISE NOTICE '過去7日間のログイン数: %', recent_logins;
    RAISE NOTICE '平均応答時間: % 秒', avg_response_time;
    RAISE NOTICE 'スロークエリ数 (1時間): %', slow_queries;
    
    -- アラート条件
    IF slow_queries > 10 THEN
        RAISE NOTICE '警告: スロークエリが多発しています';
    END IF;
    
    IF avg_response_time > 1.0 THEN
        RAISE NOTICE '警告: 平均応答時間が1秒を超えています';
    END IF;
END;
$$;

-- 5. 自動メンテナンスプロシージャ
CREATE OR REPLACE PROCEDURE auto_maintenance()
LANGUAGE plpgsql
AS $$
DECLARE
    cleanup_days INTEGER;
    retention_days INTEGER;
    deleted_count INTEGER;
    maintenance_mode TEXT;
BEGIN
    -- メンテナンスモードチェック
    SELECT config_value INTO maintenance_mode FROM t_config WHERE config_key = 'system_maintenance_mode';
    IF maintenance_mode = 'true' THEN
        RAISE NOTICE 'システムメンテナンスモード中です。自動メンテナンスをスキップします。';
        RETURN;
    END IF;
    
    -- 設定値を取得
    SELECT config_value::INTEGER INTO cleanup_days FROM t_config WHERE config_key = 'user_cleanup_days';
    SELECT config_value::INTEGER INTO retention_days FROM t_config WHERE config_key = 'error_log_retention_days';
    
    -- 古いエラーログの削除
    DELETE FROM t_error WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '1 day' * retention_days;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '古いエラーログ % 件を削除しました', deleted_count;
    
    -- 古い監査ログの削除（90日以上前）
    DELETE FROM t_audit_log WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '古い監査ログ % 件を削除しました', deleted_count;
    
    -- 非アクティブユーザーの最終ログイン更新
    UPDATE m_user SET last_login_at = CURRENT_TIMESTAMP 
    WHERE status = 'inactive' AND last_login_at < CURRENT_TIMESTAMP - INTERVAL '1 day' * cleanup_days;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '非アクティブユーザーの最終ログインを % 件更新しました', deleted_count;
    
    -- 統計情報の更新
    ANALYZE m_user;
    ANALYZE t_error;
    ANALYZE t_audit_log;
    
    RAISE NOTICE '自動メンテナンスが完了しました';
END;
$$;

-- 6. データエクスポートプロシージャ
CREATE OR REPLACE PROCEDURE export_user_data(
    export_format TEXT DEFAULT 'json',
    status_filter TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    query TEXT;
    result TEXT;
BEGIN
    -- クエリの構築
    query := 'SELECT json_agg(row_to_json(t)) FROM (';
    query := query || 'SELECT id, name, status, last_login_at, created_at FROM m_user';
    
    IF status_filter IS NOT NULL THEN
        query := query || ' WHERE status = ' || quote_literal(status_filter);
    END IF;
    
    query := query || ' ORDER BY id) t';
    
    -- 結果を取得
    EXECUTE query INTO result;
    
    -- 結果をファイルに出力（PostgreSQLのCOPYコマンドを使用）
    IF export_format = 'csv' THEN
        -- CSV形式でエクスポート
        RAISE NOTICE 'CSVエクスポート機能は別途実装が必要です';
    ELSE
        -- JSON形式で出力
        RAISE NOTICE 'エクスポート結果: %', result;
    END IF;
    
    RAISE NOTICE 'データエクスポートが完了しました (形式: %)', export_format;
END;
$$;

-- 7. 設定管理プロシージャ
CREATE OR REPLACE PROCEDURE update_config(
    p_config_key TEXT,
    p_config_value TEXT,
    p_description TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO t_config (config_key, config_value, description, updated_at)
    VALUES (p_config_key, p_config_value, p_description, CURRENT_TIMESTAMP)
    ON CONFLICT (config_key) 
    DO UPDATE SET 
        config_value = EXCLUDED.config_value,
        description = COALESCE(EXCLUDED.description, t_config.description),
        updated_at = CURRENT_TIMESTAMP;
    
    -- 監査ログ
    INSERT INTO t_audit_log (operation_type, table_name, new_values)
    VALUES ('CONFIG_UPDATE', 't_config', 
            jsonb_build_object('key', p_config_key, 'value', p_config_value));
    
    RAISE NOTICE '設定 "%" を "%" に更新しました', p_config_key, p_config_value;
END;
$$;

-- 8. ヘルスチェックプロシージャ
CREATE OR REPLACE FUNCTION health_check()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    result JSONB;
    db_size BIGINT;
    connection_count INTEGER;
BEGIN
    -- データベースサイズ
    SELECT pg_database_size(current_database()) INTO db_size;
    
    -- 接続数
    SELECT count(*) INTO connection_count FROM pg_stat_activity;
    
    -- ヘルスチェック結果
    result := jsonb_build_object(
        'status', 'healthy',
        'timestamp', CURRENT_TIMESTAMP,
        'database_size_mb', ROUND(db_size / 1024.0 / 1024.0, 2),
        'active_connections', connection_count,
        'tables', jsonb_build_object(
            'm_user', (SELECT COUNT(*) FROM m_user),
            't_error', (SELECT COUNT(*) FROM t_error),
            't_audit_log', (SELECT COUNT(*) FROM t_audit_log)
        )
    );
    
    RETURN result;
END;
$$;

-- 9. バックアップ準備プロシージャ
CREATE OR REPLACE PROCEDURE prepare_backup()
LANGUAGE plpgsql
AS $$
BEGIN
    -- メンテナンスモードを有効化
    CALL update_config('system_maintenance_mode', 'true', 'バックアップ準備中');
    
    -- 未完了のトランザクションを待機
    PERFORM pg_sleep(1);
    
    -- 統計情報を更新
    ANALYZE;
    
    RAISE NOTICE 'バックアップ準備が完了しました。pg_dumpを実行してください。';
    RAISE NOTICE 'バックアップ完了後、メンテナンスモードを無効化してください。';
END;
$$;

-- 10. 復旧プロシージャ
CREATE OR REPLACE PROCEDURE post_restore_cleanup()
LANGUAGE plpgsql
AS $$
BEGIN
    -- メンテナンスモードを無効化
    CALL update_config('system_maintenance_mode', 'false', '復旧完了');
    
    -- 統計情報を更新
    ANALYZE;
    
    -- インデックスの再構築（コメントアウト）
    -- REINDEX DATABASE current_database();
    RAISE NOTICE 'インデックス再構築は手動で実行してください: REINDEX DATABASE current_database();';
    
    RAISE NOTICE '復旧後のクリーンアップが完了しました';
END;
$$;

-- 基本的なプロシージャ（既存）
-- 1. 基本的なプロシージャ - ユーザー情報を取得
CREATE OR REPLACE PROCEDURE get_user_info(user_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    user_record RECORD;
BEGIN
    SELECT * INTO user_record FROM m_user WHERE id = user_id;
    
    IF user_record IS NULL THEN
        RAISE NOTICE 'ユーザーID % が見つかりません', user_id;
    ELSE
        RAISE NOTICE 'ユーザー情報: ID=%, 名前=%, ステータス=%, 最終ログイン=%', 
            user_record.id, user_record.name, user_record.status, user_record.last_login_at;
    END IF;
END;
$$;

-- 2. パラメータ付きプロシージャ - ユーザーを作成
CREATE OR REPLACE PROCEDURE create_user(
    user_name TEXT,
    user_status TEXT DEFAULT 'active'
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- データ検証
    IF NOT validate_user_data(user_name, user_status) THEN
        RAISE EXCEPTION 'データ検証に失敗しました';
    END IF;
    
    INSERT INTO m_user (name, status, last_login_at) 
    VALUES (user_name, user_status, CURRENT_TIMESTAMP);
    
    RAISE NOTICE 'ユーザー "%" を作成しました (ステータス: %)', user_name, user_status;
END;
$$;

-- 3. 戻り値付きプロシージャ - アクティブユーザー数を取得
CREATE OR REPLACE FUNCTION get_active_user_count()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    count_result INTEGER;
BEGIN
    SELECT COUNT(*) INTO count_result FROM m_user WHERE status = 'active';
    RETURN count_result;
END;
$$;

-- 4. エラーハンドリング付きプロシージャ - ユーザーを更新
CREATE OR REPLACE PROCEDURE update_user_status(
    user_id INTEGER,
    new_status TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    old_status TEXT;
BEGIN
    -- 現在のステータスを取得
    SELECT status INTO old_status FROM m_user WHERE id = user_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ユーザーID % が見つかりません', user_id;
    END IF;
    
    -- データ検証
    IF NOT validate_user_data('dummy', new_status) THEN
        RAISE EXCEPTION '無効なステータスです: %', new_status;
    END IF;
    
    UPDATE m_user SET status = new_status WHERE id = user_id;
    
    -- 監査ログを記録
    INSERT INTO t_audit_log (operation_type, table_name, record_id, old_values, new_values)
    VALUES ('UPDATE', 'm_user', user_id, 
            jsonb_build_object('status', old_status),
            jsonb_build_object('status', new_status));
    
    RAISE NOTICE 'ユーザーID % のステータスを "%" から "%" に更新しました', user_id, old_status, new_status;
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO t_error (created_at, message) 
        VALUES (CURRENT_TIMESTAMP, 'ユーザー更新エラー: ' || SQLERRM);
        RAISE;
END;
$$;

-- 5. トランザクション付きプロシージャ - 複数ユーザーを一括作成
CREATE OR REPLACE PROCEDURE create_multiple_users(
    user_names TEXT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    user_name TEXT;
    max_users INTEGER;
    config_value TEXT;
BEGIN
    -- 設定値を取得
    SELECT config_value INTO config_value FROM t_config WHERE config_key = 'max_users_per_batch';
    max_users := COALESCE(config_value::INTEGER, 100);
    
    -- バッチサイズチェック
    IF array_length(user_names, 1) > max_users THEN
        RAISE EXCEPTION 'バッチサイズが上限 % を超えています', max_users;
    END IF;
    
    -- トランザクション開始
    BEGIN
        FOREACH user_name IN ARRAY user_names
        LOOP
            -- データ検証
            IF validate_user_data(user_name, 'active') THEN
                INSERT INTO m_user (name, status, last_login_at) 
                VALUES (user_name, 'active', CURRENT_TIMESTAMP);
                RAISE NOTICE 'ユーザー "%" を作成しました', user_name;
            ELSE
                RAISE NOTICE 'ユーザー "%" の作成をスキップしました（検証失敗）', user_name;
            END IF;
        END LOOP;
        
        RAISE NOTICE '合計 % 人のユーザーを処理しました', array_length(user_names, 1);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'エラーが発生しました: %', SQLERRM;
            RAISE;
    END;
END;
$$;

-- 6. 条件分岐付きプロシージャ - ユーザー統計を取得
CREATE OR REPLACE PROCEDURE get_user_statistics()
LANGUAGE plpgsql
AS $$
DECLARE
    total_users INTEGER;
    active_users INTEGER;
    inactive_users INTEGER;
    recent_logins INTEGER;
BEGIN
    -- 統計情報を取得
    SELECT COUNT(*) INTO total_users FROM m_user;
    SELECT COUNT(*) INTO active_users FROM m_user WHERE status = 'active';
    SELECT COUNT(*) INTO inactive_users FROM m_user WHERE status = 'inactive';
    SELECT COUNT(*) INTO recent_logins FROM m_user 
    WHERE last_login_at > CURRENT_TIMESTAMP - INTERVAL '7 days';
    
    -- 結果を表示
    RAISE NOTICE '=== ユーザー統計 ===';
    RAISE NOTICE '総ユーザー数: %', total_users;
    RAISE NOTICE 'アクティブユーザー数: %', active_users;
    RAISE NOTICE '非アクティブユーザー数: %', inactive_users;
    RAISE NOTICE '過去7日間のログイン数: %', recent_logins;
    
    -- エラーログに統計を記録
    INSERT INTO t_error (created_at, message) 
    VALUES (CURRENT_TIMESTAMP, 
        format('統計実行: 総数=%%, アクティブ=%%, 非アクティブ=%%, 最近ログイン=%%', 
               total_users, active_users, inactive_users, recent_logins));
END;
$$;

-- 7. カーソル使用プロシージャ - ユーザー一覧を処理
CREATE OR REPLACE PROCEDURE process_all_users()
LANGUAGE plpgsql
AS $$
DECLARE
    user_cursor CURSOR FOR SELECT * FROM m_user ORDER BY id;
    user_record RECORD;
    processed_count INTEGER := 0;
BEGIN
    OPEN user_cursor;
    
    LOOP
        FETCH user_cursor INTO user_record;
        EXIT WHEN NOT FOUND;
        
        -- 各ユーザーを処理
        processed_count := processed_count + 1;
        RAISE NOTICE '処理中: ID=%, 名前=%, ステータス=%', 
            user_record.id, user_record.name, user_record.status;
        
        -- 非アクティブユーザーの最終ログインを更新
        IF user_record.status = 'inactive' THEN
            UPDATE m_user SET last_login_at = CURRENT_TIMESTAMP WHERE id = user_record.id;
        END IF;
    END LOOP;
    
    CLOSE user_cursor;
    RAISE NOTICE '合計 % 人のユーザーを処理しました', processed_count;
END;
$$;

-- 8. 再帰プロシージャ - フィボナッチ数列を計算
CREATE OR REPLACE FUNCTION fibonacci(n INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF n <= 1 THEN
        RETURN n;
    ELSE
        RETURN fibonacci(n - 1) + fibonacci(n - 2);
    END IF;
END;
$$;

-- 9. 動的SQL使用プロシージャ - テーブル情報を取得
CREATE OR REPLACE PROCEDURE get_table_info(table_name TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    column_info RECORD;
    query TEXT;
BEGIN
    query := format('SELECT column_name, data_type, is_nullable 
                     FROM information_schema.columns 
                     WHERE table_name = %L 
                     ORDER BY ordinal_position', table_name);
    
    RAISE NOTICE 'テーブル "%" の構造:', table_name;
    
    FOR column_info IN EXECUTE query
    LOOP
        RAISE NOTICE 'カラム: %, 型: %, NULL許可: %', 
            column_info.column_name, column_info.data_type, column_info.is_nullable;
    END LOOP;
END;
$$;

-- 10. スケジュール実行用プロシージャ - クリーンアップ処理
CREATE OR REPLACE PROCEDURE cleanup_old_records()
LANGUAGE plpgsql
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- 30日以上前のエラーログを削除
    DELETE FROM t_error WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '30 days';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RAISE NOTICE '古いエラーログ % 件を削除しました', deleted_count;
    
    -- 非アクティブユーザーの最終ログインを更新
    UPDATE m_user SET last_login_at = CURRENT_TIMESTAMP 
    WHERE status = 'inactive' AND last_login_at < CURRENT_TIMESTAMP - INTERVAL '90 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '非アクティブユーザーの最終ログインを % 件更新しました', deleted_count;
END;
$$;

-- プロシージャの実行例
-- CALL get_user_info(1);
-- CALL create_user('David', 'active');
-- SELECT get_active_user_count();
-- CALL update_user_status(1, 'inactive');
-- CALL create_multiple_users(ARRAY['Eve', 'Frank', 'Grace']);
-- CALL get_user_statistics();
-- CALL process_all_users();
-- SELECT fibonacci(10);
-- CALL get_table_info('m_user');
-- CALL cleanup_old_records();

-- 監査ログ付きユーザー作成
CALL create_user_with_audit('AdvancedUser1', 'active', 'user1@example.com');

-- バッチユーザー作成
CALL create_users_batch('[{"name": "BatchUser1", "status": "active"}]'::jsonb);

-- 設定変更
CALL update_config('max_users_per_batch', '50', 'バッチサイズを50に変更');

-- パフォーマンス監視
CALL monitor_performance();

-- ヘルスチェック
SELECT health_check();

-- 3. エラー通知用ダミープロシージャ
CREATE OR REPLACE PROCEDURE notify_admin(message TEXT)
LANGUAGE plpgsql
AS $$
BEGIN
    -- 実際は外部サービス連携
    RAISE NOTICE '管理者通知: %', message;
END;
$$;

-- m_userテーブルに論理削除用カラム追加
ALTER TABLE m_user ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

-- ユーザー論理削除プロシージャ
CREATE OR REPLACE PROCEDURE soft_delete_user(
    p_user_id INTEGER,
    p_operator TEXT DEFAULT current_user
)
LANGUAGE plpgsql
AS $$
DECLARE
    old_status TEXT;
BEGIN
    SELECT status INTO old_status FROM m_user WHERE id = p_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ユーザーID % が見つかりません', p_user_id;
    END IF;
    
    UPDATE m_user SET deleted_at = CURRENT_TIMESTAMP WHERE id = p_user_id;
    
    -- 監査ログ
    INSERT INTO t_audit_log (operation_type, table_name, record_id, old_values, new_values, user_name)
    VALUES ('SOFT_DELETE', 'm_user', p_user_id,
            jsonb_build_object('status', old_status),
            jsonb_build_object('deleted_at', CURRENT_TIMESTAMP),
            p_operator);
    
    RAISE NOTICE 'ユーザーID % を論理削除しました', p_user_id;
END;
$$;

-- ユーザー検索（フィルタ・ページング対応）
CREATE OR REPLACE FUNCTION search_users(
    p_name TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
    id INTEGER,
    name TEXT,
    status TEXT,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP,
    deleted_at TIMESTAMP
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT id, name, status, last_login_at, created_at, deleted_at
    FROM m_user
    WHERE (p_name IS NULL OR name ILIKE '%' || p_name || '%')
      AND (p_status IS NULL OR status = p_status)
      AND deleted_at IS NULL
    ORDER BY id
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ユーザーの最終操作履歴取得
CREATE OR REPLACE FUNCTION get_user_last_audit_log(
    p_user_id INTEGER
) RETURNS TABLE(
    log_id INTEGER,
    operation_type TEXT,
    table_name TEXT,
    record_id INTEGER,
    old_values JSONB,
    new_values JSONB,
    user_name TEXT,
    created_at TIMESTAMP,
    ip_address INET
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT id, operation_type, table_name, record_id, old_values, new_values, user_name, created_at, ip_address
    FROM t_audit_log
    WHERE record_id = p_user_id AND table_name = 'm_user'
    ORDER BY created_at DESC
    LIMIT 1;
END;
$$;

-- エラー履歴の詳細取得
CREATE OR REPLACE FUNCTION get_recent_errors(
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE(
    error_id INTEGER,
    created_at TIMESTAMP,
    message TEXT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT id, created_at, message
    FROM t_error
    ORDER BY created_at DESC
    LIMIT p_limit;
END;
$$;

-- ユーザーID=1の最終操作履歴
SELECT * FROM get_user_last_audit_log(1);

-- 直近5件のエラー履歴
SELECT * FROM get_recent_errors(5);

-- ユーザー一括ステータス変更
CREATE OR REPLACE PROCEDURE bulk_update_user_status(
    p_old_status TEXT,
    p_new_status TEXT,
    p_operator TEXT DEFAULT current_user
)
LANGUAGE plpgsql
AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE m_user 
    SET status = p_new_status 
    WHERE status = p_old_status AND deleted_at IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    -- 監査ログ
    INSERT INTO t_audit_log (operation_type, table_name, old_values, new_values, user_name)
    VALUES ('BULK_UPDATE', 'm_user', 
            jsonb_build_object('old_status', p_old_status, 'count', updated_count),
            jsonb_build_object('new_status', p_new_status, 'count', updated_count),
            p_operator);
    
    RAISE NOTICE 'ステータス "%" から "%" に % 件のユーザーを一括変更しました', p_old_status, p_new_status, updated_count;
END;
$$;

-- 履歴のCSVエクスポート（PostgreSQLのCOPY機能を使用）
CREATE OR REPLACE PROCEDURE export_audit_log_csv(
    p_file_path TEXT DEFAULT '/tmp/audit_log.csv'
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- CSVファイルにエクスポート
    EXECUTE format('COPY (
        SELECT 
            id,
            operation_type,
            table_name,
            record_id,
            old_values::text,
            new_values::text,
            user_name,
            created_at,
            ip_address
        FROM t_audit_log 
        ORDER BY created_at DESC
    ) TO %L WITH CSV HEADER', p_file_path);
    
    RAISE NOTICE '監査ログを % にエクスポートしました', p_file_path;
END;
$$;

-- ユーザー統計レポート（詳細版）
CREATE OR REPLACE FUNCTION generate_user_report()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    report JSONB;
    total_users INTEGER;
    active_users INTEGER;
    inactive_users INTEGER;
    deleted_users INTEGER;
    recent_users INTEGER;
    avg_age_days NUMERIC;
BEGIN
    -- 基本統計
    SELECT COUNT(*) INTO total_users FROM m_user;
    SELECT COUNT(*) INTO active_users FROM m_user WHERE status = 'active' AND deleted_at IS NULL;
    SELECT COUNT(*) INTO inactive_users FROM m_user WHERE status = 'inactive' AND deleted_at IS NULL;
    SELECT COUNT(*) INTO deleted_users FROM m_user WHERE deleted_at IS NOT NULL;
    SELECT COUNT(*) INTO recent_users FROM m_user WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '7 days';
    
    -- 平均ユーザー年齢（作成からの日数）
    SELECT AVG(EXTRACT(DAY FROM (CURRENT_TIMESTAMP - created_at))) INTO avg_age_days FROM m_user WHERE deleted_at IS NULL;
    
    -- レポート作成
    report := jsonb_build_object(
        'report_date', CURRENT_TIMESTAMP,
        'summary', jsonb_build_object(
            'total_users', total_users,
            'active_users', active_users,
            'inactive_users', inactive_users,
            'deleted_users', deleted_users,
            'recent_users_7days', recent_users,
            'avg_user_age_days', ROUND(COALESCE(avg_age_days, 0), 1)
        ),
        'status_distribution', (
            SELECT jsonb_object_agg(status, count)
            FROM (
                SELECT status, COUNT(*) as count
                FROM m_user 
                WHERE deleted_at IS NULL
                GROUP BY status
            ) status_counts
        ),
        'recent_activity', (
            SELECT jsonb_agg(jsonb_build_object(
                'operation_type', operation_type,
                'count', count
            ))
            FROM (
                SELECT operation_type, COUNT(*) as count
                FROM t_audit_log
                WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '24 hours'
                GROUP BY operation_type
                ORDER BY count DESC
            ) recent_ops
        )
    );
    
    RETURN report;
END;
$$;

-- バックアップ・リストア支援機能
CREATE OR REPLACE PROCEDURE prepare_system_backup()
LANGUAGE plpgsql
AS $$
BEGIN
    -- メンテナンスモードを有効化
    CALL update_config('system_maintenance_mode', 'true', 'バックアップ準備中');
    
    -- 未完了のトランザクションを待機
    PERFORM pg_sleep(2);
    
    -- 統計情報を更新
    ANALYZE m_user;
    ANALYZE t_error;
    ANALYZE t_audit_log;
    ANALYZE t_config;
    
    -- バックアップ前の最終チェック
    PERFORM notify_admin('バックアップ準備完了: ' || current_database());
    
    RAISE NOTICE 'バックアップ準備が完了しました。pg_dumpを実行してください。';
    RAISE NOTICE 'バックアップ完了後、CALL post_backup_cleanup()を実行してください。';
END;
$$;

-- バックアップ後のクリーンアップ
CREATE OR REPLACE PROCEDURE post_backup_cleanup()
LANGUAGE plpgsql
AS $$
BEGIN
    -- メンテナンスモードを無効化
    CALL update_config('system_maintenance_mode', 'false', 'バックアップ完了');
    
    -- 統計情報を更新
    ANALYZE;
    
    -- インデックスの再構築（手動実行を案内）
    RAISE NOTICE 'インデックス再構築を実行してください:';
    RAISE NOTICE 'REINDEX DATABASE %;', current_database();
    
    PERFORM notify_admin('バックアップ完了: ' || current_database());
    
    RAISE NOTICE 'バックアップ後のクリーンアップが完了しました';
END;
$$;

-- システムヘルスチェック（詳細版）
CREATE OR REPLACE FUNCTION detailed_health_check()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    health_status JSONB;
    db_size BIGINT;
    connection_count INTEGER;
    maintenance_mode TEXT;
    error_count_24h INTEGER;
    audit_count_24h INTEGER;
BEGIN
    -- 基本情報
    SELECT pg_database_size(current_database()) INTO db_size;
    SELECT count(*) INTO connection_count FROM pg_stat_activity;
    SELECT config_value INTO maintenance_mode FROM t_config WHERE config_key = 'system_maintenance_mode';
    
    -- 24時間の統計
    SELECT COUNT(*) INTO error_count_24h FROM t_error WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '24 hours';
    SELECT COUNT(*) INTO audit_count_24h FROM t_audit_log WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '24 hours';
    
    -- ヘルスチェック結果
    health_status := jsonb_build_object(
        'status', CASE 
            WHEN maintenance_mode = 'true' THEN 'maintenance'
            WHEN error_count_24h > 100 THEN 'warning'
            ELSE 'healthy'
        END,
        'timestamp', CURRENT_TIMESTAMP,
        'database_info', jsonb_build_object(
            'name', current_database(),
            'size_mb', ROUND(db_size / 1024.0 / 1024.0, 2),
            'active_connections', connection_count
        ),
        'maintenance_mode', maintenance_mode = 'true',
        'table_stats', jsonb_build_object(
            'm_user', (SELECT COUNT(*) FROM m_user),
            't_error', (SELECT COUNT(*) FROM t_error),
            't_audit_log', (SELECT COUNT(*) FROM t_audit_log),
            't_config', (SELECT COUNT(*) FROM t_config)
        ),
        'activity_24h', jsonb_build_object(
            'errors', error_count_24h,
            'audit_logs', audit_count_24h
        ),
        'recommendations', CASE 
            WHEN error_count_24h > 100 THEN jsonb_build_array('エラーが多発しています。ログを確認してください。')
            WHEN maintenance_mode = 'true' THEN jsonb_build_array('メンテナンスモード中です。')
            ELSE jsonb_build_array('システムは正常です。')
        END
    );
    
    RETURN health_status;
END;
$$; 