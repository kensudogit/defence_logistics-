@echo off
echo PostgreSQLプロシージャの実行
echo ================================

REM PostgreSQLの接続情報を設定
set DB_HOST=localhost
set DB_PORT=5433
set DB_NAME=testdb
set DB_USER=postgres
set DB_PASSWORD=password

REM パスワードを環境変数に設定（psqlで使用）
set PGPASSWORD=%DB_PASSWORD%

echo PostgreSQLコンテナが起動しているか確認中...
docker ps | findstr postgres_procedures >nul
if errorlevel 1 (
    echo PostgreSQLコンテナが起動していません。起動します...
    docker-compose up -d
    timeout /t 5 /nobreak >nul
)

echo 1. テーブルを作成中...
psql -h %DB_HOST% -p %DB_PORT% -d %DB_NAME% -U %DB_USER% -f create_tables.sql
if errorlevel 1 (
    echo テーブル作成でエラーが発生しました。
    pause
    exit /b 1
)

echo.
echo 2. プロシージャを作成中...
psql -h %DB_HOST% -p %DB_PORT% -d %DB_NAME% -U %DB_USER% -f postgresql_procedures.sql
if errorlevel 1 (
    echo プロシージャ作成でエラーが発生しました。
    pause
    exit /b 1
)

echo.
echo 3. プロシージャのテスト実行...
echo 基本的なプロシージャのテスト:
psql -h %DB_HOST% -p %DB_PORT% -d %DB_NAME% -U %DB_USER% -c "CALL get_user_info(1);"

echo.
echo ユーザー作成のテスト:
psql -h %DB_HOST% -p %DB_PORT% -d %DB_NAME% -U %DB_USER% -c "CALL create_user('TestUser', 'active');"

echo.
echo アクティブユーザー数の取得:
psql -h %DB_HOST% -p %DB_PORT% -d %DB_NAME% -U %DB_USER% -c "SELECT get_active_user_count();"

echo.
echo 実行完了！
echo パスワード環境変数をクリアしました。
set PGPASSWORD=
pause 