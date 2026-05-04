import json
import sys
import urllib.error
import urllib.request

checks = [
    ('GET', '/'),
    ('GET', '/auth/login'),
    ('GET', '/user'),
    ('PUT', '/user/00000000-0000-0000-0000-000000000000'),
    ('PATCH', '/user/00000000-0000-0000-0000-000000000000'),
    ('PUT', '/users/00000000-0000-0000-0000-000000000000'),
    ('PATCH', '/users/00000000-0000-0000-0000-000000000000'),
    ('PUT', '/profile'),
    ('PATCH', '/profile'),
    ('PUT', '/me'),
    ('PATCH', '/me'),
    ('PUT', '/auth/me'),
    ('PATCH', '/auth/me'),
]

for method, path in checks:
    print(f'\n=== {method} {path} ===')
    data = None
    headers = {}
    if method in {'PUT', 'PATCH'}:
        data = json.dumps({'name': 'Teste Nome'}).encode()
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(
        f'http://localhost:8080{path}',
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            body = resp.read(200).decode('utf-8', 'ignore')
            print('HTTP', resp.status)
            print(body)
    except urllib.error.HTTPError as e:
        body = e.read(200).decode('utf-8', 'ignore')
        print('HTTP', e.code)
        print(body)
    except Exception as e:
        print(type(e).__name__, str(e))

