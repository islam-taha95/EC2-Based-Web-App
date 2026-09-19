#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

# Update OS and install Apache + PHP + MySQL extension
dnf update -y
dnf install -y httpd php php-mysqlnd

# Create health.php endpoint for ALB health check
cat << 'EOF' > /var/www/html/health.php
<?php
http_response_code(200);
header('Content-Type: text/plain');
echo "OK";
EOF

# Create db.php with RDS database connection details
cat << 'EOF' > /var/www/html/db.php
<?php
define('DB_HOST', 'manara-web-app-db.cmdcqecmu4rm.us-east-1.rds.amazonaws.com');
define('DB_NAME', 'appdb');
define('DB_USER', 'admin');
define('DB_PASS', 'Soly$95Taha');

function getDbConnection() {
    try {
        $pdo = new PDO(
            "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
            DB_USER,
            DB_PASS,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        $pdo->exec("CREATE TABLE IF NOT EXISTS guestbook (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )");
        return $pdo;
    } catch (PDOException $e) {
        error_log("DB connection failed: " . $e->getMessage());
        return null;
    }
}
EOF

# Create index.php for Guestbook application UI & logic
cat << 'EOF' > /var/www/html/index.php
<?php
require_once __DIR__ . '/db.php';

$pdo = getDbConnection();
$error = null;
$success = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && $pdo) {
    $name = trim($_POST['name'] ?? '');
    $message = trim($_POST['message'] ?? '');
    if ($name !== '' && $message !== '') {
        $stmt = $pdo->prepare("INSERT INTO guestbook (name, message) VALUES (?, ?)");
        $stmt->execute([$name, $message]);
        $success = "Entry added!";
    } else {
        $error = "Name and message are both required.";
    }
}

$entries = [];
if ($pdo) {
    $entries = $pdo->query("SELECT name, message, created_at FROM guestbook ORDER BY created_at DESC LIMIT 20")->fetchAll();
}

$instanceId = @file_get_contents(
    'http://169.254.169.254/latest/meta-data/instance-id',
    false,
    stream_context_create(['http' => ['timeout' => 1]])
) ?: 'unknown';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Manara Web App</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>Manara Web App — Demo Guestbook</h1>
        <p class="meta">Served by EC2 instance: <code><?= htmlspecialchars($instanceId) ?></code></p>

        <?php if (!$pdo): ?>
            <p class="error">Could not connect to the database.</p>
        <?php endif; ?>
        <?php if ($error): ?><p class="error"><?= htmlspecialchars($error) ?></p><?php endif; ?>
        <?php if ($success): ?><p class="success"><?= htmlspecialchars($success) ?></p><?php endif; ?>

        <form method="post">
            <input type="text" name="name" placeholder="Your name" required>
            <textarea name="message" placeholder="Leave a message" required></textarea>
            <button type="submit">Sign the guestbook</button>
        </form>

        <h2>Entries</h2>
        <ul class="entries">
            <?php foreach ($entries as $entry): ?>
                <li>
                    <strong><?= htmlspecialchars($entry['name']) ?></strong>
                    <span class="time"><?= htmlspecialchars($entry['created_at']) ?></span>
                    <p><?= htmlspecialchars($entry['message']) ?></p>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
</body>
</html>
EOF

# Create style.css for UI styling
cat << 'EOF' > /var/www/html/style.css
body {
    font-family: -apple-system, Segoe UI, Arial, sans-serif;
    background: #f4f6f8;
    margin: 0;
    padding: 2rem;
}
.container {
    max-width: 600px;
    margin: 0 auto;
    background: #fff;
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.1);
}
h1 { font-size: 1.4rem; }
.meta { color: #666; font-size: 0.85rem; }
.error { color: #b00020; }
.success { color: #0a7a2f; }
form { display: flex; flex-direction: column; gap: 0.5rem; margin: 1rem 0; }
input, textarea, button { padding: 0.5rem; font-size: 1rem; font-family: inherit; }
button { background: #ff9900; border: none; border-radius: 4px; cursor: pointer; }
.entries { list-style: none; padding: 0; }
.entries li { border-bottom: 1px solid #eee; padding: 0.75rem 0; }
.time { color: #999; font-size: 0.75rem; margin-left: 0.5rem; }
EOF

# Set permissions and enable web service
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/
systemctl enable --now httpd