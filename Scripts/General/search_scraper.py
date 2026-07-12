import asyncio
import aiohttp
from bs4 import BeautifulSoup
import urllib.parse
import re
import sys
import tty
import termios
import argparse
import webbrowser
import subprocess
import shutil

def copy_to_clipboard(text):
    """Copies text to system clipboard using available platform binaries."""
    try:
        if shutil.which("xclip"):
            subprocess.run(["xclip", "-selection", "clipboard"], input=text.encode(), check=True)
            return True
        elif shutil.which("xsel"):
            subprocess.run(["xsel", "--clipboard", "--input"], input=text.encode(), check=True)
            return True
        elif shutil.which("pbcopy"):
            subprocess.run(["pbcopy"], input=text.encode(), check=True)
            return True
        elif shutil.which("clip"):
            subprocess.run(["clip"], input=text.encode(), check=True)
            return True
    except Exception:
        pass
    return False




# Configuration
BASE_URL = "https://www.skidrowreloaded.com"
SEARCH_PATH = "/?s="
PAGE_PATH = "/page/{}/?s={}"

# Custom headers to simulate a normal browser request
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5"
}

async def fetch_page(session, url, retries=2):
    """Fetches the HTML content of a URL asynchronously with optional retries."""
    for attempt in range(retries + 1):
        try:
            async with session.get(url, headers=HEADERS, timeout=15) as response:
                if response.status == 200:
                    return await response.text()
                elif response.status in [429, 503] and attempt < retries:
                    await asyncio.sleep(1.5 * (attempt + 1))
                else:
                    if attempt == retries:
                        print(f"Error fetching {url}: HTTP {response.status} (Attempt {attempt+1}/{retries+1})")
                        return None
        except Exception as e:
            if attempt == retries:
                print(f"Exception fetching {url}: {e} (Attempt {attempt+1}/{retries+1})")
                return None
            await asyncio.sleep(1.0)
    return None

def parse_search_results(html):
    """Parses a search result page to extract titles and links from WordPress posts."""
    if not html:
        return []
    
    soup = BeautifulSoup(html, 'html.parser')
    results = []
    
    # Typical WordPress post containers
    posts = soup.find_all('div', class_='post') or soup.find_all('article') or soup.find_all('div', class_='post-content')
    
    for post in posts:
        # Search for post titles inside h2 tags (typical for WordPress blogs)
        title_elem = post.find('h2') or post.find('h1') or post.find('a', class_='post-title')
        if title_elem:
            link_elem = title_elem.find('a') if not title_elem.name == 'a' else title_elem
            if link_elem and link_elem.has_attr('href'):
                title = link_elem.get_text(strip=True)
                link = link_elem['href']
                
                # Retrieve any snippet text if available
                excerpt_elem = post.find('div', class_='entry') or post.find('div', class_='entry-content') or post.find('p')
                excerpt = excerpt_elem.get_text(strip=True) if excerpt_elem else ""
                
                results.append({
                    'title': title,
                    'link': link,
                    'excerpt': excerpt[:150] + "..." if len(excerpt) > 150 else excerpt
                })
            
    return results

def get_max_pages(html):
    """Determines the total number of pages from pagination elements (e.g., wp-pagenavi)."""
    if not html:
        return 1
    
    soup = BeautifulSoup(html, 'html.parser')
    
    # Common pagination containers in WordPress
    pagination = (
        soup.find('div', class_='wp-pagenavi') or 
        soup.find('div', class_='pagination') or 
        soup.find('div', class_='nav-links') or
        soup.find('div', class_='pages')
    )
    if not pagination:
        return 1
        
    page_numbers = []
    for link in pagination.find_all('a'):
        text = link.get_text(strip=True)
        # Filter out navigation arrows/words (like 'Next', 'Last', '»')
        if text.isdigit():
            page_numbers.append(int(text))
            
    # Include current active page class if present (wp-pagenavi uses span for current page)
    current_page = pagination.find('span', class_='current')
    if current_page:
        text = current_page.get_text(strip=True)
        if text.isdigit():
            page_numbers.append(int(text))
            
    return max(page_numbers) if page_numbers else 1

def parse_release_info(title):
    """Parses version, build, or date from the post title for sorting."""
    # Try to match a build number, e.g. "Build 6160665"
    build_match = re.search(r'[Bb]uild\s+(\d+)', title)
    if build_match:
        return {'type': 'build', 'val': int(build_match.group(1))}
        
    # Try to match a date in format DD.MM.YYYY
    date_match = re.search(r'(\d{1,2})\.(\d{1,2})\.(\d{4})', title)
    if date_match:
        d, m, y = map(int, date_match.groups())
        return {'type': 'date', 'val': (y, m, d)}
        
    # Try to match version like "v4.1.9" or "v20260128" or "1.1.0a"
    version_match = re.search(r'[vv]?(\d+(?:\.\d+)+[a-zA-Z]?)', title)
    if version_match:
        version_str = version_match.group(1)
        # Split version parts into numeric/alphabetic values for tuple comparison
        parts = []
        for p in re.split(r'(\d+)', version_str):
            if p.isdigit():
                parts.append(int(p))
            elif p:
                parts.append(p)
        return {'type': 'version', 'val': tuple(parts)}
        
    return {'type': 'other', 'val': title}

async def fetch_and_parse_details(session, url):
    """Fetches a game's detail page and extracts download mirrors from the tabs/extended post."""
    html = await fetch_page(session, url)
    if not html:
        return []
        
    soup = BeautifulSoup(html, 'html.parser')
    
    # Locate main tab content container
    tab_content = soup.find('div', id=lambda val: val and val.startswith('tabs-') and val.endswith('-0'))
    if not tab_content:
        tab_content = soup.find('div', class_='wordpress-post-tabs') or soup.find('div', class_='post-extended')
        
    mirrors = []
    if tab_content:
        for a_tag in tab_content.find_all('a'):
            href = a_tag.get('href')
            if not href or 'skidrowreloaded.com' in href or 'steampowered.com' in href:
                continue
                
            parent = a_tag.parent
            strong_tag = parent.find('strong') or parent.find('span')
            host_name = strong_tag.get_text(strip=True) if strong_tag else parent.get_text(strip=True)
            
            # Clean up the host name label
            host_name = re.sub(r'[^a-zA-Z0-9\s\.\-]', '', host_name).strip()
            
            # If name is missing or too long, fallback to the domain name of the link
            if not host_name or len(host_name) > 30:
                try:
                    host_name = href.split('/')[2].replace('www.', '')
                except IndexError:
                    host_name = "DOWNLOAD"
                    
            mirrors.append({'host': host_name.upper(), 'url': href})
            
    return mirrors

async def check_mirror_status(session, mirror, semaphore):
    """Checks the status of a mirror URL concurrently with semaphore rate-limiting and optimized HEAD requests."""
    async with semaphore:
        url = mirror['url']
        
        # Check ad-shorteners first
        ad_shorteners = ["ouo.io", "ouo.press", "shrinkme.io", "adf.ly", "bit.ly", "cuty.io", "shrinkearn.com", "gplinks.in", "gplinks.co", "shortzon.com"]
        if any(ad in url.lower() for ad in ad_shorteners):
            return {**mirror, 'status': 'DEAD (Ad-Shortener Link)', 'alive': False}
            
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        
        # ISP block patterns (such as local DoT blocking pages returning HTTP 200)
        isp_triggers = [
            "requested url has been blocked",
            "department of telecommunications",
            "blocked as per the directions",
            "keralavision",
            "access to this website has been blocked",
            "government of india",
            "airtel.in",
            "court-orders"
        ]
        
        try:
            # Pre-filter services known to be shut down or skipped
            inactive_services = ['zippyshare.com', 'anonfiles.com', 'bayfiles.com', 'letsupload.io', 'uptobox.com', 'yadi.sk', 'yandex', 'yadex']
            if any(service in url.lower() for service in inactive_services):
                return {**mirror, 'status': 'DEAD (Service Offline/Skipped)', 'alive': False}

            # 1. GoFile Handler (uses direct GoFile API to check file existence)
            if 'gofile.io' in url.lower():
                content_id = None
                if '?c=' in url:
                    content_id = url.split('?c=')[-1].split('&')[0]
                elif '/d/' in url:
                    content_id = url.split('/d/')[-1].split('/')[0]
                    
                if content_id:
                    api_url = f"https://api.gofile.io/getContent?contentId={content_id}"
                    async with session.get(api_url, headers=headers, timeout=8) as resp:
                        # Check redirects for ad shorteners
                        for redirect in resp.history:
                            if any(ad in str(redirect.url).lower() for ad in ad_shorteners):
                                return {**mirror, 'status': 'DEAD (Redirected to Ad-Shortener)', 'alive': False}
                        if any(ad in str(resp.url).lower() for ad in ad_shorteners):
                            return {**mirror, 'status': 'DEAD (Redirected to Ad-Shortener)', 'alive': False}
                            
                        body = await resp.text()
                        if any(t in body.lower() for t in isp_triggers):
                            return {**mirror, 'status': 'BLOCKED BY ISP', 'alive': False}
                        if 'error-notFound' in body or 'error-notFound' == body.strip():
                            return {**mirror, 'status': 'DELETED (API)', 'alive': False}
                        return {**mirror, 'status': 'ALIVE', 'alive': True}
                else:
                    return {**mirror, 'status': 'UNVERIFIED (No ID)', 'alive': True}

            # 2. Pixeldrain Handler
            elif 'pixeldra.in' in url.lower() or 'pixeldrain' in url.lower():
                file_id = url.split('/')[-1]
                api_url = f"https://pixeldrain.com/api/file/{file_id}/info"
                async with session.get(api_url, headers=headers, timeout=8) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        if data.get('success') is False:
                            return {**mirror, 'status': 'DELETED (API)', 'alive': False}
                        return {**mirror, 'status': 'ALIVE', 'alive': True}
                    elif resp.status == 404:
                        return {**mirror, 'status': 'DELETED (404)', 'alive': False}
                    else:
                        return {**mirror, 'status': f'UNKNOWN (HTTP {resp.status})', 'alive': False}
                        
            # 3. Mediafire Handler
            elif 'mediafire.com' in url.lower():
                async with session.get(url, headers=headers, timeout=8) as resp:
                    body = await resp.text()
                    if any(t in body.lower() for t in isp_triggers):
                        return {**mirror, 'status': 'BLOCKED BY ISP', 'alive': False}
                    if resp.status == 200:
                        down_triggers = [
                            "attempted to download has been removed",
                            "violating our terms of service",
                            "dangerous file blocked",
                            "invalid or deleted file",
                            "file no longer available"
                        ]
                        if any(t in body.lower() for t in down_triggers):
                            return {**mirror, 'status': 'DELETED/BLOCKED', 'alive': False}
                        return {**mirror, 'status': 'ALIVE', 'alive': True}
                    else:
                        return {**mirror, 'status': f'DOWN (HTTP {resp.status})', 'alive': False}
                        
            # 4. Turbobit & Hitfile Handler
            elif 'turbobit.net' in url.lower() or 'hitfile.net' in url.lower():
                async with session.get(url, headers=headers, timeout=8) as resp:
                    body = await resp.text()
                    if any(t in body.lower() for t in isp_triggers):
                        return {**mirror, 'status': 'BLOCKED BY ISP', 'alive': False}
                    if resp.status == 200:
                        soup = BeautifulSoup(body, 'html.parser')
                        title = soup.find('title')
                        title_text = title.get_text(strip=True) if title else ""
                        if not title_text:
                            return {**mirror, 'status': 'DELETED (Empty Title)', 'alive': False}
                        
                        down_triggers = [
                            "attempted to download has been removed",
                            "violating our terms of service",
                            "dangerous file blocked",
                            "invalid or deleted file",
                            "file no longer available",
                            "file not found"
                        ]
                        if any(t in body.lower() for t in down_triggers):
                            return {**mirror, 'status': 'DELETED/BLOCKED', 'alive': False}
                        return {**mirror, 'status': 'ALIVE', 'alive': True}
                    else:
                        return {**mirror, 'status': f'DOWN (HTTP {resp.status})', 'alive': False}

            # 5. Generic Host Handler with HEAD optimization
            else:
                # Try HEAD request first for fast verification
                try:
                    async with session.head(url, headers=headers, timeout=5, allow_redirects=True) as resp:
                        # Check redirects for ad shorteners
                        for redirect in resp.history:
                            if any(ad in str(redirect.url).lower() for ad in ad_shorteners):
                                return {**mirror, 'status': 'DEAD (Redirected to Ad-Shortener)', 'alive': False}
                        if any(ad in str(resp.url).lower() for ad in ad_shorteners):
                            return {**mirror, 'status': 'DEAD (Redirected to Ad-Shortener)', 'alive': False}

                        if resp.status in [404, 410]:
                            return {**mirror, 'status': 'DELETED (HEAD 404/410)', 'alive': False}
                        elif resp.status == 200:
                            return {**mirror, 'status': 'ALIVE (HEAD)', 'alive': True}
                except Exception:
                    # Fallback to full GET if HEAD fails
                    pass

                async with session.get(url, headers=headers, timeout=8) as resp:
                    for redirect in resp.history:
                        if any(ad in str(redirect.url).lower() for ad in ad_shorteners):
                            return {**mirror, 'status': 'DEAD (Redirected to Ad-Shortener)', 'alive': False}
                    if any(ad in str(resp.url).lower() for ad in ad_shorteners):
                        return {**mirror, 'status': 'DEAD (Redirected to Ad-Shortener)', 'alive': False}

                    if resp.status in [404, 410]:
                        return {**mirror, 'status': 'DELETED (404/410)', 'alive': False}
                    
                    body = (await resp.read())[:15000].decode('utf-8', errors='ignore')
                    
                    # Follow JavaScript redirects
                    for _ in range(2):
                        js_redirect = re.search(r"(?:window\.location\.replace|window\.location)\s*\(\s*['\"]([^'\"]+)['\"]\s*\)", body) or re.search(r"(?:window\.location\.replace|window\.location)\s*=\s*['\"]([^'\"]+)['\"]", body)
                        if js_redirect:
                            redirect_url = js_redirect.group(1)
                            if redirect_url.startswith('/'):
                                from urllib.parse import urljoin
                                redirect_url = urljoin(url, redirect_url)
                            async with session.get(redirect_url, headers=headers, timeout=8) as redirect_resp:
                                if redirect_resp.status == 200:
                                    body = (await redirect_resp.read())[:15000].decode('utf-8', errors='ignore')
                                else:
                                    return {**mirror, 'status': f'DOWN (Redirect HTTP {redirect_resp.status})', 'alive': False}
                        else:
                            break
                    
                    body_lower = body.lower()
                    if any(t in body_lower for t in isp_triggers):
                        return {**mirror, 'status': 'BLOCKED BY ISP', 'alive': False}
                    
                    if resp.status == 200:
                        generic_triggers = [
                            "file has been deleted",
                            "file was deleted",
                            "no longer exists",
                            "file not found",
                            "key has been deleted",
                            "file is no longer available",
                            "has been removed",
                            "link has expired",
                            "file no longer exists",
                            "the requested file has been deleted",
                            "could not be found",
                            "doesn't exist",
                            "does not exist",
                            "file you were looking for",
                            "may have been deleted",
                            "not found on this server"
                        ]
                        if any(t in body_lower for t in generic_triggers):
                            return {**mirror, 'status': 'DELETED (Content)', 'alive': False}
                        return {**mirror, 'status': 'ALIVE', 'alive': True}
                    else:
                        return {**mirror, 'status': f'UNVERIFIED (HTTP {resp.status})', 'alive': True}
                        
        except asyncio.TimeoutError:
            return {**mirror, 'status': 'TIMEOUT', 'alive': False}
        except aiohttp.ClientConnectorDNSError:
            return {**mirror, 'status': 'DNS BLOCKED/ERROR', 'alive': False}
        except aiohttp.ClientSSLError:
            return {**mirror, 'status': 'SSL ERROR', 'alive': False}
        except aiohttp.ClientConnectorError as e:
            err_msg = str(e).lower()
            if "connection refused" in err_msg:
                return {**mirror, 'status': 'CONNECTION REFUSED', 'alive': False}
            elif "connection reset" in err_msg:
                return {**mirror, 'status': 'CONNECTION RESET', 'alive': False}
            return {**mirror, 'status': f'CONNECTION ERROR ({type(e).__name__})', 'alive': False}
        except Exception as e:
            return {**mirror, 'status': f'ERROR ({type(e).__name__})', 'alive': False}


async def get_steam_suggestions(session, term):
    """Fetches game suggestions from the public Steam Store Search API."""
    url = f"https://store.steampowered.com/api/storesearch/?term={urllib.parse.quote_plus(term)}&l=english&cc=US"
    try:
        async with session.get(url, timeout=5) as response:
            if response.status == 200:
                data = await response.json()
                items = data.get('items', [])
                return [item['name'] for item in items if item.get('type') == 'app']
    except Exception:
        pass
    return []

class AsyncInputReader:
    def __init__(self):
        self.fd = sys.stdin.fileno()
        self.old_settings = termios.tcgetattr(self.fd)

    def make_raw(self):
        tty.setraw(self.fd)

    def restore(self):
        termios.tcsetattr(self.fd, termios.TCSADRAIN, self.old_settings)

    async def read_char(self):
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, sys.stdin.read, 1)

async def run_interactive_typeahead(session):
    """Runs a real-time typeahead interactive terminal suggestion autocomplete using a shared connection session."""
    print("Real-time Game Search (Type to find, Tab to cycle suggestions, Enter to search):")
    
    query = ""
    suggestions = []
    suggestion_index = 0
    lines_displayed = 0
    
    def redraw(show_loader=False, cycle_suggestions=False):
        nonlocal lines_displayed
        
        # 1. Move cursor back to the query line if suggestions/loader were displayed
        if lines_displayed > 0:
            sys.stdout.write(f"\033[{lines_displayed}A")
            
        # 2. Clear everything from the query line down
        sys.stdout.write("\r\033[J")
        
        # 3. Print the current query line
        sys.stdout.write(f"Search: {query}")
        
        # 4. Draw what's below the query line
        lines_displayed = 0
        if show_loader:
            sys.stdout.write("\n\033[1;30m  (searching suggestions...)\033[0m")
            lines_displayed = 1
        elif suggestions:
            sys.stdout.write("\n\033[1;36mSuggestions (Press Tab to cycle suggestions):\033[0m")
            lines_displayed = 1
            for i, s in enumerate(suggestions[:5]):
                is_selected = cycle_suggestions and (i == (suggestion_index - 1) % len(suggestions))
                if is_selected:
                    sys.stdout.write(f"\n  -> \033[1;33m{s}\033[0m")
                else:
                    sys.stdout.write(f"\n  - {s}")
                lines_displayed += 1
                
        # 5. Move cursor back to the query line and place it at the end of query text
        if lines_displayed > 0:
            sys.stdout.write(f"\033[{lines_displayed}A")
        col = 8 + len(query)
        sys.stdout.write(f"\r\033[{col}C")
        sys.stdout.flush()

    reader = AsyncInputReader()
    reader.make_raw()
    debounce_task = None
    
    # Draw initial blank search prompt
    redraw()
    
    try:
        while True:
            char = await reader.read_char()
            
            # Enter key
            if char in ('\r', '\n'):
                break
            # Backspace
            elif char in ('\x7f', '\x08'):
                if len(query) > 0:
                    query = query[:-1]
                suggestion_index = 0
            # Tab - cycle through suggestions
            elif char == '\t':
                if suggestions:
                    query = suggestions[suggestion_index % len(suggestions)]
                    suggestion_index += 1
                    
                    reader.restore()
                    redraw(show_loader=False, cycle_suggestions=True)
                    reader.make_raw()
                    continue  # Avoid resetting index or fetching suggestions
            # Escape
            elif ord(char) == 27:
                query = ""
                break
            # Printable characters
            elif 32 <= ord(char) <= 126:
                query += char
                suggestion_index = 0
                
            # Update input display and clear stale suggestions immediately
            show_loader = (len(query) >= 2)
            suggestions = []  # Clear immediately
            reader.restore()
            redraw(show_loader=show_loader)
            reader.make_raw()
            
            # Debounce suggestions request (200ms)
            if debounce_task:
                debounce_task.cancel()
                
            async def fetch_suggestions_after_delay(q):
                await asyncio.sleep(0.20)
                sugs = await get_steam_suggestions(session, q)
                nonlocal suggestions
                suggestions = sugs
                reader.restore()
                redraw(show_loader=False)
                reader.make_raw()
                
            if len(query) >= 2:
                debounce_task = asyncio.create_task(fetch_suggestions_after_delay(query))
                
    finally:
        reader.restore()
        # Cleanly clear suggestions from screen before ending the typeahead
        suggestions = []
        redraw(show_loader=False)
        sys.stdout.write("\n")
        sys.stdout.flush()
        
    return query.strip()

async def run_search_pipeline(session, query, no_verify=False, auto_open=False):
    """Executes the complete Skidrow search and mirror validation pipeline."""
    encoded_query = urllib.parse.quote_plus(query)
    first_page_url = f"{BASE_URL}{SEARCH_PATH}{encoded_query}"
    
    print(f"Searching Skidrow for '{query}'...")
    
    # Step 1: Fetch the first page to get initial results and determine total pages
    first_page_html = await fetch_page(session, first_page_url)
    if not first_page_html:
        print("Failed to retrieve initial search results.")
        return
        
    results = parse_search_results(first_page_html)
    max_pages = get_max_pages(first_page_html)
    print(f"Found {len(results)} results on page 1. Total pages: {max_pages}")
    
    # Step 2: Fetch remaining pages concurrently
    if max_pages > 1:
        tasks = []
        
        async def fetch_and_log_page(p, url):
            html = await fetch_page(session, url)
            print(f"  [+] Fetched search results page {p}/{max_pages}...")
            return html
            
        for page in range(2, max_pages + 1):
            page_url = f"{BASE_URL}{PAGE_PATH.format(page, encoded_query)}"
            tasks.append(fetch_and_log_page(page, page_url))
            
        print(f"[Fetch] Fetching remaining {max_pages - 1} pages concurrently...")
        pages_html = await asyncio.gather(*tasks)
        
        for page_html in pages_html:
            page_results = parse_search_results(page_html)
            results.extend(page_results)
            
    # Step 3: Sort and Group results
    direct_matches = []
    related_matches = []
    
    for item in results:
        if query.lower() in item['title'].lower():
            item['info'] = parse_release_info(item['title'])
            direct_matches.append(item)
        else:
            related_matches.append(item)
            
    # Group direct matches by build/version/date
    builds = [item for item in direct_matches if item['info']['type'] == 'build']
    versions = [item for item in direct_matches if item['info']['type'] == 'version']
    dates = [item for item in direct_matches if item['info']['type'] == 'date']
    others = [item for item in direct_matches if item['info']['type'] == 'other']
    
    # Sort sub-groups descending (newest/highest first)
    builds.sort(key=lambda x: x['info']['val'], reverse=True)
    versions.sort(key=lambda x: x['info']['val'], reverse=True)
    dates.sort(key=lambda x: x['info']['val'], reverse=True)
    others.sort(key=lambda x: x['info']['val'].lower())
    
    # Step 4: Pull in the latest build's download mirrors automatically
    latest_item = None
    if builds:
        latest_item = builds[0]
    elif versions:
        latest_item = versions[0]
    elif dates:
        latest_item = dates[0]
    elif others:
        latest_item = others[0]
        
    latest_mirrors = []
    if latest_item and not no_verify:
        print(f"\n[Latest Release] Automatically fetching mirrors for: {latest_item['title']}...")
        raw_mirrors = await fetch_and_parse_details(session, latest_item['link'])
        if raw_mirrors:
            print(f"[Verification] Verifying {len(raw_mirrors)} download mirrors concurrently (max 12 workers)...")
            
            semaphore = asyncio.Semaphore(12)
            checked_count = 0
            total_mirrors = len(raw_mirrors)
            
            async def check_and_log(mirror):
                nonlocal checked_count
                result = await check_mirror_status(session, mirror, semaphore)
                checked_count += 1
                status_indicator = "🟢" if result['alive'] else "🔴"
                if result['alive'] and 'ALIVE' not in result['status']:
                    status_indicator = "🟡"
                print(f"  [{checked_count}/{total_mirrors}] {status_indicator} {result['host']}: {result['status']}")
                return result
            
            tasks = [check_and_log(m) for m in raw_mirrors]
            latest_mirrors = await asyncio.gather(*tasks)
        
    # Output results
    print(f"\nTotal Search Results Found: {len(results)}")
    print("="*60)
    print(f"DIRECT MATCHES FOR '{query.upper()}' (Sorted Newest to Oldest)")
    print("="*60)
    
    count = 1
    if builds:
        print("\n--- STEAM BUILDS ---")
        for item in builds:
            print(f"{count:2d}. {item['title']}")
            print(f"    Link: {item['link']}")
            count += 1
            
    if versions:
        print("\n--- VERSION RELEASES ---")
        for item in versions:
            print(f"{count:2d}. {item['title']}")
            print(f"    Link: {item['link']}")
            count += 1
            
    if dates or others:
        print("\n--- DATE-BASED & OTHER RELEASES ---")
        for item in (dates + others):
            print(f"{count:2d}. {item['title']}")
            print(f"    Link: {item['link']}")
            count += 1
            
    if not direct_matches:
        print("No direct title matches found.")
        
    if related_matches:
        print("\n" + "="*60)
        print("RELATED RESULTS (Matched via tags/excerpt content)")
        print("="*60)
        for item in related_matches:
            print(f"{count:2d}. {item['title']}")
            print(f"    Link: {item['link']}")
            if item['excerpt']:
                clean_exc = " ".join(item['excerpt'].split())
                print(f"    Details: {clean_exc}")
            print("-" * 50)
            count += 1

    # Print mirrors for the latest release if found
    if latest_item and latest_mirrors:
        print("\n" + "="*60)
        print(f"VERIFIED DOWNLOAD MIRRORS FOR LATEST BUILD: {latest_item['title']}")
        print("="*60)
        
        recommended = []
        other_live = []
        unverified = []
        dead = []
        
        for m in latest_mirrors:
            url_lower = m['url'].lower()
            is_recommended_host = ('pixeldra.in' in url_lower or 'pixeldrain' in url_lower or 'mediafire.com' in url_lower)
            
            if m['alive'] and is_recommended_host and 'ALIVE' in m['status']:
                recommended.append(m)
            elif m['alive'] and 'ALIVE' in m['status']:
                other_live.append(m)
            elif m['alive']:
                unverified.append(m)
            else:
                dead.append(m)
                
        target_link = None
        
        if recommended:
            print("\n[RECOMMENDED MIRRORS] (PixelDrain / Mediafire)")
            for m in recommended:
                print(f"  🟢 {m['host']}: {m['url']}")
            target_link = recommended[0]['url']
                
        if other_live:
            print("\n[OTHER LIVE MIRRORS]")
            for m in other_live:
                print(f"  🟢 {m['host']}: {m['url']}")
            if not target_link:
                target_link = other_live[0]['url']
                
        if unverified:
            print("\n[UNVERIFIED / TIMEOUTS] (May still work)")
            for m in unverified:
                print(f"  🟡 {m['host']} ({m['status']}): {m['url']}")
            if not target_link:
                target_link = unverified[0]['url']
                
        if dead:
            print("\n[DEAD / REMOVED MIRRORS]")
            for m in dead:
                print(f"  🔴 {m['host']} ({m['status']}): {m['url']}")
        print("\n" + "="*60)
        
        if target_link:
            # Clipboard copying
            copied = copy_to_clipboard(target_link)
            if copied:
                print(f"\n📋 Copied best mirror link to clipboard: {target_link}")
            else:
                print(f"\n🔗 Best mirror link: {target_link}")
                
            # Browser launching
            if auto_open:
                print("🌐 Auto-opening recommended mirror link in browser...")
                webbrowser.open(target_link)
            elif sys.stdin.isatty():
                try:
                    choice = input("\nDo you want to open this link in your browser? [Y/n]: ").strip().lower()
                    if choice in ('', 'y', 'yes'):
                        print("🌐 Opening link in browser...")
                        webbrowser.open(target_link)
                except (IOError, KeyboardInterrupt):
                    pass
                    
    elif latest_item:
        print("\n" + "="*60)
        if no_verify:
            print(f"Download mirror verification was skipped for: {latest_item['title']}\nDetails link: {latest_item['link']}")
        else:
            print(f"No active download mirrors found on the detail page of: {latest_item['title']}")
        print("="*60)

async def main():
    parser = argparse.ArgumentParser(description="Skidrow Search & Verification Scraper")
    parser.add_argument("query", nargs="?", default=None, help="Game title to search for (bypasses interactive prompt)")
    parser.add_argument("--no-verify", action="store_true", help="Skip verifying download mirrors")
    parser.add_argument("--auto-open", action="store_true", help="Automatically open the best recommended mirror link in browser")
    args = parser.parse_args()

    # Share single aiohttp ClientSession connection pool
    connector = aiohttp.TCPConnector(ssl=False)
    async with aiohttp.ClientSession(connector=connector) as session:
        query = args.query
        if not query:
            if not sys.stdin.isatty():
                query = input("Enter the game to search for: ").strip()
            else:
                query = await run_interactive_typeahead(session)
                
        if not query:
            print("Empty search query.")
            return
            
        await run_search_pipeline(session, query, no_verify=args.no_verify, auto_open=args.auto_open)

if __name__ == "__main__":
    asyncio.run(main())
