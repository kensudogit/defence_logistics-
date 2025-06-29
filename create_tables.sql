-- PostgreSQLプロシージャ用のテーブル作成

-- ユーザーマスタテーブル
CREATE TABLE IF NOT EXISTS m_user (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    last_login_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- エラーログテーブル
CREATE TABLE IF NOT EXISTS t_error (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    message TEXT
);

-- サンプルデータの挿入
INSERT INTO m_user (name, status) VALUES 
    ('Alice', 'active'),
    ('Bob', 'active'),
    ('Charlie', 'inactive'),
    ('Diana', 'active'),
    ('Eve', 'inactive')
ON CONFLICT DO NOTHING;

-- テーブル内容の確認
SELECT * FROM m_user;
SELECT * FROM t_error; 