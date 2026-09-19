<?php
// config.php is NOT part of this repo — it is generated on each EC2 instance
// by the Launch Template's user data script, so real DB credentials are
// never committed to GitHub.
require_once __DIR__ . '/config.php';

function getDbConnection() {
    try {
        $pdo = new PDO(
            "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
            DB_USER,
            DB_PASS,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        // Auto-create the table on first run so there is zero manual DB setup.
        $pdo->exec("CREATE TABLE IF NOT EXISTS guestbook (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )");
        return $pdo;
    } catch (PDOException $e) {
        // Log the real error server-side, never show connection details to visitors.
        error_log("DB connection failed: " . $e->getMessage());
        return null;
    }
}
