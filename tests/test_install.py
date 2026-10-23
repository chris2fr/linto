import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = [str(ROOT / "bin" / "linto"), "linto", "install"]


def run(*args, env=None, **kwargs):
    # Installing real packages needs the network: tests skip the Python environment unless they ask for it.
    if "--help" not in args and "--venv" not in args and "--no-venv" not in args:
        args = (*args, "--no-venv")
    environment = dict(os.environ, LC_ALL="C")
    environment.update(env or {})
    return subprocess.run([*INSTALL, *args], capture_output=True, text=True, env=environment,
                          stdin=subprocess.DEVNULL, **kwargs)


class InstallTests(unittest.TestCase):
    def test_a_mode_is_required_without_a_terminal(self):
        result = run()
        self.assertEqual(result.returncode, 2)
        self.assertIn("install: choose --user or --system", result.stderr)

    def test_options_are_checked_against_the_mode(self):
        self.assertIn("--shell only applies with --user", run("--system", "--shell", "fish").stderr)
        self.assertIn("--sysconfdir only applies with --system", run("--user", "--sysconfdir", "/x").stderr)
        self.assertIn("unsupported shell 'csh'", run("--user", "--shell", "csh").stderr)

    def test_help_and_french_help(self):
        english = run("--help")
        french = run("--help", env={"LC_ALL": "fr_FR.UTF-8"})
        self.assertTrue(english.stdout.startswith("Usage: linto linto install"))
        self.assertNotEqual(english.stdout, french.stdout)

    def test_system_install_into_a_prefix(self):
        with tempfile.TemporaryDirectory() as directory:
            prefix = Path(directory) / "usr"
            sysconf = Path(directory) / "etc"
            for _ in range(2):                                       # a second run upgrades in place
                result = run("--system", "--prefix", str(prefix), "--sysconfdir", str(sysconf))
                self.assertEqual(result.returncode, 0, result.stderr)
            installed = (prefix / "lib" / "linto" / "config.yml").read_text(encoding="utf-8")
            self.assertNotIn("memos.gv.je", installed)               # the personal config.yml is not shipped
            self.assertIn("web: default", installed)
            self.assertTrue((sysconf / "linto" / "linto.yml").exists())
            (sysconf / "linto" / "linto.yml").write_text("# mine\n", encoding="utf-8")
            self.assertEqual(run("--system", "--prefix", str(prefix), "--sysconfdir", str(sysconf)).returncode, 0)
            self.assertEqual((sysconf / "linto" / "linto.yml").read_text(encoding="utf-8"), "# mine\n")
            env = {"PATH": f"{prefix / 'bin'}:{os.environ['PATH']}"}
            version = subprocess.run(["linto", "--version"], capture_output=True, text=True,
                                     env=dict(os.environ, **env))
            self.assertRegex(version.stdout, r"^linto \S+\n$")
            token = subprocess.run(["linto-utils-uuid"], capture_output=True, text=True,
                                   env=dict(os.environ, **env))
            self.assertEqual(token.returncode, 0, token.stderr)
            for path in ("share/bash-completion/completions/linto", "share/zsh/site-functions/_linto",
                         "share/fish/vendor_completions.d/linto.fish", "share/man/man1/linto.1"):
                self.assertTrue((prefix / path).exists(), path)
            self.assertFalse((prefix / "lib" / "linto" / ".git").exists())
            self.assertFalse((prefix / "lib" / "linto" / "tests").exists())

    def test_system_install_runs_privileged_steps_through_sudo(self):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "fakebin"
            fake.mkdir()
            log = Path(directory) / "sudo.log"
            (fake / "sudo").write_text(f'#!/bin/sh\n[ "$1" = -v ] && exit 0\necho "$@" >> "{log}"\nexec "$@"\n')
            (fake / "sudo").chmod(0o755)
            prefix = Path(directory) / "usr"
            result = run("--system", "--prefix", str(prefix), "--sysconfdir", str(Path(directory) / "etc"),
                         env={"LINTO_INSTALL_SUDO": "always", "PATH": f"{fake}:{os.environ['PATH']}"})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("using sudo", result.stderr)
            calls = log.read_text().splitlines()
            for command in ("mkdir -p", "tar --no-same-owner", "tee", "ln -sfn", "chmod 0755", "install -m"):
                self.assertTrue(any(c.startswith(command) or c.startswith("env ") for c in calls) and
                                any(command in c for c in calls), command)
            self.assertTrue(any(c.startswith("env ") and "build.sh" in c for c in calls))
            self.assertTrue((prefix / "bin" / "linto").exists())

    def test_system_install_without_sudo_explains(self):
        import shutil
        if shutil.which("sudo"):
            self.skipTest("sudo is installed")
        result = run("--system", "--prefix", "/tmp/linto-no-sudo", env={"LINTO_INSTALL_SUDO": "always"})
        self.assertEqual(result.returncode, 1)
        self.assertIn("run as root, or choose another --prefix", result.stderr)

    def test_user_install_creates_the_user_config_once(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            env = {"HOME": str(home), "XDG_DATA_HOME": str(home / "data"), "XDG_CONFIG_HOME": str(home / "config")}
            self.assertEqual(run("--user", "--no-man", "--shell", "bash", env=env).returncode, 0)
            user_config = home / ".linto.yml"
            self.assertIn("Linto local configuration", user_config.read_text(encoding="utf-8"))
            user_config.write_text("# mine\n", encoding="utf-8")
            self.assertEqual(run("--user", "--no-man", "--shell", "bash", env=env).returncode, 0)
            self.assertEqual(user_config.read_text(encoding="utf-8"), "# mine\n")

    def test_the_python_environment_survives_an_upgrade_and_failure_only_warns(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            env = {"HOME": str(home), "XDG_DATA_HOME": str(home / "data"), "XDG_CONFIG_HOME": str(home / "config"),
                   "LINTO_SYSTEM_PREFIXES": "/nonexistent",
                   "PIP_INDEX_URL": "http://127.0.0.1:9/simple", "PIP_RETRIES": "0", "PIP_TIMEOUT": "1"}
            kept = home / ".local" / "lib" / "linto" / ".venv" / "extra-package-marker"
            first = run("--user", "--no-man", "--shell", "bash", "--venv", env=env)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertTrue(kept.parent.is_dir())                         # created even though pip could not download
            self.assertIn("could not create the Python environment", first.stderr)
            kept.write_text("x", encoding="utf-8")
            second = run("--user", "--no-man", "--shell", "bash", "--no-venv", env=env)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertTrue(kept.exists())                                # an upgrade keeps .venv

    def test_system_install_refuses_to_replace_a_foreign_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "lib" / "linto").mkdir(parents=True)
            result = run("--system", "--prefix", directory)
            self.assertEqual(result.returncode, 1)
            self.assertIn("not a Linto installation", result.stderr)


class UserInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.env = {"HOME": str(self.home), "XDG_DATA_HOME": str(self.home / "data"),
                    "XDG_CONFIG_HOME": str(self.home / "config"), "ZDOTDIR": str(self.home),
                    "LINTO_SYSTEM_PREFIXES": "/nonexistent"}
        self.lib = self.home / ".local" / "lib" / "linto"

    def tearDown(self):
        self.tmp.cleanup()

    def install(self, *args, env=None):
        return run("--user", "--no-man", *args, env={**self.env, **(env or {})})

    def test_shell_lines_point_at_the_installed_copy_not_the_checkout(self):
        self.assertEqual(self.install().returncode, 0)
        for startup in (self.home / ".bashrc", self.home / ".profile", self.home / ".kshrc", self.home / ".zshrc",
                        self.home / "config" / "fish" / "config.fish"):
            text = startup.read_text(encoding="utf-8")
            self.assertNotIn(str(ROOT), text, startup)
            self.assertIn(str(self.home / ".local"), text, startup)
        self.assertFalse((self.lib / ".git").exists())
        launched = subprocess.run([str(self.home / ".local" / "bin" / "linto"), "--version"],
                                  capture_output=True, text=True)
        self.assertRegex(launched.stdout, r"^linto \S+\n$")
        wrapper = subprocess.run([str(self.home / "data" / "linto" / "bin" / "linto-utils-uuid")],
                                 capture_output=True, text=True)
        self.assertEqual(wrapper.returncode, 0, wrapper.stderr)

    def test_lines_pointing_at_a_checkout_are_replaced(self):
        fish = self.home / "config" / "fish" / "config.fish"
        fish.parent.mkdir(parents=True)
        fish.write_text(f'fish_add_path "{ROOT}/bin" "{self.home}/data/linto/bin"\nsource "{ROOT}/completions/linto.fish"\n'
                        "function y\nend\n", encoding="utf-8")
        bashrc = self.home / ".bashrc"
        bashrc.write_text(f'source "{ROOT}/completions/linto.bash"\nexport PATH="{ROOT}/bin:{self.home}/data/linto/bin:$PATH"\n',
                          encoding="utf-8")
        self.assertEqual(self.install().returncode, 0)
        self.assertEqual(self.install().returncode, 0)                      # and again: idempotent
        for startup in (fish, bashrc):
            self.assertNotIn(str(ROOT), startup.read_text(encoding="utf-8"), startup)
        self.assertEqual(bashrc.read_text(encoding="utf-8").count("export PATH="), 1)
        self.assertIn("function y", fish.read_text(encoding="utf-8"))

    def test_installing_from_the_installed_copy_is_refused(self):
        self.assertEqual(self.install().returncode, 0)
        result = subprocess.run([str(self.lib / "bin" / "linto"), "linto", "install", "--user", "--no-man"],
                                capture_output=True, text=True, env=dict(os.environ, LC_ALL="C", **self.env))
        self.assertEqual(result.returncode, 1)
        self.assertIn("run the installer from a checkout", result.stderr)
        self.assertTrue((self.lib / "bin" / "linto").exists())

    def test_warns_when_a_system_installation_exists(self):
        system = self.home / "sys"
        (system / "lib" / "linto").mkdir(parents=True)
        (system / "lib" / "linto" / ".linto-install").write_text("v0\n", encoding="utf-8")
        result = self.install(env={"LINTO_SYSTEM_PREFIXES": str(system)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("a system-wide Linto is installed", result.stderr)
        self.assertIn(str(system / "lib" / "linto"), result.stderr)
        self.assertNotIn("system-wide Linto", self.install().stderr)

    def test_uninstall_user_removes_the_installation_and_keeps_the_configuration(self):
        self.assertEqual(self.install().returncode, 0)
        (self.home / ".bashrc").write_text("# mine\n" + (self.home / ".bashrc").read_text(encoding="utf-8"), encoding="utf-8")
        refused = run("--user", env=self.env) and subprocess.run(
            [*INSTALL[:-1], "uninstall", "--user"], capture_output=True, text=True,
            env=dict(os.environ, LC_ALL="C", **self.env), stdin=subprocess.DEVNULL)
        self.assertEqual(refused.returncode, 2)                              # no terminal, no --yes
        self.assertTrue(self.lib.exists())
        result = subprocess.run([*INSTALL[:-1], "uninstall", "--user", "--yes"], capture_output=True, text=True,
                                env=dict(os.environ, LC_ALL="C", **self.env), stdin=subprocess.DEVNULL)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.lib.exists())
        self.assertFalse((self.home / ".local" / "bin" / "linto").exists())
        self.assertFalse((self.home / "data" / "linto" / "bin").exists())
        for startup in (self.home / ".bashrc", self.home / ".profile", self.home / ".zshrc",
                        self.home / "config" / "fish" / "config.fish"):
            self.assertNotIn("linto", startup.read_text(encoding="utf-8").replace("linto-", ""), startup)
        self.assertIn("# mine", (self.home / ".bashrc").read_text(encoding="utf-8"))
        self.assertTrue((self.home / ".linto.yml").exists())

    def test_system_install_can_remove_the_user_installation(self):
        self.assertEqual(self.install().returncode, 0)
        prefix = self.home / "usr"
        result = run("--system", "--prefix", str(prefix), "--sysconfdir", str(self.home / "etc"),
                     "--remove-user-install", env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.lib.exists())
        self.assertTrue((prefix / "lib" / "linto").exists())
        self.assertEqual(self.install().returncode, 0)
        kept = run("--system", "--prefix", str(prefix), "--sysconfdir", str(self.home / "etc"), env=self.env)
        self.assertTrue(self.lib.exists())                                   # no terminal: it is kept
        self.assertIn("linto linto uninstall --user", kept.stdout)

    def test_uninstall_system(self):
        prefix = self.home / "usr"
        sysconf = self.home / "etc"
        self.assertEqual(run("--system", "--prefix", str(prefix), "--sysconfdir", str(sysconf), env=self.env).returncode, 0)
        result = subprocess.run([*INSTALL[:-1], "uninstall", "--system", "--prefix", str(prefix), "--yes"],
                                capture_output=True, text=True, env=dict(os.environ, LC_ALL="C", **self.env),
                                stdin=subprocess.DEVNULL)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((prefix / "lib" / "linto").exists())
        self.assertEqual([p.name for p in (prefix / "bin").glob("linto*")], [])
        for path in ("share/bash-completion/completions/linto", "share/zsh/site-functions/_linto",
                     "share/fish/vendor_completions.d/linto.fish", "share/linto"):
            self.assertFalse((prefix / path).exists(), path)
        self.assertTrue((sysconf / "linto" / "linto.yml").exists())
        again = subprocess.run([*INSTALL[:-1], "uninstall", "--system", "--prefix", str(prefix), "--yes"],
                               capture_output=True, text=True, env=dict(os.environ, LC_ALL="C", **self.env))
        self.assertEqual(again.returncode, 1)
        self.assertIn("not a Linto installation", again.stderr)


if __name__ == "__main__":
    unittest.main()
