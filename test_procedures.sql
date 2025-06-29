-- PostgreSQLプロシージャのテスト実行

-- 1. 基本的なプロシージャのテスト
CALL get_user_info(1);

-- 2. ユーザー作成のテスト
CALL create_user('TestUser1', 'active');
CALL create_user('TestUser2', 'inactive');

-- 3. アクティブユーザー数の取得
SELECT get_active_user_count() as active_users;

-- 4. ユーザー統計の取得
CALL get_user_statistics();

-- 5. 複数ユーザーの一括作成
CALL create_multiple_users(ARRAY['UserA', 'UserB', 'UserC']);

-- 6. フィボナッチ数列の計算
SELECT fibonacci(10) as fibonacci_10;

-- 7. テーブル情報の取得
CALL get_table_info('m_user');

-- 8. 全ユーザーの処理
CALL process_all_users();

-- 9. クリーンアップ処理
CALL cleanup_old_records();

-- 10. 最終的なユーザー一覧を表示
SELECT id, name, status, last_login_at FROM m_user ORDER BY id; 