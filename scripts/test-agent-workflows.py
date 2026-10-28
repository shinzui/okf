#!/usr/bin/env python3
"""Executable-level acceptance using isolated config, local kits and fake providers.

Run after building: python3 scripts/test-agent-workflows.py --okf /path/to/okf
No provider credentials or real user assets are used.
"""
import argparse
import errno
import json
import os
from pathlib import Path
import pty
import select
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unittest

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--okf', required=True, type=lambda p: str(Path(p).resolve()))
args, remaining = parser.parse_known_args()


class AgentWorkflows(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='okf-agent-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.project = self.root / 'project ü'
        self.project.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.record = self.root / 'received.json'
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(('OKF_', 'XDG_', 'CLAUDE_', 'CODEX_'))}
        self.env.update(HOME=str(self.root), XDG_CONFIG_HOME=str(self.root / 'config'),
                        XDG_CACHE_HOME=str(self.root / 'cache'),
                        PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        OKF_PROFILE_ROOTS=str(self.project),
                        OKF_BUNDLE_ROOTS=str(self.project),
                        OKF_TEST_RECORD=str(self.record))
        for provider in ('claude', 'codex'):
            executable = self.bin / provider
            executable.write_text(f'#!{sys.executable}\n' + '''import json, os, signal, sys
with open(os.environ['OKF_TEST_RECORD'], 'w') as f:
    json.dump({'pid': os.getpid(), 'argv': sys.argv[1:], 'tty': [os.isatty(i) for i in range(3)]}, f)
if os.environ.get('OKF_TEST_INTERRUPT'):
    signal.signal(signal.SIGINT, lambda *_: print('INTERRUPTED', flush=True))
    print('READY', flush=True)
    sys.stdin.readline()
print('provider stdout', flush=True)
print('provider stderr', file=sys.stderr, flush=True)
sys.exit(23)
''')
            executable.chmod(0o755)

    def run_okf(self, *argv):
        return subprocess.run([args.okf, *argv], cwd=self.project, env=self.env,
                              capture_output=True, text=True, timeout=20)

    def run_terminal(self, *argv):
        pid, fd = pty.fork()
        if pid == 0:
            os.chdir(self.project)
            os.execve(args.okf, [args.okf, *argv], self.env)
        output = bytearray()
        reaped = False
        eof = False
        input_stage = 0
        try:
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                ready, _, _ = select.select([] if eof else [fd], [], [], 0.01)
                if ready:
                    try:
                        data = os.read(fd, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        data = b''
                    eof = not data
                    output.extend(data)
                    if self.env.get('OKF_TEST_INTERRUPT'):
                        if input_stage == 0 and b'READY' in output:
                            os.write(fd, b'\x03')
                            input_stage = 1
                        if input_stage == 1 and b'INTERRUPTED' in output:
                            os.write(fd, b'done\n')
                            input_stage = 2
                child, status = os.waitpid(pid, os.WNOHANG)
                if child:
                    reaped = True
                    return os.waitstatus_to_exitcode(status), output.decode(errors='replace')
            self.fail('interactive launch did not finish within 20 seconds: '
                      + output.decode(errors='replace'))
        finally:
            os.close(fd)
            if not reaped:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                os.waitpid(pid, 0)

    def test_provider_argv_terminal_and_exit(self):
        prompt = "--inspect 'quoted' ü\nnext line"
        for provider in ('claude', 'codex'):
            with self.subTest(provider=provider):
                status, output = self.run_terminal('assist', '--provider', provider,
                                                  '--system-prompt', 'Extra instructions', '--', prompt)
                self.assertEqual(status, 23, output)
                received = json.loads(self.record.read_text())
                self.assertEqual(received['tty'], [True, True, True])
                argv = received['argv']
                self.assertIn('provider stdout', output)
                self.assertIn('provider stderr', output)
                self.assertIn('--', argv)
                if provider == 'claude':
                    self.assertEqual(argv[-1], prompt)
                    self.assertIn('--append-system-prompt', argv)
                    self.assertNotIn('--system-prompt', argv)
                else:
                    self.assertIn(prompt, argv[-1])
                    self.assertIn('Extra instructions', argv[-1])
                    self.assertNotIn('exec', argv)

    def test_interrupt_does_not_orphan_provider(self):
        self.env['OKF_TEST_INTERRUPT'] = '1'
        for provider in ('claude', 'codex'):
            with self.subTest(provider=provider):
                status, output = self.run_terminal('assist', '--provider', provider, 'inspect')
                self.assertEqual(status, 23, output)
                self.assertIn('INTERRUPTED', output)
                child_pid = json.loads(self.record.read_text())['pid']
                with self.assertRaises(ProcessLookupError):
                    os.kill(child_pid, 0)

    def test_missing_provider_and_inspection(self):
        self.env['PATH'] = str(self.root / 'empty-bin')
        printed = self.run_okf('assist', '--print-command', 'inspect')
        self.assertEqual(printed.returncode, 0, printed.stderr)
        self.assertEqual(shlex.split(printed.stdout)[0], 'claude')
        self.assertFalse(self.record.exists())
        status, output = self.run_terminal('assist', 'inspect')
        self.assertEqual(status, 127, output)
        self.assertIn('failed to launch claude', output)
        self.assertIn('--print-command', output)

    def test_kit_json(self):
        # A local git origin exercises the engine's real clone/manifest path offline.
        origin = self.root / 'kit-origin'
        origin.mkdir()
        (origin / 'kit.json').write_text(json.dumps({'version': 2, 'skills': [], 'agents': []}))
        for command in (['init'], ['add', '.'], ['-c', 'user.name=Test', '-c',
                         'user.email=test@example.invalid', 'commit', '-m', 'fixture']):
            subprocess.run(['git', *command], cwd=origin, check=True, capture_output=True)
        # Legacy config must still decode without profiles or agent blocks.
        config = self.root / 'legacy.dhall'
        config.write_text('let Provider = < Claude | Codex > in '
                          '{ kit = { repoUrl = "' + str(origin) + '", providers = [Provider.Claude] }, '
                          'assist = { provider = Provider.Claude, model = None Text, systemPrompt = None Text } }')
        self.env['OKF_CONFIG'] = str(config)
        for verb in ('list', 'status', 'update'):
            result = self.run_okf('kit', verb, '--json')
            self.assertEqual(result.returncode, 0, result.stderr)
            document = json.loads(result.stdout)
            self.assertEqual(document['formatVersion'], 1)
            self.assertEqual(document['document'], 'kit-' + verb)


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0], *remaining])
