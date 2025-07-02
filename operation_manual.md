# 防衛省ロジスティクスシステム 運用マニュアル

## 📖 目次
1. [システム概要](#システム概要)
2. [日常運用](#日常運用)
3. [ユーザー管理](#ユーザー管理)
4. [材料管理](#材料管理)
5. [輸送管理](#輸送管理)
6. [緊急事態管理](#緊急事態管理)
7. [システム監視](#システム監視)
8. [トラブルシューティング](#トラブルシューティング)
9. [セキュリティガイドライン](#セキュリティガイドライン)

## 🏗️ システム概要

### システム構成
- **データベース**: PostgreSQL 15 (Docker)
- **言語**: PL/pgSQL
- **セキュリティレベル**: 3段階 (1: 一般, 2: 機密, 3: 極秘)

### 主要テーブル
- `users` - ユーザー管理
- `logistics_materials` - 材料管理
- `transport_orders` - 輸送オーダー
- `emergency_incidents` - 緊急事態
- `audit_log` - 監査ログ
- `debug_log` - デバッグログ

## 🔄 日常運用

### 日次作業

#### 1. システムヘルスチェック
```sql
-- システム全体の健全性確認
SELECT * FROM check_system_health();
```

**期待される結果**:
- database: HEALTHY
- user_management: HEALTHY
- material_management: HEALTHY
- transport_management: HEALTHY
- emergency_management: HEALTHY

#### 2. 日次レポート確認
```sql
-- 日次レポート生成・確認
SELECT * FROM generate_daily_report();
```

**確認項目**:
- 総ユーザー数
- 総材料数
- アクティブ輸送オーダー数
- アクティブ緊急事態数
- 低在庫材料数

#### 3. アラート状況確認
```sql
-- アクティブなアラート確認
SELECT 
    ia.id,
    lm.material_name,
    ia.alert_type,
    ia.priority,
    ia.status,
    ia.created_at
FROM inventory_alerts ia
JOIN logistics_materials lm ON ia.material_id = lm.id
WHERE ia.status = 'ACTIVE'
ORDER BY ia.created_at DESC;
```

#### 4. 緊急事態状況確認
```sql
-- アクティブな緊急事態確認
SELECT 
    id,
    incident_type,
    location,
    severity,
    status,
    created_at
FROM emergency_incidents
WHERE status = 'ACTIVE'
ORDER BY created_at DESC;
```

### 週次作業

#### 1. パフォーマンス監視
```sql
-- システムパフォーマンス確認
SELECT * FROM monitor_system_performance();
```

#### 2. 監査ログ確認
```sql
-- 最新の監査ログ確認
SELECT * FROM show_recent_audit_logs(20);
```

#### 3. セキュリティログ確認
```sql
-- アクセスログ確認
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
ORDER BY al.created_at DESC
LIMIT 20;
```

### 月次作業

#### 1. システムメンテナンス
```sql
-- 自動メンテナンス実行
SELECT run_system_maintenance();
```

#### 2. システムバックアップ
```sql
-- システムバックアップ作成
SELECT create_system_backup();
```

## 👥 ユーザー管理

### 新規ユーザー作成
```sql
-- 基本ユーザー作成
SELECT create_user_with_debug(
    'username',           -- ユーザー名
    'email@defense.gov.jp', -- メールアドレス
    '氏名',               -- フルネーム
    '部署名',             -- 部署
    2                     -- セキュリティレベル (1-3)
);
```

### ユーザー検索
```sql
-- ユーザー検索（フィルタリング・ページネーション）
SELECT * FROM search_users_with_pagination(
    '検索キーワード',  -- 検索キーワード
    'IT部門',          -- 部署フィルタ
    2,                 -- セキュリティレベルフィルタ
    1,                 -- ページ番号
    10                 -- 1ページあたりの件数
);
```

### ユーザー論理削除
```sql
-- ユーザーの論理削除
SELECT delete_user_logical(ユーザーID);
```

## 📦 材料管理

### 新規材料登録
```sql
-- 材料登録
SELECT create_logistics_material_with_debug(
    'MAT-001',        -- 材料コード
    '材料名',         -- 材料名
    'カテゴリ',       -- カテゴリ
    100,              -- 数量
    '個',             -- 単位
    2,                -- セキュリティレベル
    '倉庫A-1F'        -- 保管場所
);
```

### 在庫監視
```sql
-- 自動在庫監視実行
SELECT auto_monitor_inventory();
```

### 材料検索
```sql
-- 材料一覧表示
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
```

## 🚚 輸送管理

### 輸送オーダー作成
```sql
-- 輸送オーダー作成
SELECT create_transport_order_with_debug(
    'ORDER-001',           -- オーダー番号
    '出発地',              -- 出発地
    '目的地',              -- 目的地
    'HIGH',                -- 優先度 (LOW/MEDIUM/HIGH)
    2,                     -- セキュリティレベル
    CURRENT_DATE + 7       -- 配達予定日
);
```

### 輸送追跡
```sql
-- 輸送ステータス更新
SELECT update_transport_status(
    オーダーID,
    'IN_TRANSIT',          -- ステータス
    '現在地',              -- 現在地
    '備考'                 -- 備考
);
```

### 輸送状況確認
```sql
-- 輸送追跡状況確認
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
```

## 🚨 緊急事態管理

### 緊急事態報告
```sql
-- 緊急事態報告
SELECT * FROM report_emergency_incident_with_debug(
    '事態種別',            -- 事態種別
    '発生場所',            -- 発生場所
    'HIGH',                -- 深刻度 (LOW/MEDIUM/HIGH/CRITICAL)
    '詳細説明',            -- 詳細説明
    報告者ID,              -- 報告者ID
    2                      -- セキュリティレベル
);
```

### 緊急事態エスカレーション
```sql
-- 緊急事態エスカレーション
SELECT escalate_emergency_incident(事態ID, エスカレーションレベル);
```

### 緊急事態状況確認
```sql
-- 緊急事態一覧確認
SELECT 
    id,
    incident_type,
    location,
    severity,
    status,
    created_at
FROM emergency_incidents
ORDER BY created_at DESC;
```

## 📊 システム監視

### システム統計確認
```sql
-- システム全体統計
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
WHERE status = 'ACTIVE';
```

### デバッグログ確認
```sql
-- デバッグログ表示
SELECT * FROM show_debug_log(10);

-- 特定プロシージャのデバッグログ
SELECT * FROM show_procedure_debug_log('プロシージャ名', 5);

-- デバッグ統計
SELECT * FROM get_debug_statistics();
```

## 🔧 トラブルシューティング

### よくある問題と対処法

#### 1. データベース接続エラー
**症状**: プロシージャ実行時に接続エラー
**対処法**:
```bash
# Docker コンテナ再起動
docker-compose restart

# ログ確認
docker logs postgres_procedures
```

#### 2. プロシージャ実行エラー
**症状**: プロシージャ実行時にエラー
**対処法**:
```sql
-- デバッグログ確認
SELECT * FROM show_debug_log(10);

-- エラーログ確認
SELECT * FROM show_error_logs(10);
```

#### 3. パフォーマンス問題
**症状**: クエリ実行が遅い
**対処法**:
```sql
-- パフォーマンス監視
SELECT * FROM monitor_system_performance();

-- システムヘルスチェック
SELECT * FROM check_system_health();
```

#### 4. セキュリティアクセスエラー
**症状**: アクセス権限エラー
**対処法**:
```sql
-- ユーザーのセキュリティレベル確認
SELECT username, security_level FROM users WHERE id = ユーザーID;

-- アクセスログ確認
SELECT * FROM access_log WHERE user_id = ユーザーID ORDER BY created_at DESC;
```

## 🔐 セキュリティガイドライン

### セキュリティレベル
- **レベル1**: 一般情報 - 基本的な材料情報
- **レベル2**: 機密情報 - 詳細な材料情報、輸送情報
- **レベル3**: 極秘情報 - 緊急事態、セキュリティ関連情報

### アクセス制御
```sql
-- セキュリティアクセスチェック
SELECT check_security_access(ユーザーID, 必要レベル, 'アクション名');
```

### 監査ログ
- 全ての操作は自動的に監査ログに記録されます
- 監査ログは削除できません
- 定期的に監査ログを確認してください

### パスワード管理
- 強力なパスワードを使用
- 定期的なパスワード変更
- パスワードの共有禁止

## 📞 サポート連絡先

### 緊急時
- **システム障害**: admin@defense.gov.jp
- **セキュリティ問題**: security@defense.gov.jp

### 通常時
- **技術サポート**: tech-support@defense.gov.jp
- **運用サポート**: operation-support@defense.gov.jp

---

**最終更新**: 2025年7月2日  
**バージョン**: 1.0.0 