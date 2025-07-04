# 防衛省ロジスティクスシステム

## 📋 システム概要

防衛省ロジスティクスシステムは、防衛省の機密情報を扱うロジスティクス管理システムです。PostgreSQL 15とPL/pgSQLを使用し、3段階のセキュリティレベルによる厳格なアクセス制御を実装しています。

### 🎯 主要機能
- **ユーザー管理**: セキュリティレベル付きユーザー管理
- **材料管理**: 在庫監視とアラート機能
- **輸送管理**: 輸送オーダー作成と追跡
- **緊急事態管理**: 緊急事態報告とエスカレーション
- **セキュリティ**: アクセス制御と監査ログ
- **システム監視**: パフォーマンス監視とヘルスチェック

## 🚀 クイックスタート

### 前提条件
- Docker と Docker Compose がインストール済み
- Windows 10/11 または Linux/macOS

### 1. システム起動
```bash
# システム起動スクリプトを実行
start_system.bat
```

### 2. データベース接続
```bash
# PostgreSQLに接続
docker exec -it postgres_procedures psql -U postgres -d defense_logistics
```

### 3. システム停止
```bash
# システム停止スクリプトを実行
stop_system.bat
```

## 📦 システム構成

### データベーステーブル (12テーブル)
- `users` - ユーザー管理
- `logistics_materials` - ロジスティクス材料管理
- `transport_orders` - 輸送オーダー管理
- `transport_tracking` - 輸送追跡
- `emergency_incidents` - 緊急事態管理
- `emergency_escalations` - 緊急事態エスカレーション
- `inventory_alerts` - 在庫アラート
- `audit_log` - 監査ログ
- `access_log` - アクセスログ
- `debug_log` - デバッグログ
- `daily_reports` - 日次レポート
- `system_backups` - システムバックアップ

### ストアドプロシージャ (30+個)

#### ユーザー管理
- `create_user_with_debug()` - ユーザー作成（デバッグ対応）
- `search_users_with_pagination()` - ユーザー検索（ページネーション）
- `delete_user_logical()` - ユーザー論理削除
- `get_last_audit_log_per_user()` - ユーザー別最終監査ログ取得

#### 材料管理
- `create_logistics_material_with_debug()` - 材料作成（デバッグ対応）
- `create_inventory_alert()` - 在庫アラート作成
- `auto_monitor_inventory()` - 自動在庫監視
- `export_materials_data()` - 材料データエクスポート

#### 輸送管理
- `create_transport_order_with_debug()` - 輸送オーダー作成（デバッグ対応）
- `update_transport_status()` - 輸送ステータス更新
- `track_transport_order()` - 輸送オーダー追跡

#### 緊急事態管理
- `report_emergency_incident_with_debug()` - 緊急事態報告（デバッグ対応）
- `escalate_emergency_incident()` - 緊急事態エスカレーション
- `get_recent_error_logs()` - 最近のエラーログ取得

#### セキュリティ
- `check_security_access()` - セキュリティアクセスチェック
- `bulk_update_user_status()` - ユーザーステータス一括更新
- `generate_user_report()` - ユーザーレポート生成

#### システム監視
- `monitor_system_performance()` - システムパフォーマンス監視
- `check_system_health()` - システムヘルスチェック
- `generate_daily_report()` - 日次レポート生成
- `create_system_backup()` - システムバックアップ作成
- `run_system_maintenance()` - システムメンテナンス実行

#### デバッグ・ログ管理
- `log_debug()` - デバッグログ記録
- `show_debug_log()` - デバッグログ表示
- `get_debug_statistics()` - デバッグ統計取得
- `show_procedure_debug_log()` - プロシージャ別デバッグログ
- `clear_debug_log()` - デバッグログクリア

## 🔐 セキュリティ機能

### セキュリティレベル
- **レベル1 (一般)**: 基本的な材料情報、一般公開可能な情報
- **レベル2 (機密)**: 詳細な材料情報、輸送情報、内部限定情報
- **レベル3 (極秘)**: 緊急事態情報、セキュリティ関連情報、最高機密情報

### アクセス制御
```sql
-- セキュリティアクセスチェック
SELECT check_security_access(ユーザーID, 必要レベル, 'アクション名');
```

### 監査ログ
全ての操作は自動的に監査ログに記録されます：
```sql
-- 監査ログ確認
SELECT * FROM show_recent_audit_logs(10);
```

## 📊 運用管理

### 日常運用

#### 日次作業
```sql
-- システムヘルスチェック
SELECT * FROM check_system_health();

-- 日次レポート生成
SELECT * FROM generate_daily_report();

-- アラート状況確認
SELECT * FROM inventory_alerts WHERE status = 'ACTIVE';
```

#### 週次作業
```sql
-- パフォーマンス監視
SELECT * FROM monitor_system_performance();

-- 監査ログ確認
SELECT * FROM show_recent_audit_logs(20);
```

#### 月次作業
```sql
-- システムメンテナンス
SELECT run_system_maintenance();

-- システムバックアップ
SELECT create_system_backup();
```

### トラブルシューティング

#### よくある問題と対処法

**1. データベース接続エラー**
```bash
# コンテナ再起動
docker-compose restart

# ログ確認
docker logs postgres_procedures
```

**2. プロシージャ実行エラー**
```sql
-- デバッグログ確認
SELECT * FROM show_debug_log(10);

-- エラーログ確認
SELECT * FROM show_error_logs(10);
```

**3. パフォーマンス問題**
```sql
-- パフォーマンス監視
SELECT * FROM monitor_system_performance();

-- システムヘルスチェック
SELECT * FROM check_system_health();
```

## 🛠️ 開発・カスタマイズ

### 新しいプロシージャの追加
```sql
-- デバッグログ付きプロシージャのテンプレート
CREATE OR REPLACE FUNCTION your_procedure_name(
    p_param1 VARCHAR(50),
    p_param2 INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_result INTEGER;
BEGIN
    -- デバッグログ開始
    PERFORM log_debug('your_procedure_name', 'START', 'プロシージャ開始');
    
    -- パラメータ確認
    PERFORM log_debug('your_procedure_name', 'PARAMS', 'パラメータ確認', 'param1', p_param1);
    
    -- 処理ロジック
    -- ...
    
    -- 監査ログ作成
    INSERT INTO audit_log (user_id, action, details, created_at)
    VALUES (1, 'YOUR_ACTION', '詳細説明', CURRENT_TIMESTAMP);
    
    PERFORM log_debug('your_procedure_name', 'END', 'プロシージャ完了');
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug('your_procedure_name', 'ERROR', 'エラーメッセージ', 'error_message', SQLERRM);
        RAISE;
END;
$$ LANGUAGE plpgsql;
```

### テスト実行
```sql
-- 包括的テスト実行
\i complete_final_test.sql

-- 特定機能テスト
\i test_enhanced_functions.sql
```

## 📚 ドキュメント

### 技術ドキュメント
- **運用マニュアル**: `operation_manual.md` - 日常運用の詳細手順
- **セキュリティガイド**: `security_guide.md` - セキュリティポリシーと手順
- **技術仕様書**: `technical_spec.md` - システムアーキテクチャと設計詳細
- **デプロイレポート**: `system_deployment_report.md` - システムデプロイ完了レポート

### スクリプトファイル
- **システム起動**: `start_system.bat` - システム起動スクリプト
- **システム停止**: `stop_system.bat` - システム停止スクリプト
- **Docker設定**: `docker-compose.yml` - Docker Compose設定

## 🔧 設定・カスタマイズ

### 環境変数
```yaml
# docker-compose.yml
environment:
  POSTGRES_DB: defense_logistics
  POSTGRES_USER: postgres
  POSTGRES_PASSWORD: postgres
```

### ポート設定
```yaml
# デフォルト: 5432
ports:
  - "5432:5432"
```

### データ永続化
```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data
```

## 📞 サポート

### 緊急時連絡先
- **システム障害**: admin@defense.gov.jp
- **セキュリティ問題**: security@defense.gov.jp

### 通常時
- **技術サポート**: tech-support@defense.gov.jp
- **運用サポート**: operation-support@defense.gov.jp

## 📈 システム統計

### 現在の状況
- **総ユーザー数**: 3名
- **総材料数**: 9種類
- **アクティブ輸送オーダー**: 1件
- **アクティブ緊急事態**: 2件
- **アクティブアラート**: 4件
- **総監査ログ**: 34件
- **総デバッグログ**: 156件

### システム健全性
- ✅ **ユーザー管理**: 正常
- ✅ **材料管理**: 正常
- ✅ **輸送管理**: 正常
- ✅ **緊急事態管理**: 正常
- ✅ **監査機能**: 正常
- ✅ **デバッグ機能**: 正常

## 🎯 次のステップ

1. **運用チーム研修**: システム操作研修の実施
2. **セキュリティ監査**: 外部セキュリティ監査の実施
3. **パフォーマンス監視**: 本格運用開始後の監視強化
4. **機能拡張**: ユーザー要望に基づく機能追加

---

**システムバージョン**: 1.0.0  
**最終更新**: 2025年7月2日  
**ステータス**: 🟢 本格運用可能 