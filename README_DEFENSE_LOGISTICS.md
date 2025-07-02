# 防衛省ロジスティクス基盤システム
## Defense Logistics Infrastructure System

### 概要
防衛省のロジスティクス基盤再構築プロジェクト用の包括的なデータベースシステムです。セキュリティ要件とロジスティクス特有の機能を備えたPostgreSQLプロシージャーセットを提供します。

### 主な機能

#### 1. セキュリティ管理
- **セキュリティレベル管理**: 一般、機密、極秘、最重要機密の4段階
- **セキュリティ監査ログ**: すべての操作を記録・追跡
- **アクセス制御**: セキュリティレベルに基づくデータアクセス制限

#### 2. ロジスティクス資材管理
- **資材登録・更新・削除**: 完全なライフサイクル管理
- **在庫監視**: 最小・最大在庫レベルの自動監視
- **在庫不足アラート**: 自動通知機能

#### 3. 輸送管理
- **輸送オーダー作成**: 優先度付きオーダー管理
- **在庫自動更新**: オーダー作成時の在庫自動調整
- **輸送効率分析**: ルート別の効率性分析

#### 4. 緊急事態管理
- **緊急事態報告**: 重大度レベル1-5の分類
- **自動アラート**: 重大度レベル4-5の自動通知
- **対応チーム管理**: 緊急対応チームの割り当て

#### 5. システム監視
- **ヘルスチェック**: システム全体の健全性監視
- **パフォーマンス監視**: 応答時間・エラー率の監視
- **自動メンテナンス**: 古いログの自動クリーンアップ

### ファイル構成

```
devlop/
├── defense_logistics_setup.sql      # セットアップスクリプト
├── defense_logistics_test.sql       # テストスクリプト
├── defense_logistics_run.bat        # 実行バッチファイル
├── docker-compose-postgres.yml      # Docker Compose設定
├── defence_logistics/
│   └── postgresql_procedures.sql    # 基本プロシージャー
└── README_DEFENSE_LOGISTICS.md      # このファイル
```

### セットアップ手順

#### 1. 前提条件
- Docker Desktop
- Windows 10/11
- 管理者権限

#### 2. 実行手順

```bash
# 1. ディレクトリに移動
cd devlop

# 2. バッチファイルを実行
defense_logistics_run.bat
```

#### 3. 手動実行（オプション）

```bash
# PostgreSQLコンテナの起動
docker-compose -f docker-compose-postgres.yml up -d

# セットアップスクリプトの実行
docker exec -i postgres_procedures psql -U postgres -d postgres -f /tmp/defense_logistics_setup.sql

# テストスクリプトの実行
docker exec -i postgres_procedures psql -U postgres -d postgres -f /tmp/defense_logistics_test.sql
```

### データベース構造

#### 主要テーブル

1. **security_levels** - セキュリティレベル管理
2. **logistics_materials** - ロジスティクス資材
3. **transportation_orders** - 輸送オーダー
4. **emergency_incidents** - 緊急事態管理
5. **security_audit_logs** - セキュリティ監査ログ

#### 主要プロシージャー

1. **create_defense_user()** - セキュリティ強化ユーザー作成
2. **manage_logistics_material()** - 資材管理
3. **create_transportation_order()** - 輸送オーダー作成
4. **report_emergency_incident()** - 緊急事態報告
5. **monitor_inventory_levels()** - 在庫監視
6. **defense_system_health_check()** - システムヘルスチェック

### 使用例

#### 1. セキュリティ強化ユーザー作成
```sql
SELECT create_defense_user(
    'defense_admin',
    'admin@defense.gov.jp',
    '防衛省管理者',
    'ロジスティクス部',
    '極秘',
    '課長',
    '03-1234-5678',
    1
);
```

#### 2. 資材管理
```sql
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
);

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
);
```

#### 3. 輸送オーダー作成
```sql
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
);
```

#### 4. 緊急事態報告
```sql
SELECT report_emergency_incident(
    '燃料漏洩',
    4, -- 重大度レベル4
    '東京基地 燃料タンクA',
    '燃料タンクから軽油が漏洩している。緊急対応が必要。',
    'MAT001: 燃料（軽油）',
    '緊急対応チームA',
    1
);
```

#### 5. システム監視
```sql
-- 在庫監視
SELECT * FROM monitor_inventory_levels();

-- システムヘルスチェック
SELECT * FROM defense_system_health_check();

-- セキュリティ監査レポート
SELECT * FROM generate_security_audit_report(
    CURRENT_DATE - INTERVAL '7 days',
    CURRENT_DATE,
    '極秘'
);
```

### セキュリティ機能

#### 1. セキュリティレベル
- **一般**: 一般職員向け
- **機密**: 機密情報取扱者向け
- **極秘**: 極秘情報取扱者向け
- **最重要機密**: 最重要機密情報取扱者向け

#### 2. 監査ログ
- すべての操作を記録
- ユーザー、IPアドレス、タイムスタンプを記録
- 古いログの自動クリーンアップ

#### 3. データエクスポート
- セキュリティレベルに基づく制限
- エクスポート履歴の記録
- CSV形式での安全なエクスポート

### 運用管理

#### 1. 定期メンテナンス
```sql
-- 自動メンテナンス実行
SELECT auto_maintenance_defense_system();
```

#### 2. バックアップ準備
```sql
-- バックアップ前の準備
CALL prepare_system_backup();

-- バックアップ後のクリーンアップ
CALL post_backup_cleanup();
```

#### 3. パフォーマンス監視
```sql
-- パフォーマンス監視
CALL monitor_performance();

-- 詳細ヘルスチェック
SELECT detailed_health_check();
```

### トラブルシューティング

#### 1. よくある問題

**Q: PostgreSQLコンテナが起動しない**
A: ポート5433が使用中の場合、docker-compose-postgres.ymlでポートを変更してください。

**Q: プロシージャーが実行できない**
A: セットアップスクリプトが正常に実行されているか確認してください。

**Q: セキュリティエラーが発生する**
A: セキュリティレベルが正しく設定されているか確認してください。

#### 2. ログ確認
```bash
# コンテナログの確認
docker logs postgres_procedures

# セキュリティ監査ログの確認
docker exec -i postgres_procedures psql -U postgres -d postgres -c "SELECT * FROM security_audit_logs ORDER BY timestamp DESC LIMIT 10;"
```

### 開発・カスタマイズ

#### 1. 新しいプロシージャーの追加
1. `defense_logistics_setup.sql`にプロシージャーを追加
2. `defense_logistics_test.sql`にテストケースを追加
3. セットアップスクリプトを再実行

#### 2. テーブル構造の変更
1. セキュリティ監査ログの記録を追加
2. インデックスの更新
3. 既存データの移行

### ライセンス
このシステムは防衛省のロジスティクス基盤再構築プロジェクト用に開発されました。

### サポート
技術的な問題や質問がある場合は、開発チームまでお問い合わせください。

---

**注意**: このシステムは防衛省のセキュリティ要件に準拠して設計されています。運用時は適切なセキュリティ対策を実施してください。 