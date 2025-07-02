# 防衛省ロジスティクスシステム セキュリティガイドライン

## 🔐 セキュリティ概要

### システムセキュリティレベル
本システムは防衛省の機密情報を扱うため、3段階のセキュリティレベルを実装しています。

- **レベル1 (一般)**: 基本的な材料情報、一般公開可能な情報
- **レベル2 (機密)**: 詳細な材料情報、輸送情報、内部限定情報
- **レベル3 (極秘)**: 緊急事態情報、セキュリティ関連情報、最高機密情報

## 🛡️ セキュリティ機能

### 1. アクセス制御

#### セキュリティレベルベース認可
```sql
-- アクセス権限チェック
SELECT check_security_access(ユーザーID, 必要レベル, 'アクション名');
```

**実装例**:
```sql
-- 管理者アクセスチェック
SELECT check_security_access(1, 3, 'ADMIN_ACCESS');

-- 機密データアクセスチェック
SELECT check_security_access(2, 2, 'VIEW_SENSITIVE_DATA');
```

#### 機能別アクセス制御
- **ユーザー管理**: レベル3以上
- **材料管理**: レベル2以上
- **輸送管理**: レベル2以上
- **緊急事態管理**: レベル3以上
- **システム監視**: レベル3以上

### 2. 監査ログ

#### 自動監査記録
全ての操作は自動的に監査ログに記録されます：

```sql
-- 監査ログ確認
SELECT 
    id,
    u.username,
    action,
    details,
    created_at
FROM audit_log al
LEFT JOIN users u ON al.user_id = u.id
ORDER BY created_at DESC
LIMIT 10;
```

#### 監査ログ項目
- **ユーザーID**: 操作実行者
- **アクション**: 実行された操作
- **詳細**: 操作の詳細情報
- **タイムスタンプ**: 実行日時
- **IPアドレス**: アクセス元（実装予定）

### 3. アクセスログ

#### セキュリティアクセス記録
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
ORDER BY al.created_at DESC;
```

#### アクセス拒否検知
- 不正アクセス試行の自動検知
- セキュリティレベル不足によるアクセス拒否記録
- 異常アクセスパターンの監視

## 🔒 データ保護

### 1. データ暗号化

#### パスワードハッシュ化
- ユーザーパスワードはbcryptでハッシュ化
- ソルト付きハッシュによるセキュリティ強化
- 平文パスワードの保存禁止

#### 機密データ保護
- セキュリティレベルに応じたデータアクセス制御
- 機密情報の自動マスキング機能
- データエクスポート時の暗号化

### 2. データ整合性

#### 入力値検証
```sql
-- 入力値検証例
IF p_username IS NULL OR p_email IS NULL THEN
    RAISE EXCEPTION '必須パラメータが不足しています';
END IF;

IF p_security_level < 1 OR p_security_level > 3 THEN
    RAISE EXCEPTION 'セキュリティレベルが無効です';
END IF;
```

#### データ整合性チェック
- 外部キー制約による参照整合性
- チェック制約による値の妥当性検証
- トランザクション制御によるデータ一貫性

## 🚨 セキュリティ監視

### 1. リアルタイム監視

#### セキュリティアラート
```sql
-- セキュリティアラート確認
SELECT 
    id,
    alert_type,
    severity,
    message,
    created_at
FROM security_alerts
WHERE status = 'ACTIVE'
ORDER BY created_at DESC;
```

#### 異常検知
- 大量アクセス試行の検知
- 不正なセキュリティレベルアクセスの検知
- 異常な操作パターンの検知

### 2. セキュリティレポート

#### 日次セキュリティレポート
```sql
-- セキュリティ統計
SELECT 
    'Total Access Attempts' as metric,
    COUNT(*) as value
FROM access_log
WHERE created_at >= CURRENT_DATE
UNION ALL
SELECT 
    'Access Denials',
    COUNT(*)
FROM access_log
WHERE access_granted = FALSE AND created_at >= CURRENT_DATE
UNION ALL
SELECT 
    'Security Alerts',
    COUNT(*)
FROM security_alerts
WHERE created_at >= CURRENT_DATE;
```

## 📋 セキュリティポリシー

### 1. ユーザー管理ポリシー

#### アカウント作成
- 管理者承認によるアカウント作成
- 適切なセキュリティレベル割り当て
- 初期パスワードの強制変更

#### アカウント管理
- 定期的なアカウントレビュー
- 不要アカウントの論理削除
- アクセス権限の最小化原則

### 2. パスワードポリシー

#### パスワード要件
- 最小8文字以上
- 大文字・小文字・数字・記号を含む
- 辞書語の使用禁止
- 個人情報の使用禁止

#### パスワード管理
- 90日ごとの強制変更
- 過去5回分のパスワード再利用禁止
- アカウントロックアウト機能
- パスワード共有の禁止

### 3. セッション管理

#### セッション制御
- 30分のアイドルタイムアウト
- 同時ログイン制限
- セッション固定攻撃対策
- セキュアログアウト機能

## 🔍 セキュリティ監査

### 1. 定期監査

#### 月次セキュリティ監査
```sql
-- セキュリティ監査レポート
SELECT 
    'User Access Review' as audit_item,
    COUNT(*) as total_users,
    COUNT(CASE WHEN last_login < CURRENT_DATE - INTERVAL '30 days' THEN 1 END) as inactive_users
FROM users
WHERE deleted = FALSE
UNION ALL
SELECT 
    'Access Denials',
    COUNT(*),
    COUNT(CASE WHEN created_at >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END)
FROM access_log
WHERE access_granted = FALSE;
```

#### 監査項目
- ユーザーアクセス権限の妥当性
- セキュリティレベル設定の適切性
- アクセス拒否の分析
- 異常アクセスの検知

### 2. セキュリティテスト

#### ペネトレーションテスト
- 定期的な脆弱性診断
- アクセス制御の効果検証
- セキュリティ機能の動作確認

#### セキュリティ評価
- セキュリティレベル設定の妥当性
- 監査ログの完全性確認
- データ保護機能の効果確認

## 🚨 インシデント対応

### 1. セキュリティインシデント

#### インシデント分類
- **レベル1**: 軽微なセキュリティ違反
- **レベル2**: 中程度のセキュリティ侵害
- **レベル3**: 重大なセキュリティ侵害

#### 対応手順
1. **検知**: セキュリティアラートの確認
2. **分析**: インシデントの詳細分析
3. **対応**: 適切な対応措置の実施
4. **復旧**: システムの正常化
5. **報告**: インシデントレポートの作成

### 2. 緊急時対応

#### 緊急連絡先
- **セキュリティ担当**: security@defense.gov.jp
- **システム管理者**: admin@defense.gov.jp
- **緊急時**: +81-3-XXXX-XXXX

#### 緊急対応手順
```sql
-- 緊急時ユーザーアクセス制限
UPDATE users SET security_level = 1 WHERE security_level > 1;

-- 緊急時セキュリティログ確認
SELECT * FROM access_log WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour';
```

## 📚 セキュリティ教育

### 1. ユーザー教育

#### 必須研修項目
- セキュリティポリシーの理解
- パスワード管理の重要性
- ソーシャルエンジニアリング対策
- インシデント報告手順

#### 定期的な教育
- 年2回のセキュリティ研修
- セキュリティポリシーの更新通知
- 新規脅威への対応教育

### 2. 管理者教育

#### 管理者研修項目
- セキュリティ監査の実施方法
- インシデント対応手順
- セキュリティ設定の管理
- ログ分析と異常検知

## 📊 セキュリティメトリクス

### 1. 主要指標

#### セキュリティ指標
- **アクセス成功率**: 95%以上
- **セキュリティインシデント**: 月1件以下
- **パスワード変更率**: 100%（期限通り）
- **監査ログ完全性**: 100%

#### 監視指標
- **異常アクセス検知率**: 100%
- **セキュリティアラート対応時間**: 30分以内
- **インシデント対応時間**: 2時間以内

### 2. レポート

#### 月次セキュリティレポート
- セキュリティインシデントの統計
- アクセス制御の効果分析
- セキュリティ設定の妥当性評価
- 改善提案の提示

---

**最終更新**: 2025年7月2日  
**バージョン**: 1.0.0  
**承認者**: セキュリティ担当責任者 