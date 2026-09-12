#!/usr/bin/env python3
# Codex クラウド（Linux）から Claude Code をサブスク認証で呼ぶ唯一の経路。
# Windows は `~/.codex/bin/cc-subscription-gateway.ps1`。
#
# 使い方:
#   python3 ~/.agents/cloud/cc-subscription-call.py <prompt-file>
#   python3 ~/.agents/cloud/cc-subscription-call.py --check
#
# 失敗時は認証情報を含み得る生の出力を出さず、固定メッセージだけを stderr に出す。

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TOKEN_PATH = Path('/root/.config/claude-subscription/oauth-token')
ALLOWED_ENV = {'PATH', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY',
               'http_proxy', 'https_proxy', 'all_proxy', 'no_proxy',
               'SSL_CERT_FILE', 'SSL_CERT_DIR', 'NODE_EXTRA_CA_CERTS', 'LANG'}
BASE_ARGS = ['--no-session-persistence', '--setting-sources', '',
             '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}']


def read_token() -> str:
    if not TOKEN_PATH.is_file() or TOKEN_PATH.is_symlink():
        raise ValueError('Invalid authentication file')
    if TOKEN_PATH.stat().st_mode & 0o777 != 0o600:
        raise ValueError('Invalid authentication file mode')
    if TOKEN_PATH.parent.is_symlink() or TOKEN_PATH.parent.stat().st_mode & 0o777 != 0o700:
        raise ValueError('Invalid authentication directory')
    token = TOKEN_PATH.read_text()
    if not token.startswith('sk-ant-oat01-') or re.search(r'\s', token):
        raise ValueError('Invalid authentication token')
    return token


def run_claude(prompt: str, extra_args: list, timeout: int) -> subprocess.CompletedProcess:
    token = read_token()
    cli = shutil.which('claude')
    if not cli:
        raise ValueError('Claude CLI unavailable')
    with tempfile.TemporaryDirectory(dir='/root') as home:
        env = {k: os.environ[k] for k in ALLOWED_ENV if k in os.environ}
        env.update(HOME=home, CLAUDE_CONFIG_DIR=home,
                   CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1',
                   ENABLE_CLAUDEAI_MCP_SERVERS='false',
                   CLAUDE_CODE_OAUTH_TOKEN=token)
        return subprocess.run(
            [cli, '-p', prompt] + extra_args + BASE_ARGS,
            cwd=home, env=env, stdin=subprocess.DEVNULL, capture_output=True,
            text=True, timeout=timeout)


def check() -> int:
    try:
        run = run_claude('Reply with exactly OK', ['--tools', '', '--max-turns', '1'], 90)
    except Exception as exc:
        print('CLAUDE_SUBSCRIPTION_CALL_FAILED exit_code=1 error=%s' % type(exc).__name__,
              file=sys.stderr)
        return 1
    ok = run.returncode == 0 and run.stdout.strip() == 'OK'
    print(json.dumps({'exit_code': run.returncode, 'ok_exact': ok}))
    return 0 if ok else 1


def call(prompt_file: str) -> int:
    prompt = Path(prompt_file).read_text(encoding='utf-8')
    try:
        run = run_claude(prompt, [], 1800)
    except Exception as exc:
        print('CLAUDE_SUBSCRIPTION_CALL_FAILED exit_code=1 error=%s' % type(exc).__name__,
              file=sys.stderr)
        return 1
    if run.returncode != 0:
        print('CLAUDE_SUBSCRIPTION_CALL_FAILED exit_code=%d' % run.returncode, file=sys.stderr)
        return 1
    sys.stdout.write(run.stdout)
    return 0


def main() -> int:
    args = sys.argv[1:]
    if len(args) != 1:
        print('usage: cc-subscription-call.py <prompt-file> | --check', file=sys.stderr)
        return 2
    if args[0] == '--check':
        return check()
    if not Path(args[0]).is_file():
        print('usage: cc-subscription-call.py <prompt-file> | --check', file=sys.stderr)
        return 2
    return call(args[0])


if __name__ == '__main__':
    raise SystemExit(main())
