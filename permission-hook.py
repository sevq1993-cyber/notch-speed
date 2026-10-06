#!/usr/bin/env python3
"""Claude Code PermissionRequest hook: ask in the notch first.

The request is dropped into ~/.cache/claude-speed/permissions/<id>.json for the ClaudeSpeed app; the app
writes <id>.answer: "allow" / "deny", or "pass" when the app hosting this session (Claude desktop, a terminal)
is in front, since the user then sees Claude Code's own dialog. "pass", no app running, or no answer within
the timeout → no output, so Claude Code shows its own permission dialog. Only one-off decisions are made here.
"""
import json
import os
import re
import sys
import time
import uuid

DIR = os.path.expanduser("~/.cache/claude-speed/permissions")
APP_PID = os.path.expanduser("~/.cache/claude-speed/app.pid")
TIMEOUT = float(os.environ.get("CLAUDE_SPEED_PERM_TIMEOUT", "30"))
POLL = 0.15

# commands that destroy or overwrite things: the notch asks to hold the button instead of a click
DANGER = re.compile(
    r"\brm\s|\s-delete\b|\bgit\s+(push\b.*\s(-f|--force)|reset\s+--hard|clean\s+-\w*f|branch\s+-D)|"
    r"\bsudo\b|\bmkfs|\bdd\s|\bchmod\s+-R|\bchown\s+-R|\bkill(all)?\s|>\s*/dev/|\btruncate\b|"
    r"\bdrop\s+(table|database)\b|\bdocker\s+(rm|rmi|system\s+prune)\b",
    re.I)


def app_alive():
    try:
        with open(APP_PID) as fh:
            os.kill(int(fh.read().strip()), 0)
        return True
    except (OSError, ValueError):
        return False


def summary(tool, inp):
    if tool == "Bash":
        return str(inp.get("command", ""))
    for key in ("file_path", "notebook_path", "url", "pattern", "path"):
        if inp.get(key):
            return str(inp[key])
    return json.dumps(inp, ensure_ascii=False)[:400]


def context(info):
    """Chat title, project and deep link, through collect.py's helpers (best effort)."""
    tp = info.get("transcript_path") or ""
    chat, link = "", None
    try:
        sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
        import collect
        if tp:
            chat = collect.claude_chat_title(collect.tail_lines(tp))
            sid = os.path.basename(tp)[:-len(".jsonl")]
            link = collect.open_url("claude", sid, collect.desktop_session_ids())
    except Exception:
        pass
    return chat, os.path.basename((info.get("cwd") or "").rstrip("/")), link


def wait_answer(path, deadline):
    while time.time() < deadline:
        try:
            with open(path, encoding="utf-8") as fh:
                return fh.read().strip()
        except OSError:
            time.sleep(POLL)
    return None


def main():
    try:
        info = json.load(sys.stdin)
    except ValueError:
        return
    if not app_alive():
        return
    tool = info.get("tool_name") or ""
    text = summary(tool, info.get("tool_input") or {})
    chat, project, link = context(info)
    now = time.time()
    rid = uuid.uuid4().hex
    req = {"id": rid, "src": "claude", "tool": tool, "text": text, "chat": chat, "project": project,
           "open": link, "danger": bool(tool == "Bash" and DANGER.search(text)),
           # the app hosting this session: in front means the user sees the chat's own dialog
           "host": os.environ.get("__CFBundleIdentifier", ""),
           "transcript": info.get("transcript_path") or "",
           "created": now, "expires": now + TIMEOUT}
    os.makedirs(DIR, mode=0o700, exist_ok=True)
    base = os.path.join(DIR, rid)
    answer = None
    try:
        with open(base + ".tmp", "w", encoding="utf-8") as fh:
            json.dump(req, fh, ensure_ascii=False)
        os.replace(base + ".tmp", base + ".json")
        answer = wait_answer(base + ".answer", now + TIMEOUT)
    finally:
        for p in (base + ".json", base + ".answer", base + ".tmp"):
            try:
                os.remove(p)
            except OSError:
                pass
    if answer == "allow":
        decision = {"behavior": "allow"}
    elif answer == "deny":
        decision = {"behavior": "deny", "message": "The user denied this from the ClaudeSpeed notch."}
    else:
        return
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": decision}}))


if __name__ == "__main__":
    main()
