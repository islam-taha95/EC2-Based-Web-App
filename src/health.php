<?php
// Intentionally does NOT check the database — if RDS has a brief hiccup,
// we don't want the ALB yanking every EC2 instance out of rotation.
http_response_code(200);
header('Content-Type: text/plain');
echo "OK";
