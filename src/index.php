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

// Pulls the real EC2 instance ID from instance metadata. Refreshing the page
// a few times while under load is a simple, visible way to prove the ALB is
// spreading traffic across multiple instances/AZs — useful for your screenshots.
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
    <title>Scalable Web App Demo</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>AWS Scalable Web App — Demo Guestbook</h1>
        <p class="meta">Served by EC2 instance: <code><?= htmlspecialchars($instanceId) ?></code></p>

        <?php if (!$pdo): ?>
            <p class="error">Could not connect to the database. Check the RDS endpoint/credentials in config.php.</p>
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
