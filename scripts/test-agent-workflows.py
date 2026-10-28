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
                              capture_output=True, text=True, timeout=20, start_new_session=True)

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

    def test_context_reaches_provider(self):
        bundle = self.project / 'bundle ü'
        bundle.mkdir()
        (bundle / 'index.md').write_text('---\nokf_version: "0.2"\n---\n# Fixture\n')
        # A valid local-only descriptor, including profile/type authoring guidance.
        fixture = Path(__file__).resolve().parents[1] / 'okf-core/test/fixtures/profiles/guidance.dhall'
        schema = fixture.parents[3] / 'dhall/package.dhall'
        (self.project / 'profile.dhall').write_text(fixture.read_text().replace('../../../dhall/package.dhall', str(schema)))
        self.env['OKF_AGENT_MODEL'] = 'PRIVATE_SENTINEL'
        context = self.run_okf('agent', 'context', '--json')
        self.assertEqual(context.returncode, 0, context.stderr)
        snapshot = json.loads(context.stdout)
        self.assertEqual(snapshot['schemaVersion'], 1)
        self.assertIn(str(bundle.resolve()), snapshot['bundles'])
        self.assertEqual(snapshot['profiles'][0]['name'], 'qa-runbooks')
        self.assertIn('Record the setup', snapshot['profiles'][0]['guidance'])
        self.assertTrue(snapshot['profiles'][0]['typeGuidance'])
        self.assertEqual(context.stdout, self.run_okf('agent', 'context', '--json').stdout)
        self.assertNotIn('PRIVATE_SENTINEL', context.stdout)
        markdown = self.run_okf('agent', 'context').stdout
        debug = self.run_okf('agent', 'assist', '--debug')
        self.assertEqual(debug.returncode, 0, debug.stderr)
        self.assertEqual(debug.stdout, markdown)
        self.assertNotIn('PRIVATE_SENTINEL', debug.stdout)
        self.assertFalse(self.record.exists())
        for provider in ('claude', 'codex'):
            for entry in (('agent', 'assist'), ('assist',)):
                for prompt in ((), ('--', 'Review ü with "quotes"')):
                    with self.subTest(provider=provider, entry=entry, prompt=prompt):
                        printed = self.run_okf(*entry, '--provider', provider, '--print-command', *prompt)
                        self.assertEqual(printed.returncode, 0, printed.stderr)
                        expected_argv = shlex.split(printed.stdout)[1:]
                        status, output = self.run_terminal(*entry, '--provider', provider, *prompt)
                        self.assertEqual(status, 23, output)
                        received = json.loads(self.record.read_text())['argv']
                        self.assertEqual(received, expected_argv)
                        context_arg = next(a for a in received if '# OKF project context' in a)
                        self.assertIn(str(bundle.resolve()), context_arg)
                        self.assertIn('okf concepts BUNDLE --where', context_arg)
                        self.assertIn('Record the setup', context_arg)
                        self.assertIn(markdown.rstrip(), context_arg)
                        if provider == 'claude':
                            self.assertEqual(received[-1], prompt[-1] if prompt else '')
        self.assertNotEqual(self.run_okf('agent', 'assist', '--debug', '--print-command').returncode, 0)

    def test_empty_nested_and_inaccessible_context(self):
        result = self.run_okf('agent', 'context', '--json')
        snapshot = json.loads(result.stdout)
        self.assertEqual(snapshot['bundles'], [])
        self.assertEqual(snapshot['profiles'], [])
        (self.project / '.git').mkdir()
        root = str(self.project.resolve())
        nested = self.project / 'nested'
        nested.mkdir()
        self.project = nested
        # Let the shared root policy choose the project, rather than env roots.
        self.env.pop('OKF_PROFILE_ROOTS')
        self.env.pop('OKF_BUNDLE_ROOTS')
        snapshot = json.loads(self.run_okf('agent', 'context', '--json').stdout)
        self.assertEqual(snapshot['projectRoot'], root)
        self.assertEqual(snapshot['workingDirectory'], str(nested.resolve()))
        unavailable = self.root / 'unreadable'
        unavailable.mkdir()
        unavailable.chmod(0)
        self.addCleanup(lambda: unavailable.chmod(0o700))
        self.env['OKF_BUNDLE_ROOTS'] = str(unavailable)
        snapshot = json.loads(self.run_okf('agent', 'context', '--json').stdout)
        self.assertTrue(snapshot['warnings'])
        detached = self.run_okf('agent', 'assist')
        self.assertEqual(detached.returncode, 2, detached.stderr)
        self.assertIn('no controlling terminal', detached.stderr)
        self.assertFalse(self.record.exists())
        (nested / 'okf-config.dhall').write_text('malformed config')
        self.assertEqual(self.run_okf('agent', '--help').returncode, 0)
        self.assertEqual(self.run_okf('agent', 'assist', '--help').returncode, 0)
        self.assertEqual(self.run_okf('agent', 'context', '--json').returncode, 0)
        completion = self.run_okf('--bash-completion-index', '2', '--bash-completion-word', 'okf',
                                  '--bash-completion-word', 'agent', '--bash-completion-word', '')
        self.assertEqual(completion.returncode, 0)
        self.assertIn('assist', completion.stdout)
        self.assertIn('context', completion.stdout)

    def fake_fzf(self, action='0'):
        self.env['OKF_TEST_PICK'] = action
        self.env['OKF_TEST_CANDIDATES'] = str(self.root / 'picker-received.txt')
        executable = self.bin / 'fzf'
        executable.write_text(f'#!{sys.executable}\n' + """import os, sys
lines = sys.stdin.read().splitlines()
with open(os.environ['OKF_TEST_CANDIDATES'], 'w') as f:
    f.write('\\n'.join(lines))
action = os.environ['OKF_TEST_PICK']
if action == 'cancel': sys.exit(130)
if action == 'fail': sys.exit(7)
if action == 'nomatch': sys.exit(1)
if action == 'invalid': print('invalid'); sys.exit(0)
if action == 'outside': print('999\\toutside'); sys.exit(0)
print(lines[int(action)])
""")
        executable.chmod(0o755)

    def test_kit_picker_preflight(self):
        self.env['OKF_CONFIG'] = str(self.root / 'preflight.dhall')
        Path(self.env['OKF_CONFIG']).write_text('let Provider = < Claude | Codex > in '
            '{kit = {repoUrl = "file:///nonexistent-kit-origin", providers = [Provider.Claude]}, '
            'assist = {provider = Provider.Claude, model = None Text, systemPrompt = None Text}}')
        self.fake_fzf()
        result = self.run_okf('kit', 'install')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('okf kit install NAME', result.stderr)
        self.assertFalse((self.root / '.cache/okf/kit').exists())
        self.env['PATH'] = str(self.root / 'no-bin')
        status, output = self.run_terminal('kit', 'install')
        self.assertEqual(status, 2, output)
        self.assertIn('install fzf', output)
        self.assertFalse((self.root / '.cache/okf/kit').exists())

    def test_kit_picker_selection_and_visibility(self):
        self.fake_fzf('1')
        self.local_kit(skills=[
            {'name': 'review-ü', 'description': 'Shared label \x1b[31m', 'path': 'skills/demo', 'files': ['SKILL.md']},
            {'name': 'review space ü', 'description': 'Shared label \x1b[31m', 'path': 'skills/demo', 'files': ['SKILL.md']}])
        (self.project / '.git').mkdir()
        status, output = self.run_terminal('kit', 'install', '--project', '--tool-only')
        self.assertEqual(status, 0, output)
        self.assertIn("Installed skill 'review space ü'", output)
        candidates = (self.root / 'picker-received.txt').read_text()
        self.assertIn('[skill]', candidates)
        self.assertNotIn('\x1b', candidates)
        self.assertFalse((self.project / '.agents/skills/review-ü').exists())
        self.assertTrue((self.project / '.agents/skills/review space ü/SKILL.md').exists())
        snapshot = json.loads(self.run_okf('agent', 'context', '--json').stdout)
        self.assertEqual({a['provider'] for a in snapshot['installedAssets']}, {'claude', 'codex'})
        for provider in ('claude', 'codex'):
            status, output = self.run_terminal('agent', 'assist', '--provider', provider)
            self.assertEqual(status, 23, output)
            argv = json.loads(self.record.read_text())['argv']
            self.assertIn('review space ü', ' '.join(argv))

    def test_kit_picker_failures_write_no_assets(self):
        self.local_kit(skills=[{'name': 'review-ü', 'description': 'Fixture skill',
                               'path': 'skills/demo', 'files': ['SKILL.md']}])
        for action, expected in [('cancel', 0), ('fail', 1), ('invalid', 1), ('outside', 1), ('nomatch', 1)]:
            with self.subTest(action=action):
                self.fake_fzf(action)
                status, output = self.run_terminal('kit', 'install', '--project')
                self.assertEqual(status, expected, output)
                self.assertFalse((self.project / '.okf/agents').exists())
                self.assertFalse((self.project / '.agents').exists())
        self.fake_fzf('fail')
        # An explicit name bypasses fzf and terminal probes, even detached.
        result = self.run_okf('kit', 'install', 'review-ü', '--project', '--shared')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.project / '.agents/skills/review-ü/SKILL.md').exists())

    def test_empty_kit_and_agent_selection(self):
        self.fake_fzf()
        self.local_kit()
        status, output = self.run_terminal('kit', 'install')
        self.assertEqual(status, 1, output)
        self.assertIn('no skills or subagents', output)
        self.assertFalse((self.root / 'picker-received.txt').exists())
        # Refresh the local origin with one subagent. The engine owns git refresh.
        origin = self.root / 'kit-origin'
        (origin / 'kit.json').write_text(json.dumps({'version': 2, 'skills': [], 'agents': [
            {'name': 'reviewer', 'description': 'Fixture agent', 'path': 'agents/reviewer.md'}]}))
        subprocess.run(['git', 'add', '.'], cwd=origin, check=True, capture_output=True)
        subprocess.run(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                        'commit', '-m', 'add agent'], cwd=origin, check=True, capture_output=True)
        status, output = self.run_terminal('kit', 'install', '--project', '--accept-shared-codex')
        self.assertEqual(status, 0, output)
        self.assertIn("Installed agent 'reviewer'", output)
        self.assertIn('[agent]', (self.root / 'picker-received.txt').read_text())

    def test_duplicate_picker_labels_keep_identity(self):
        self.fake_fzf('1')
        self.local_kit(skills=[{'name': name, 'description': 'Same description',
                               'path': 'skills/demo', 'files': ['SKILL.md']}
                              for name in ('same\nname', 'samename')])
        status, output = self.run_terminal('kit', 'install', '--project', '--shared')
        self.assertEqual(status, 0, output)
        lines = (self.root / 'picker-received.txt').read_text().splitlines()
        self.assertEqual(lines[0].split('\t', 1)[1], lines[1].split('\t', 1)[1])
        self.assertTrue((self.project / '.agents/skills/samename/SKILL.md').exists())

    def local_kit(self, skills=None, agents=None):
        origin = self.root / 'kit-origin'
        origin.mkdir()
        (origin / 'skills/demo').mkdir(parents=True)
        (origin / 'skills/demo/SKILL.md').write_text('---\nname: review-ü\ndescription: Fixture review skill\n---\n# Review\n')
        (origin / 'agents').mkdir()
        (origin / 'agents/reviewer.md').write_text('---\nname: reviewer\ndescription: Fixture reviewer\n---\nReview the project.\n')
        (origin / 'kit.json').write_text(json.dumps({'version': 2, 'skills': skills or [], 'agents': agents or []}))
        for command in (['init'], ['add', '.'], ['-c', 'user.name=Test', '-c',
                         'user.email=test@example.invalid', 'commit', '-m', 'fixture']):
            subprocess.run(['git', *command], cwd=origin, check=True, capture_output=True)
        config = self.root / 'legacy.dhall'
        config.write_text('let Provider = < Claude | Codex > in '
                          '{ kit = { repoUrl = "' + str(origin) + '", providers = [Provider.Claude, Provider.Codex] }, '
                          'assist = { provider = Provider.Claude, model = None Text, systemPrompt = None Text } }')
        self.env['OKF_CONFIG'] = str(config)
        return origin

    def test_installed_assets_from_nested_project(self):
        self.local_kit(skills=[{'name': 'review-ü', 'description': 'Fixture skill',
                               'path': 'skills/demo', 'files': ['SKILL.md']}])
        (self.project / '.git').mkdir()
        installed = self.run_okf('kit', 'install', 'review-ü', '--project', '--tool-only')
        self.assertEqual(installed.returncode, 0, installed.stderr)
        root = self.project.resolve()
        nested = self.project / 'nested'
        nested.mkdir()
        self.project = nested
        snapshot = json.loads(self.run_okf('agent', 'context', '--json').stdout)
        assets = snapshot['installedAssets']
        self.assertEqual({a['provider'] for a in assets}, {'claude', 'codex'})
        self.assertTrue(all(a['scope'] == 'project' for a in assets))
        self.assertEqual(snapshot['projectRoot'], str(root))
        for provider in ('claude', 'codex'):
            printed = self.run_okf('agent', 'assist', '--provider', provider, '--print-command')
            self.assertEqual(printed.returncode, 0, printed.stderr)
            argv = shlex.split(printed.stdout)
            self.assertTrue(any(str(root) in a for a in argv))
            if provider == 'codex':
                override = next(a for a in argv if a.startswith('skills.config='))
                self.assertIn('review-ü/SKILL.md', override)
                self.assertIn('enabled=true', override)
            status, output = self.run_terminal('agent', 'assist', '--provider', provider)
            self.assertEqual(status, 23, output)

    def test_kit_json(self):
        self.local_kit()
        for verb in ('list', 'status', 'update'):
            result = self.run_okf('kit', verb, '--json')
            self.assertEqual(result.returncode, 0, result.stderr)
            document = json.loads(result.stdout)
            self.assertEqual(document['formatVersion'], 1)
            self.assertEqual(document['document'], 'kit-' + verb)


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0], *remaining])
