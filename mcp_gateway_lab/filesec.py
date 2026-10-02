"""
mcp_gateway_lab.filesec — portable "is this path private?" check (CHG-ESTACK-LAB-PORTABLE-001).

Two levels, same meaning on every OS:
  PRIVATE       only the current user (plus, on Windows, SYSTEM and Administrators) can read or change it;
  NOT_WRITABLE  others may read it, but only the current user (or root / SYSTEM / Administrators) can change it.

POSIX (Linux, macOS): owner uid + permission bits, from lstat (symlinks are refused by the callers).
Windows: owner SID + DACL, read with the native security API through ctypes (no subprocess, no third-party
package). The DACL evaluation is a pure function (`evaluate_windows_acl`) so it is tested on every platform; only
the reader needs Windows. Anything unexpected — NULL DACL, an ACE type we do not understand, an API failure —
means "not private" (fail closed). Callers turn a False into a fixed-text refusal.
"""
from __future__ import annotations

import os
import stat
import sys

PRIVATE = "PRIVATE"
NOT_WRITABLE = "NOT_WRITABLE"

# Windows well-known SIDs that may always hold access (the machine itself and local administrators).
SID_SYSTEM = "S-1-5-18"
SID_ADMINISTRATORS = "S-1-5-32-544"
TRUSTED_SIDS = frozenset({SID_SYSTEM, SID_ADMINISTRATORS})

ACCESS_ALLOWED_ACE_TYPE = 0
ACCESS_DENIED_ACE_TYPE = 1
INHERIT_ONLY_ACE = 0x08
SYNCHRONIZE = 0x00100000
# Rights that let someone else change the object (or its permissions/ownership).
_WRITE_RIGHTS = (0x0002 | 0x0004 | 0x0010 | 0x0100 | 0x00010000 | 0x00040000 | 0x00080000   # data, append, EA, attrs, DELETE, WRITE_DAC, WRITE_OWNER
                 | 0x40000000 | 0x10000000 | 0x0040)                                    # GENERIC_WRITE, GENERIC_ALL, FILE_DELETE_CHILD


class FileSecurityError(RuntimeError):
    def __init__(self):
        super().__init__("file security information is not available")


def evaluate_windows_acl(owner_sid: str, aces, user_sid: str, level: str) -> bool:
    """aces: iterable of (ace_type, ace_flags, access_mask, sid) as read from the DACL, or None for a NULL DACL."""
    if level not in (PRIVATE, NOT_WRITABLE) or not user_sid:
        return False
    if owner_sid not in ({user_sid} | TRUSTED_SIDS):
        return False
    if aces is None:                                      # NULL DACL: everyone has full access
        return False
    for ace_type, ace_flags, mask, sid in aces:
        if ace_type == ACCESS_DENIED_ACE_TYPE:           # a deny only takes access away
            continue
        if ace_type != ACCESS_ALLOWED_ACE_TYPE:           # object/callback/audit ACEs: not understood → fail closed
            return False
        if ace_flags & INHERIT_ONLY_ACE:                  # applies to children only, not to this object
            continue
        if sid == user_sid or sid in TRUSTED_SIDS:
            continue
        effective = mask & ~SYNCHRONIZE
        if level == PRIVATE and effective:
            return False
        if level == NOT_WRITABLE and effective & _WRITE_RIGHTS:
            return False
    return True


def evaluate_posix(st_uid: int, st_mode: int, uid: int, level: str) -> bool:
    if level == PRIVATE:
        return st_uid == uid and not (st_mode & 0o077)
    if level == NOT_WRITABLE:
        return st_uid in (uid, 0) and not (st_mode & 0o022)
    return False


def _windows_security(path: str):
    """(owner_sid, aces or None, current_user_sid) through advapi32. Raises FileSecurityError on any failure."""
    import ctypes
    from ctypes import wintypes

    advapi32 = ctypes.WinDLL("advapi32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    PVOID = ctypes.c_void_p

    class ACL_SIZE_INFORMATION(ctypes.Structure):
        _fields_ = [("AceCount", wintypes.DWORD), ("AclBytesInUse", wintypes.DWORD), ("AclBytesFree", wintypes.DWORD)]

    class ACE_HEADER(ctypes.Structure):
        _fields_ = [("AceType", ctypes.c_ubyte), ("AceFlags", ctypes.c_ubyte), ("AceSize", wintypes.WORD)]

    class ACCESS_ALLOWED_ACE(ctypes.Structure):
        _fields_ = [("Header", ACE_HEADER), ("Mask", wintypes.DWORD), ("SidStart", wintypes.DWORD)]

    GetNamedSecurityInfoW = advapi32.GetNamedSecurityInfoW
    GetNamedSecurityInfoW.argtypes = [wintypes.LPCWSTR, ctypes.c_int, wintypes.DWORD, ctypes.POINTER(PVOID), ctypes.POINTER(PVOID),
                                      ctypes.POINTER(PVOID), ctypes.POINTER(PVOID), ctypes.POINTER(PVOID)]
    GetNamedSecurityInfoW.restype = wintypes.DWORD
    ConvertSidToStringSidW = advapi32.ConvertSidToStringSidW
    ConvertSidToStringSidW.argtypes = [PVOID, ctypes.POINTER(wintypes.LPWSTR)]
    ConvertSidToStringSidW.restype = wintypes.BOOL
    GetAclInformation = advapi32.GetAclInformation
    GetAclInformation.argtypes = [PVOID, PVOID, wintypes.DWORD, ctypes.c_int]
    GetAclInformation.restype = wintypes.BOOL
    GetAce = advapi32.GetAce
    GetAce.argtypes = [PVOID, wintypes.DWORD, ctypes.POINTER(PVOID)]
    GetAce.restype = wintypes.BOOL
    OpenProcessToken = advapi32.OpenProcessToken
    OpenProcessToken.argtypes = [wintypes.HANDLE, wintypes.DWORD, ctypes.POINTER(wintypes.HANDLE)]
    OpenProcessToken.restype = wintypes.BOOL
    GetTokenInformation = advapi32.GetTokenInformation
    GetTokenInformation.argtypes = [wintypes.HANDLE, ctypes.c_int, PVOID, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    GetTokenInformation.restype = wintypes.BOOL
    GetCurrentProcess = kernel32.GetCurrentProcess
    GetCurrentProcess.restype = wintypes.HANDLE
    CloseHandle = kernel32.CloseHandle
    CloseHandle.argtypes = [wintypes.HANDLE]
    LocalFree = kernel32.LocalFree
    LocalFree.argtypes = [PVOID]

    def sid_str(psid):
        out = wintypes.LPWSTR()
        if not psid or not ConvertSidToStringSidW(psid, ctypes.byref(out)):
            raise FileSecurityError()
        try:
            return out.value
        finally:
            LocalFree(ctypes.cast(out, PVOID))

    # current user SID from the process token
    token = wintypes.HANDLE()
    if not OpenProcessToken(GetCurrentProcess(), 0x0008, ctypes.byref(token)):       # TOKEN_QUERY
        raise FileSecurityError()
    try:
        size = wintypes.DWORD(0)
        GetTokenInformation(token, 1, None, 0, ctypes.byref(size))                    # TokenUser
        if not size.value or size.value > 4096:
            raise FileSecurityError()
        buf = ctypes.create_string_buffer(size.value)
        if not GetTokenInformation(token, 1, buf, size, ctypes.byref(size)):
            raise FileSecurityError()
        user_sid = sid_str(ctypes.cast(buf, ctypes.POINTER(PVOID))[0])               # TOKEN_USER.User.Sid
    finally:
        CloseHandle(token)

    owner, dacl, sd = PVOID(), PVOID(), PVOID()
    rc = GetNamedSecurityInfoW(path, 1, 0x1 | 0x4, ctypes.byref(owner), None, ctypes.byref(dacl), None, ctypes.byref(sd))
    if rc != 0:                                                                         # SE_FILE_OBJECT, OWNER|DACL
        raise FileSecurityError()
    try:
        owner_sid = sid_str(owner)
        if not dacl:
            return owner_sid, None, user_sid
        info = ACL_SIZE_INFORMATION()
        if not GetAclInformation(dacl, ctypes.byref(info), ctypes.sizeof(info), 2):     # AclSizeInformation
            raise FileSecurityError()
        aces = []
        for i in range(min(info.AceCount, 256)):
            pace = PVOID()
            if not GetAce(dacl, i, ctypes.byref(pace)):
                raise FileSecurityError()
            hdr = ctypes.cast(pace, ctypes.POINTER(ACE_HEADER)).contents
            if hdr.AceType in (ACCESS_ALLOWED_ACE_TYPE, ACCESS_DENIED_ACE_TYPE):
                ace = ctypes.cast(pace, ctypes.POINTER(ACCESS_ALLOWED_ACE)).contents
                sid = sid_str(pace.value + ACCESS_ALLOWED_ACE.SidStart.offset)
                aces.append((hdr.AceType, hdr.AceFlags, ace.Mask, sid))
            else:
                aces.append((hdr.AceType, hdr.AceFlags, 0, ""))
        if info.AceCount > 256:
            raise FileSecurityError()
        return owner_sid, aces, user_sid
    finally:
        LocalFree(sd)


def is_private(path: str, level: str = PRIVATE) -> bool:
    """True when `path` (file or directory, not a symlink) meets `level` on this OS. Never raises."""
    try:
        st = os.lstat(path)
        if stat.S_ISLNK(st.st_mode):
            return False
        if os.name == "posix" and hasattr(os, "getuid"):
            return evaluate_posix(st.st_uid, st.st_mode, os.getuid(), level)
        if sys.platform == "win32":
            owner_sid, aces, user_sid = _windows_security(path)
            return evaluate_windows_acl(owner_sid, aces, user_sid, level)
    except (OSError, FileSecurityError, ValueError, AttributeError):
        return False
    return False                                            # unknown platform: fail closed


def how_to_fix(level: str = PRIVATE) -> str:
    """Fixed, platform-specific hint for operator messages (never contains the path)."""
    if sys.platform == "win32":
        return ("remove inherited access and grant only your user: icacls <path> /inheritance:r /grant:r \"%USERNAME%:F\""
                if level == PRIVATE else "make sure only your user, SYSTEM and Administrators can modify it")
    return "chmod 600 (files) or 700 (directories)" if level == PRIVATE else "chmod go-w"
