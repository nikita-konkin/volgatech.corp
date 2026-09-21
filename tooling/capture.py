"""mitmproxy addon: log request/response pairs as JSONL for API modeling.
Usage: mitmdump -s capture.py --set capfile=flows.jsonl
Optional host filter: --set apihost=substring  (only log flows whose host contains it)
"""
import json, time
from mitmproxy import http, ctx

def load(loader):
    loader.add_option("capfile", str, "flows.jsonl", "Output JSONL path")
    loader.add_option("apihost", str, "", "Only log flows whose host contains this substring")

def _body(msg, limit=200_000):
    try:
        raw = msg.raw_content or b""          # compressed/original bytes (for size)
    except Exception:
        raw = b""
    n = len(raw)
    if n == 0:
        return "", 0
    ct = (msg.headers.get("content-type") or "").lower()
    if any(t in ct for t in ("json","text","xml","x-www-form-urlencoded","javascript")):
        try:
            # mitmproxy .text auto-decodes content-encoding (gzip/br/deflate) + charset
            txt = msg.get_text(strict=False)
            if txt is not None:
                return txt[:limit], n
        except Exception:
            pass
        try:
            return (msg.content or raw)[:limit].decode("utf-8","replace"), n
        except Exception:
            pass
    return f"<binary {n} bytes>", n

def response(flow: http.HTTPFlow):
    host = flow.request.pretty_host
    want = ctx.options.apihost
    if want and want not in host:
        return
    req_body, req_n = _body(flow.request)
    res_body, res_n = _body(flow.response) if flow.response else ("", 0)
    rec = {
        "ts": time.strftime("%Y-%m-%d %H:%M:%S"),
        "method": flow.request.method,
        "scheme": flow.request.scheme,
        "host": host,
        "path": flow.request.path,
        "url": flow.request.pretty_url,
        "status": flow.response.status_code if flow.response else None,
        "req_headers": dict(flow.request.headers),
        "req_body": req_body, "req_len": req_n,
        "res_headers": dict(flow.response.headers) if flow.response else {},
        "res_body": res_body, "res_len": res_n,
    }
    with open(ctx.options.capfile, "a") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    ctx.log.info(f"[cap] {flow.request.method} {host}{flow.request.path} -> {rec['status']}")
