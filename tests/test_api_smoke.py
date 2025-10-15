import os, time, pytest
from playwright.sync_api import Page, expect, APIRequestContext, Playwright

API_URL = os.getenv("API_URL")
assert API_URL, "Set API_URL (e.g., https://.../visitors)"

LATENCY_BUDGET_MS = 1500
RUN_ID = f"smoke-{int(time.time()*1000)}"

@pytest.fixture(scope="session")
def api_request_context(playwright: Playwright) -> APIRequestContext:
    request_context = playwright.request.new_context(base_url=API_URL)
    yield request_context
    request_context.dispose()

def test_api_response_code(api_request_context: APIRequestContext):
    response = api_request_context.get("/")

    status_code = response.status
    print(f"API Response Status Code: {status_code}")

    expect(response).to_be_ok() 


def test_get_returns_json(api_request_context: APIRequestContext):
    t0 = time.time()
    res = api_request_context.get(API_URL)
    dt_ms = (time.time() - t0) * 1000

    assert res.status == 200
    assert "application/json" in (res.headers.get("content-type") or "")
    data = res.json()
    assert isinstance(data.get("view_count"), int)
    assert dt_ms < LATENCY_BUDGET_MS

def test_increments_persist(api_request_context: APIRequestContext):
    r1 = api_request_context.get(API_URL); assert r1.ok
    v1 = r1.json()["view_count"]; assert isinstance(v1, int)
    time.sleep(0.2)  
    r2 = api_request_context.get(API_URL); assert r2.ok
    v2 = r2.json()["view_count"]; assert isinstance(v2, int)
    assert v2 - v1 == 1 

def test_handles_unexpected_input(api_request_context: APIRequestContext):
    bad = api_request_context.post(
        API_URL, headers={"content-type": "text/plain"}, data="nonsense"
    )
    assert bad.status in (400, 405, 415)

    sep = "&" if "?" in API_URL else "?"
    res = api_request_context.get(f"{API_URL}{sep}totally_bogus=1")
    assert res.status in (200, 400)