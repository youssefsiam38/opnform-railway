<?php
// Creates the first OpnForm user (workspace admin) from ADMIN_NAME / ADMIN_EMAIL / ADMIN_PASSWORD when the users
// table is empty, by sending the app's own POST /register through Laravel's HTTP kernel in-process (no network, no
// argv). Upstream self-hosted mode only allows registration while no user exists, so after this the public sign-up
// is closed and nobody can claim the instance first. Never prints the password.

// Keep call arguments (the request body holds the password) out of any exception trace that gets logged.
ini_set('zend.exception_ignore_args', '1');

chdir('/usr/share/nginx/html');
require 'vendor/autoload.php';
$app = require 'bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);

$out = fn (string $m) => fwrite(STDOUT, "opnform-railway: $m\n");

// Some providers resolve the current request while booting, so build it first.
$request = Illuminate\Http\Request::create('/register', 'POST', [], [], [], [
    'HTTP_ACCEPT' => 'application/json',
    'CONTENT_TYPE' => 'application/json',
    'REMOTE_ADDR' => '127.0.0.1',
    'HTTP_USER_AGENT' => 'opnform-railway-bootstrap',
], '{}');
$app->instance('request', $request);
$kernel->bootstrap();

$count = \App\Models\User::count();
if ($count > 0) {
    $out("users exist ($count); first-user bootstrap skipped");
    exit(0);
}

$email = strtolower(trim((string) getenv('ADMIN_EMAIL')));
$password = (string) getenv('ADMIN_PASSWORD');
$name = trim((string) getenv('ADMIN_NAME')) ?: 'Admin';

$body = json_encode([
    'name' => $name,
    'email' => $email,
    'password' => $password,
    'password_confirmation' => $password,
    'hear_about_us' => 'railway-template',
    'agree_terms' => true,
]);

$request = Illuminate\Http\Request::create('/register', 'POST', [], [], [], [
    'HTTP_ACCEPT' => 'application/json',
    'CONTENT_TYPE' => 'application/json',
    'REMOTE_ADDR' => '127.0.0.1',
    'HTTP_USER_AGENT' => 'opnform-railway-bootstrap',
], $body);
$app->instance('request', $request);

$response = $kernel->handle($request);
$status = $response->getStatusCode();
$data = json_decode((string) $response->getContent(), true) ?: [];
$kernel->terminate($request, $response);

if ($status === 200 && isset($data['user'])) {
    $out("first user created for $email");
    exit(0);
}

$errors = isset($data['errors']) && is_array($data['errors']) ? implode('; ', array_map(
    fn ($k, $v) => $k . ': ' . implode(' ', (array) $v),
    array_keys($data['errors']),
    $data['errors']
)) : '';
$out("first-user registration failed (HTTP $status): " . ($data['message'] ?? 'no message') . ($errors ? " [$errors]" : ''));
exit(1);
