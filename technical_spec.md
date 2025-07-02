# 防衛省ロジスティクスシステム 技術仕様書

## 🏗️ システムアーキテクチャ

### 全体構成
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   クライアント   │    │   API Gateway   │    │   PostgreSQL    │
│   (Web/Mobile)  │◄──►│   (Future)      │◄──►│   Database      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Monitoring    │
                       │   & Logging     │
                       └─────────────────┘
```

### データベース構成
- **エンジン**: PostgreSQL 15
- **コンテナ**: Docker
- **文字エンコーディング**: UTF-8
- **タイムゾーン**: UTC
- **接続方式**: TCP/IP over Docker

## 📊 データベース設計

### テーブル一覧

#### 1. ユーザー管理テーブル
```sql
-- users テーブル
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    department VARCHAR(100),
    security_level INTEGER CHECK (security_level BETWEEN 1 AND 3),
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 2. ロジスティクス材料テーブル
```sql
-- logistics_materials テーブル
CREATE TABLE logistics_materials (
    id SERIAL PRIMARY KEY,
    material_code VARCHAR(50) UNIQUE NOT NULL,
    material_name VARCHAR(100) NOT NULL,
    category VARCHAR(100),
    quantity INTEGER DEFAULT 0,
    unit VARCHAR(20),
    security_level INTEGER CHECK (security_level BETWEEN 1 AND 3),
    location VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 3. 輸送オーダーテーブル
```sql
-- transport_orders テーブル
CREATE TABLE transport_orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    origin_location VARCHAR(100) NOT NULL,
    destination_location VARCHAR(100) NOT NULL,
    priority VARCHAR(20) CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')),
    security_level INTEGER CHECK (security_level BETWEEN 1 AND 3),
    expected_delivery_date DATE,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 4. 緊急事態テーブル
```sql
-- emergency_incidents テーブル
CREATE TABLE emergency_incidents (
    id SERIAL PRIMARY KEY,
    incident_type VARCHAR(100) NOT NULL,
    location VARCHAR(100) NOT NULL,
    severity VARCHAR(20) CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    description TEXT,
    reported_by INTEGER REFERENCES users(id),
    security_level INTEGER CHECK (security_level BETWEEN 1 AND 3),
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 5. 監査ログテーブル
```sql
-- audit_log テーブル
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 6. デバッグログテーブル
```sql
-- debug_log テーブル
CREATE TABLE debug_log (
    id SERIAL PRIMARY KEY,
    procedure_name VARCHAR(100) NOT NULL,
    step_name VARCHAR(50) NOT NULL,
    message TEXT,
    variable_name VARCHAR(50),
    variable_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### インデックス設計

#### パフォーマンス最適化インデックス
```sql
-- ユーザー検索用インデックス
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_security_level ON users(security_level);
CREATE INDEX idx_users_deleted ON users(deleted);

-- 材料検索用インデックス
CREATE INDEX idx_materials_code ON logistics_materials(material_code);
CREATE INDEX idx_materials_category ON logistics_materials(category);
CREATE INDEX idx_materials_security_level ON logistics_materials(security_level);

-- 輸送オーダー検索用インデックス
CREATE INDEX idx_orders_number ON transport_orders(order_number);
CREATE INDEX idx_orders_status ON transport_orders(status);
CREATE INDEX idx_orders_priority ON transport_orders(priority);

-- 監査ログ検索用インデックス
CREATE INDEX idx_audit_user_id ON audit_log(user_id);
CREATE INDEX idx_audit_created_at ON audit_log(created_at);
CREATE INDEX idx_audit_action ON audit_log(action);

-- デバッグログ検索用インデックス
CREATE INDEX idx_debug_procedure ON debug_log(procedure_name);
CREATE INDEX idx_debug_created_at ON debug_log(created_at);
```

## 🔧 ストアドプロシージャ設計

### プロシージャ分類

#### 1. ユーザー管理プロシージャ
- `create_user_with_debug()` - ユーザー作成（デバッグ対応）
- `search_users_with_pagination()` - ユーザー検索（ページネーション）
- `delete_user_logical()` - ユーザー論理削除
- `get_last_audit_log_per_user()` - ユーザー別最終監査ログ取得

#### 2. 材料管理プロシージャ
- `create_logistics_material_with_debug()` - 材料作成（デバッグ対応）
- `create_inventory_alert()` - 在庫アラート作成
- `auto_monitor_inventory()` - 自動在庫監視
- `export_materials_data()` - 材料データエクスポート

#### 3. 輸送管理プロシージャ
- `create_transport_order_with_debug()` - 輸送オーダー作成（デバッグ対応）
- `update_transport_status()` - 輸送ステータス更新
- `track_transport_order()` - 輸送オーダー追跡

#### 4. 緊急事態管理プロシージャ
- `report_emergency_incident_with_debug()` - 緊急事態報告（デバッグ対応）
- `escalate_emergency_incident()` - 緊急事態エスカレーション
- `get_recent_error_logs()` - 最近のエラーログ取得

#### 5. セキュリティプロシージャ
- `check_security_access()` - セキュリティアクセスチェック
- `bulk_update_user_status()` - ユーザーステータス一括更新
- `generate_user_report()` - ユーザーレポート生成

#### 6. システム監視プロシージャ
- `monitor_system_performance()` - システムパフォーマンス監視
- `check_system_health()` - システムヘルスチェック
- `generate_daily_report()` - 日次レポート生成
- `create_system_backup()` - システムバックアップ作成
- `run_system_maintenance()` - システムメンテナンス実行

#### 7. デバッグ・ログ管理プロシージャ
- `log_debug()` - デバッグログ記録
- `show_debug_log()` - デバッグログ表示
- `get_debug_statistics()` - デバッグ統計取得
- `show_procedure_debug_log()` - プロシージャ別デバッグログ
- `clear_debug_log()` - デバッグログクリア

### プロシージャ設計原則

#### 1. エラーハンドリング
```sql
-- 標準エラーハンドリングパターン
EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_debug(procedure_name, 'ERROR', 'エラーメッセージ', 'error_message', SQLERRM);
        RAISE;
```

#### 2. デバッグログ
```sql
-- 標準デバッグログパターン
PERFORM log_debug(procedure_name, 'START', 'プロシージャ開始');
PERFORM log_debug(procedure_name, 'PARAMS', 'パラメータ確認', 'param_name', param_value);
PERFORM log_debug(procedure_name, 'END', 'プロシージャ完了');
```

#### 3. 監査ログ
```sql
-- 標準監査ログパターン
INSERT INTO audit_log (user_id, action, details, created_at)
VALUES (user_id, 'ACTION_NAME', '詳細説明', CURRENT_TIMESTAMP);
```

## 🔐 セキュリティ設計

### セキュリティレベル
- **レベル1**: 一般情報（基本的な材料情報）
- **レベル2**: 機密情報（詳細な材料情報、輸送情報）
- **レベル3**: 極秘情報（緊急事態、セキュリティ関連情報）

### アクセス制御
```sql
-- セキュリティアクセスチェック関数
CREATE OR REPLACE FUNCTION check_security_access(
    p_user_id INTEGER,
    p_required_level INTEGER,
    p_action VARCHAR(100)
) RETURNS BOOLEAN AS $$
DECLARE
    v_user_level INTEGER;
BEGIN
    -- ユーザーのセキュリティレベル取得
    SELECT security_level INTO v_user_level
    FROM users
    WHERE id = p_user_id AND deleted = FALSE;
    
    -- アクセス権限チェック
    IF v_user_level >= p_required_level THEN
        -- アクセス許可ログ
        INSERT INTO access_log (user_id, action, required_level, user_level, access_granted)
        VALUES (p_user_id, p_action, p_required_level, v_user_level, TRUE);
        RETURN TRUE;
    ELSE
        -- アクセス拒否ログ
        INSERT INTO access_log (user_id, action, required_level, user_level, access_granted)
        VALUES (p_user_id, p_action, p_required_level, v_user_level, FALSE);
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

## 📊 パフォーマンス設計

### クエリ最適化

#### 1. インデックス戦略
- 検索頻度の高いカラムにインデックス作成
- 複合インデックスによる検索効率化
- 部分インデックスによるストレージ効率化

#### 2. クエリ最適化
```sql
-- 効率的なページネーション
SELECT * FROM users
WHERE deleted = FALSE
ORDER BY id
LIMIT page_size OFFSET (page_number - 1) * page_size;

-- 効率的な集計クエリ
SELECT 
    COUNT(*) as total_count,
    COUNT(CASE WHEN status = 'ACTIVE' THEN 1 END) as active_count
FROM emergency_incidents;
```

### 監視・メトリクス

#### 1. パフォーマンス監視
```sql
-- システムパフォーマンス監視
CREATE OR REPLACE FUNCTION monitor_system_performance()
RETURNS TABLE (
    metric_name VARCHAR(50),
    metric_value NUMERIC,
    metric_unit VARCHAR(20),
    recorded_at TIMESTAMP WITHOUT TIME ZONE
) AS $$
```

#### 2. ヘルスチェック
```sql
-- システムヘルスチェック
CREATE OR REPLACE FUNCTION check_system_health()
RETURNS TABLE (
    component VARCHAR(50),
    status VARCHAR(20),
    message TEXT,
    last_check TIMESTAMP WITHOUT TIME ZONE
) AS $$
```

## 🔄 バックアップ・復旧設計

### バックアップ戦略

#### 1. 自動バックアップ
```sql
-- システムバックアップ作成
CREATE OR REPLACE FUNCTION create_system_backup()
RETURNS VARCHAR(100) AS $$
DECLARE
    v_backup_id VARCHAR(100);
BEGIN
    v_backup_id := 'BACKUP_' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    
    INSERT INTO system_backups (backup_id, created_at, status)
    VALUES (v_backup_id, CURRENT_TIMESTAMP, 'COMPLETED');
    
    RETURN v_backup_id;
END;
$$ LANGUAGE plpgsql;
```

#### 2. データエクスポート
```sql
-- 材料データエクスポート
CREATE OR REPLACE FUNCTION export_materials_data()
RETURNS TABLE (
    material_code VARCHAR(50),
    material_name VARCHAR(100),
    category VARCHAR(100),
    quantity INTEGER,
    unit VARCHAR(20),
    location VARCHAR(100)
) AS $$
```

## 🚀 デプロイメント設計

### Docker構成

#### docker-compose.yml
```yaml
version: '3.8'
services:
  postgres_procedures:
    image: postgres:15
    container_name: postgres_procedures
    environment:
      POSTGRES_DB: defense_logistics
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./sql:/docker-entrypoint-initdb.d
    restart: unless-stopped

volumes:
  postgres_data:
```

### 初期化スクリプト

#### 1. テーブル作成
```sql
-- create_tables.sql
-- 全テーブルの作成スクリプト
```

#### 2. プロシージャ作成
```sql
-- create_procedures.sql
-- 全ストアドプロシージャの作成スクリプト
```

#### 3. 初期データ投入
```sql
-- initial_data.sql
-- 初期データの投入スクリプト
```

## 📈 スケーラビリティ設計

### 水平スケーリング
- 読み取り専用レプリカの追加
- シャーディングによるデータ分散
- マイクロサービス化による機能分散

### 垂直スケーリング
- データベースリソースの増強
- インデックス最適化
- クエリ最適化

## 🔍 監視・ログ設計

### ログレベル
- **DEBUG**: デバッグ情報
- **INFO**: 一般情報
- **WARNING**: 警告
- **ERROR**: エラー
- **CRITICAL**: 重大エラー

### ログ出力
```sql
-- デバッグログ記録
CREATE OR REPLACE FUNCTION log_debug(
    p_procedure_name VARCHAR(100),
    p_step_name VARCHAR(50),
    p_message TEXT,
    p_variable_name VARCHAR(50) DEFAULT NULL,
    p_variable_value TEXT DEFAULT NULL
) RETURNS VOID AS $$
```

## 📋 テスト設計

### テスト分類

#### 1. 単体テスト
- プロシージャ個別テスト
- 関数個別テスト
- エラーハンドリングテスト

#### 2. 統合テスト
- プロシージャ間連携テスト
- データ整合性テスト
- セキュリティテスト

#### 3. パフォーマンステスト
- 負荷テスト
- ストレステスト
- スケーラビリティテスト

### テストデータ
```sql
-- テストデータ作成
INSERT INTO users (username, email, full_name, department, security_level)
VALUES 
    ('test_user1', 'test1@defense.gov.jp', 'テストユーザー1', 'IT部門', 2),
    ('test_user2', 'test2@defense.gov.jp', 'テストユーザー2', '運用部門', 1);
```

---

**最終更新**: 2025年7月2日  
**バージョン**: 1.0.0  
**技術責任者**: システムアーキテクト 