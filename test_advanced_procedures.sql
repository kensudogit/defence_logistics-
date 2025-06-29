-- 実用性向上版プロシージャのテスト実行

-- 1. 監査ログ付きユーザー作成のテスト
CALL create_user_with_audit('AdvancedUser1', 'active', 'user1@example.com');
CALL create_user_with_audit('AdvancedUser2', 'inactive', 'user2@example.com');

-- 2. バッチユーザー作成のテスト
CALL create_users_batch('[
    {"name": "BatchUser1", "status": "active"},
    {"name": "BatchUser2", "status": "inactive"},
    {"name": "BatchUser3", "status": "active"}
]'::jsonb);

-- 3. データ検証のテスト
SELECT validate_user_data('ValidUser', 'active') as valid_user;
SELECT validate_user_data('', 'active') as empty_name;
SELECT validate_user_data('VeryLongUserNameThatExceedsTheMaximumAllowedLengthOfOneHundredCharactersAndShouldFailValidation', 'active') as long_name;
SELECT validate_user_data('ValidUser', 'invalid_status') as invalid_status;

-- 4. パフォーマンス監視のテスト
CALL monitor_performance();

-- 5. 設定管理のテスト
CALL update_config('test_setting', 'test_value', 'テスト用設定');
CALL update_config('max_users_per_batch', '50', 'バッチサイズを50に変更');

-- 6. ヘルスチェックのテスト
SELECT health_check();

-- 7. データエクスポートのテスト
CALL export_user_data('json', 'active');

-- 8. 自動メンテナンスのテスト
CALL auto_maintenance();

-- 9. バックアップ準備のテスト
CALL prepare_backup();

-- 10. 復旧後のクリーンアップのテスト
CALL post_restore_cleanup();

-- 11. 監査ログの確認
SELECT operation_type, table_name, record_id, created_at 
FROM t_audit_log 
ORDER BY created_at DESC 
LIMIT 10;

-- 12. 設定テーブルの確認
SELECT * FROM t_config;

-- 13. 最終的なユーザー統計
CALL get_user_statistics();

-- 14. エラーログの確認
SELECT created_at, message FROM t_error ORDER BY created_at DESC LIMIT 5; 