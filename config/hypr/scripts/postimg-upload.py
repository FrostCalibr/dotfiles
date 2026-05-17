from playwright.sync_api import sync_playwright
import requests
import subprocess
import os
from datetime import datetime
import playwright

now = datetime.now()
timestamp = now.strftime("%Y-%m-%d_%H-%M-%S")

#---Change these these variables for your convinience---
SAVE_DIR = os.path.expanduser("~/Pictures/Screenshots")
SCREENSHOT_CMD = "grimblast", "copysave", "area"
CLIPBOARD_CMD = "wl-copy"
NOTIFY = True
#----------------------------------------------------------

subprocess.run([*SCREENSHOT_CMD, f"{SAVE_DIR}/{timestamp}.png"])
with sync_playwright() as p:

    #setting up browser.Note: Headless mode doesnt work for postimg
    browser = p.chromium.launch(headless=False, args=["--window-position=-2000,0"])
    page = browser.new_page()
    page.goto("https://postimages.org")

    #finding the upload Button and uploads
    page.locator('input[type="file"]').set_input_files(f"{SAVE_DIR}/{timestamp}.png")
    
    #Waits for the id Direct to load 
    page.wait_for_selector("#direct")
    
    #Copies the direct link
    direct_link = page.locator("#direct").get_attribute("value")

#Copies the direct link to clipboard
subprocess.run([CLIPBOARD_CMD, direct_link])

#Notifies user using notify. use any notification daemon of your prefrence
if NOTIFY:
    subprocess.run(["notify-send", "Screenshot Uploaded", direct_link])
