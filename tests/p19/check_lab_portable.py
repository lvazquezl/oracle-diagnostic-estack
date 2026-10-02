"""CHG-ESTACK-LAB-PORTABLE-001 — the real lab adapter on Windows, Linux and macOS.

  * filesec: the same "private" / "not writable by others" meaning on every OS (POSIX bits, Windows DACL);
  * oracle_wallet (SEPS): thick mode only for this provider, external authentication, no password in the process,
    and the Oracle Net configuration must point at the private wallet named in the profile;
  * the macOS Keychain path is unchanged (thin, password from the Keychain).

Every case runs on every OS. No Oracle, no Oracle Client: the python-oracledb driver is the P15 fake.
"""
import json
import os
import subprocess
import sys

from tests.p13.harness import run_all, test, tmpdir
from tests.p15.harness import (ALIAS, FakeDriver, FakeKeychain, Lab, Scenario, lab_target, profile_doc, write_private,
                               write_targets)

from mcp_gateway_lab import filesec
from mcp_gateway_lab.profile import ProfileError

WIN = sys.platform == "win32"
USER, OTHER = "S-1-5-21-1-2-3-1001", "S-1-1-0"          # a user SID and Everyone


def _open_to_others(path, write=False):
    """Make `path` readable (or writable) by other users, the native way."""
    if WIN:
        subprocess.run(["icacls", path, "/grant", "*S-1-1-0:" + ("M" if write else "R")], check=True, capture_output=True)
    else:
        os.chmod(path, (0o777 if write else 0o755) if os.path.isdir(path) else (0o666 if write else 0o644))


def _wallet_env(d, alias="LAB19S_DIAG", wallet_in_sqlnet=None, override=True, tns_alias_defined=True):
    wallet = os.path.join(d, "wallet")
    net = os.path.join(d, "network")
    os.mkdir(wallet)
    os.mkdir(net)
    if not WIN:
        os.chmod(wallet, 0o700)
    with open(os.path.join(wallet, "cwallet.sso"), "wb") as f:
        f.write(b"\xa1\xf8\x4e\x36SYNTHETIC-NOT-A-WALLET")
    if not WIN:
        os.chmod(os.path.join(wallet, "cwallet.sso"), 0o600)
    loc = wallet_in_sqlnet or wallet
    with open(os.path.join(net, "sqlnet.ora"), "w", encoding="utf-8") as f:
        f.write("NAMES.DIRECTORY_PATH = (TNSNAMES)\n"
                f"WALLET_LOCATION = (SOURCE = (METHOD = FILE) (METHOD_DATA = (DIRECTORY = \"{loc}\")))\n"
                + ("SQLNET.WALLET_OVERRIDE = TRUE\n" if override else ""))
    with open(os.path.join(net, "tnsnames.ora"), "w", encoding="utf-8") as f:
        name = alias if tns_alias_defined else "OTHER_ALIAS"
        f.write(f"{name} = (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = db.example.invalid)(PORT = 1521))"
                "(CONNECT_DATA = (SERVICE_NAME = LAB19C)))\n")
    return wallet, net


def _wallet_profile(wallet, net, alias="LAB19S_DIAG", **extra):
    doc = profile_doc()
    t = doc["targets"][ALIAS]
    t["connection"] = {"username": "ESTACK_DIAG", "service_name": "LAB19C"}
    t["credential"] = dict({"provider": "oracle_wallet", "tns_alias": alias, "tns_admin": net, "wallet_location": wallet}, **extra)
    return doc


def _refused(d, doc, scenario=None):
    from mcp_gateway_lab.cli import build_lab_gateway
    try:
        build_lab_gateway(write_targets(d, [lab_target()]), write_private(d, "lab-profile.json", doc), driver=FakeDriver(scenario))
    except ProfileError as e:
        return str(e)
    raise AssertionError("startup accepted")


# --- filesec ---------------------------------------------------------------------------------------------------

@test
def the_windows_acl_evaluation_is_the_same_on_every_os():
    ev = filesec.evaluate_windows_acl
    mine = [(0, 0, 0x1F01FF, USER), (0, 0, 0x1F01FF, filesec.SID_SYSTEM), (0, 0, 0x1F01FF, filesec.SID_ADMINISTRATORS)]
    assert ev(USER, mine, USER, filesec.PRIVATE) and ev(filesec.SID_ADMINISTRATORS, mine, USER, filesec.PRIVATE)
    assert not ev(OTHER, mine, USER, filesec.PRIVATE), "owned by someone else"
    assert not ev(USER, None, USER, filesec.PRIVATE) and not ev(USER, None, USER, filesec.NOT_WRITABLE), "NULL DACL = everyone"
    read = mine + [(0, 0, 0x120089, OTHER)]                              # FILE_GENERIC_READ for Everyone
    assert not ev(USER, read, USER, filesec.PRIVATE) and ev(USER, read, USER, filesec.NOT_WRITABLE)
    write = mine + [(0, 0, 0x1301BF, OTHER)]                             # MODIFY for Everyone
    assert not ev(USER, write, USER, filesec.NOT_WRITABLE)
    assert ev(USER, mine + [(0, 0, filesec.SYNCHRONIZE, OTHER)], USER, filesec.PRIVATE), "SYNCHRONIZE alone grants nothing"
    assert ev(USER, mine + [(1, 0, 0x1F01FF, OTHER)], USER, filesec.PRIVATE), "a deny ACE only removes access"
    assert ev(USER, mine + [(0, filesec.INHERIT_ONLY_ACE, 0x1F01FF, OTHER)], USER, filesec.PRIVATE), "inherit-only ACEs do not apply"
    assert not ev(USER, mine + [(5, 0, 0, "")], USER, filesec.PRIVATE), "unknown ACE types fail closed"
    assert not ev(USER, mine, "", filesec.PRIVATE) and not ev(USER, mine, USER, "WHATEVER")


@test
def the_posix_evaluation_matches_the_previous_rule():
    ev = filesec.evaluate_posix
    assert ev(501, 0o100600, 501, filesec.PRIVATE) and not ev(501, 0o100640, 501, filesec.PRIVATE)
    assert not ev(0, 0o100600, 501, filesec.PRIVATE), "root-owned is not the user's private file"
    assert ev(0, 0o100644, 501, filesec.NOT_WRITABLE) and not ev(501, 0o100664, 501, filesec.NOT_WRITABLE)
    assert not ev(777, 0o100644, 501, filesec.NOT_WRITABLE)


@test
def the_native_check_sees_real_permission_changes_on_this_os():
    with tmpdir() as d:
        f = os.path.join(d, "f.txt")
        open(f, "w").close()
        if not WIN:
            os.chmod(f, 0o600)
        assert filesec.is_private(f) and filesec.is_private(f, filesec.NOT_WRITABLE), "a fresh private file"
        _open_to_others(f)
        assert not filesec.is_private(f) and filesec.is_private(f, filesec.NOT_WRITABLE), "readable by others"
        _open_to_others(f, write=True)
        assert not filesec.is_private(f, filesec.NOT_WRITABLE), "writable by others"
        assert not filesec.is_private(os.path.join(d, "missing")), "a missing path is never private"


@test
def a_profile_readable_by_other_users_is_refused_on_this_os():
    with tmpdir() as d:
        wallet, net = _wallet_env(d)
        doc = _wallet_profile(wallet, net)
        from mcp_gateway_lab.cli import build_lab_gateway
        prof = write_private(d, "lab-profile.json", doc)
        _open_to_others(prof)
        try:
            build_lab_gateway(write_targets(d, [lab_target()]), prof, driver=FakeDriver())
            raise AssertionError("a profile readable by others was accepted")
        except ProfileError as e:
            assert "private" in str(e) or "group or others" in str(e), str(e)


# --- oracle_wallet ----------------------------------------------------------------------------------------------

@test
def the_wallet_provider_connects_in_thick_mode_with_external_auth_and_no_password():
    with tmpdir() as d:
        wallet, net = _wallet_env(d)
        lab = Lab(d, profile=_wallet_profile(wallet, net), keychain=FakeKeychain())
        env, _ = lab.collect()
        assert env["status"] == "OK" and env["provenance"]["kind"] == "REAL", env.get("error")
        assert lab.driver.init_calls == [{"config_dir": net}], lab.driver.init_calls
        assert lab.driver.connects and all(c == {"dsn": "LAB19S_DIAG", "externalauth": True} for c in lab.driver.connects), lab.driver.connects
        assert lab.keychain.calls == [], "the keychain is never consulted for a wallet target"
        assert lab.driver.password_given and not any(lab.driver.password_given), "no password reaches the driver on the wallet path"
        assert "rollback" in lab.driver.events and "commit" not in lab.driver.events


@test
def the_wallet_session_must_still_be_the_dedicated_diagnostic_user():
    with tmpdir() as d:
        wallet, net = _wallet_env(d)
        lab = Lab(d, scenario=Scenario(session_sess_user="KIO_ORQUESTA"), profile=_wallet_profile(wallet, net))
        env, _ = lab.collect()
        assert env["status"] == "ERROR" and lab.adapter.last_failure == "MISMATCH_SESSION_USER", (env, lab.adapter.last_failure)
        assert not any("v$instance" in s.lower() for s in lab.driver.statements)


@test
def the_oracle_net_configuration_must_point_at_the_private_wallet_of_the_profile():
    with tmpdir() as d:
        other = os.path.join(d, "other-wallet")
        os.mkdir(other)
        wallet, net = _wallet_env(d, wallet_in_sqlnet=other)
        assert "WALLET_LOCATION must be the wallet named" in _refused(d, _wallet_profile(wallet, net))
    with tmpdir() as d:
        wallet, net = _wallet_env(d, override=False)
        assert "WALLET_OVERRIDE" in _refused(d, _wallet_profile(wallet, net))
    with tmpdir() as d:
        wallet, net = _wallet_env(d, tns_alias_defined=False)
        assert "not defined in tnsnames.ora" in _refused(d, _wallet_profile(wallet, net))
    with tmpdir() as d:
        wallet, net = _wallet_env(d)
        _open_to_others(wallet)
        assert "wallet_location must be private" in _refused(d, _wallet_profile(wallet, net))
    with tmpdir() as d:
        wallet, net = _wallet_env(d)
        _open_to_others(os.path.join(net, "sqlnet.ora"), write=True)
        assert "sqlnet.ora must not be writable" in _refused(d, _wallet_profile(wallet, net))
    with tmpdir() as d:
        wallet, net = _wallet_env(d)
        os.remove(os.path.join(wallet, "cwallet.sso"))
        assert "cwallet.sso" in _refused(d, _wallet_profile(wallet, net))


@test
def thick_mode_is_only_for_the_wallet_and_the_wallet_only_runs_thick():
    with tmpdir() as d:                                                   # keychain + thick driver: refused at use
        lab = Lab(d, scenario=Scenario(thin_mode=False))
        env, _ = lab.collect()
        assert env["status"] == "ERROR" and lab.adapter.last_failure == "THICK_MODE_REFUSED"
        assert getattr(lab.driver, "init_calls", []) == [], "the keychain path never initializes the thick client"
    with tmpdir() as d:                                                   # wallet + client that stays thin: refused at startup
        wallet, net = _wallet_env(d)
        assert "thick mode" in _refused(d, _wallet_profile(wallet, net), Scenario(init_stays_thin=True))
    with tmpdir() as d:                                                   # wallet + no Oracle Client libraries
        wallet, net = _wallet_env(d)
        assert "Oracle Client" in _refused(d, _wallet_profile(wallet, net), Scenario(init_error=RuntimeError("DPI-1047")))


@test
def the_wallet_profile_keeps_secrets_and_connect_strings_out():
    with tmpdir() as d:
        wallet, net = _wallet_env(d)
        doc = _wallet_profile(wallet, net)
        doc["targets"][ALIAS]["credential"]["password"] = "x"
        assert "secrets or connect strings" in _refused(d, doc)
    with tmpdir() as d:
        wallet, net = _wallet_env(d)
        doc = _wallet_profile(wallet, net)
        doc["targets"][ALIAS]["connection"]["host"] = "db.example.invalid"   # the alias, not the profile, resolves the host
        assert "missing or unexpected keys" in _refused(d, doc)
    with tmpdir() as d:
        wallet, net = _wallet_env(d)
        assert "tns_alias is invalid" in _refused(d, _wallet_profile(wallet, net, alias="BAD ALIAS;"))


@test
def client_lib_dir_is_passed_on_windows_and_macos_and_refused_on_linux():
    saved = sys.platform
    try:
        for plat, ok in (("win32", True), ("darwin", True), ("linux", False)):
            sys.platform = plat
            with tmpdir() as d:
                wallet, net = _wallet_env(d)
                lib = os.path.join(d, "instantclient")
                os.mkdir(lib)
                doc = _wallet_profile(wallet, net, client_lib_dir=lib)
                if ok:
                    sys.platform = saved                                  # build with the real platform's file checks
                    lab = Lab(d, profile=doc)
                    assert lab.driver.init_calls == [{"config_dir": net, "lib_dir": lib}], lab.driver.init_calls
                else:
                    assert "not used on Linux" in _refused(d, doc)
            sys.platform = saved
    finally:
        sys.platform = saved


@test
def the_keychain_target_is_unchanged():
    with tmpdir() as d:
        lab = Lab(d)
        env, _ = lab.collect()
        assert env["status"] == "OK", env.get("error")
        assert getattr(lab.driver, "init_calls", []) == [] and lab.driver.password_ok == [True]
        c = lab.driver.connects[0]
        assert c["host"] == "db19-lab.example.internal" and "externalauth" not in c and "dsn" not in c


@test
def human_evidence_never_leaves_a_file_other_users_can_read():
    from human_evidence import cli as he
    with tmpdir() as d:
        f = os.path.join(d, "raw", "x.tokens.json")
        he._write_private(f, "{}")
        assert filesec.is_private(f), "a fresh evidence file is private on this OS"
        saved = filesec.is_private
        filesec.is_private = lambda *a, **k: False                     # what a folder readable by others looks like
        try:
            try:
                he._write_private(f, "{}")
                raise AssertionError("a non-private evidence file was kept")
            except he.HumanEvidenceError as e:
                assert "readable by other users" in str(e) and not os.path.exists(f), str(e)
        finally:
            filesec.is_private = saved


if __name__ == "__main__":
    raise SystemExit(run_all())
