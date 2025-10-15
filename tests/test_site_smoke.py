import re
from playwright.sync_api import Page, expect

SITE_URL = "https://keeganrdavis.com"

assert SITE_URL, "Set SITE_URL (e.g., https://example.com)"

SELECTOR = "header"

def extract_int(text: str) -> int:
    m = re.search(r"-?\d+", text or "")
    if not m:
        raise AssertionError(f"No integer found in: {text!r}")
    return int(m.group(0))

def test_count_appears_and_changes_across_reload(page: Page):
    page.goto(SITE_URL, wait_until='load')

    el = page.locator(SELECTOR)
    expect(el).to_be_visible(timeout=5000)
    v1 = extract_int(el.inner_text())

    page.reload(wait_until='load')

    el = page.locator(SELECTOR)
    expect(el).to_be_visible(timeout=5000)
    v2 = extract_int(el.inner_text())

    assert v2 - v1 == 1, f"Expected +1, got {v1} -> {v2}"