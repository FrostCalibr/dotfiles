// Global State
let activeProfile = null;
let isConfigured = false;
let activeTab = "recommendations"; // "recommendations" or "discover"
let viewModes = {
    recommendations: "grid",
    discover: "grid"
};
let recommendationList = [];
let discoverList = [];
let swipeDecks = {
    recommendations: [],
    discover: []
};

// Initialize on page load
document.addEventListener("DOMContentLoaded", () => {
    checkStatus();
    initKeyboardGlobal();
});

/**
 * Check if API credentials are configured.
 */
async function checkStatus() {
    try {
        const response = await fetch("/api/status");
        const data = await response.json();
        
        isConfigured = data.configured;
        
        const wizard = document.getElementById("setup-wizard-overlay");
        if (!isConfigured) {
            wizard.classList.remove("hidden");
        } else {
            wizard.classList.add("hidden");
            loadProfile();
        }
    } catch (error) {
        console.error("Error checking status:", error);
    }
}

/**
 * Fetch and load user taste profile details.
 */
async function loadProfile() {
    try {
        const response = await fetch("/api/profile");
        const profile = await response.json();
        activeProfile = profile;
        
        // Update sidebar widgets
        const notesEl = document.getElementById("profile-notes");
        if (profile.notes && profile.notes.trim()) {
            notesEl.textContent = profile.notes;
        } else {
            notesEl.textContent = "Rate some games or describe your favorites to generate a taste profile.";
        }
        
        document.getElementById("liked-count").textContent = profile.liked ? profile.liked.length : 0;
        document.getElementById("disliked-count").textContent = profile.disliked ? profile.disliked.length : 0;
        
        // Update specs
        const specs = profile.system_specs || {};
        document.getElementById("spec-cpu").textContent = specs.cpu || "Not set";
        document.getElementById("spec-gpu").textContent = specs.gpu || "Not set";
        document.getElementById("spec-ram").textContent = specs.ram || "Not set";
        document.getElementById("spec-storage").textContent = specs.storage || "Not set";
        
        const descEl = document.getElementById("spec-desc");
        descEl.textContent = specs.description || "budget PC";
        
        // Pre-fill specs modal inputs
        document.getElementById("input-cpu").value = specs.cpu || "";
        document.getElementById("input-gpu").value = specs.gpu || "";
        document.getElementById("input-ram").value = specs.ram || "";
        document.getElementById("input-storage").value = specs.storage || "";
        document.getElementById("input-desc").value = specs.description || "budget PC";
        
    } catch (error) {
        console.error("Error loading profile:", error);
    }
}

/**
 * Tab Navigation Switcher.
 */
function switchTab(tabName) {
    if (tabName === activeTab) return;
    
    // Toggle active classes on tab buttons
    document.getElementById("tab-btn-recommendations").classList.toggle("active", tabName === "recommendations");
    document.getElementById("tab-btn-discover").classList.toggle("active", tabName === "discover");
    
    // Toggle hidden classes on tab contents
    document.getElementById("recommendations-tab-content").classList.toggle("hidden", tabName !== "recommendations");
    document.getElementById("discover-tab-content").classList.toggle("hidden", tabName !== "discover");
    
    activeTab = tabName;
}

/**
 * Toggle view layout (Grid vs Swipe Deck).
 */
function setViewMode(tab, mode) {
    if (viewModes[tab] === mode) return;
    
    viewModes[tab] = mode;
    
    // Toggle active state on buttons
    const gridBtn = document.getElementById(`btn-mode-${tab}-grid`);
    const swipeBtn = document.getElementById(`btn-mode-${tab}-swipe`);
    if (gridBtn && swipeBtn) {
        gridBtn.classList.toggle("active", mode === "grid");
        swipeBtn.classList.toggle("active", mode === "swipe");
    }
    
    // Show/hide grid vs swipe containers
    const gridContainer = document.getElementById(`${tab}-grid`);
    const swipeContainer = document.getElementById(`${tab}-swipe-container`);
    
    if (gridContainer && swipeContainer) {
        gridContainer.classList.toggle("hidden", mode !== "grid");
        swipeContainer.classList.toggle("hidden", mode !== "swipe");
    }
    
    // If switching to swipe mode, initialize/render the deck
    if (mode === "swipe") {
        initSwipeDeck(tab);
    }
}

/**
 * Fetch discovery games matching filter settings.
 */
async function getDiscoverGames() {
    const platform = document.getElementById("filter-platform").value;
    const brand = document.getElementById("filter-brand").value.trim();
    const genre = document.getElementById("filter-genre").value;
    const theme = document.getElementById("filter-theme").value;
    
    const loadingContainer = document.getElementById("discover-loading-container");
    const discoverContainer = document.getElementById("discover-container");
    const emptyState = document.getElementById("discover-empty-state");
    
    emptyState.classList.add("hidden");
    discoverContainer.classList.add("hidden");
    loadingContainer.classList.remove("hidden");
    
    try {
        const response = await fetch("/api/discover", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ platform, brand, genre, theme })
        });
        
        const data = await response.json();
        
        if (data.success && data.games && data.games.length > 0) {
            discoverList = data.games;
            
            // Render grid
            renderDiscoverGrid(data.games);
            
            // Set results count
            document.getElementById("discover-results-count").textContent = `${data.games.length} games found`;
            
            // Initialize swipe deck in background in case they switch
            initSwipeDeck("discover");
            
            discoverContainer.classList.remove("hidden");
        } else {
            emptyState.classList.remove("hidden");
            alert(data.error || "No games matching your specifications could be discovered. Try relaxing your filters.");
        }
    } catch (error) {
        console.error("Error discovering games:", error);
        emptyState.classList.remove("hidden");
        alert("Network error while discovering games.");
    } finally {
        loadingContainer.classList.add("hidden");
    }
}

/**
 * Fetch AI Recommendations.
 */
async function getRecommendations() {
    const inputEl = document.getElementById("query-input");
    const query = inputEl.value.trim();
    if (!query) {
        return;
    }
    
    const loadingContainer = document.getElementById("loading-container");
    const resultsContainer = document.getElementById("recommendations-container");
    const emptyState = document.getElementById("empty-state");
    
    emptyState.classList.add("hidden");
    resultsContainer.classList.add("hidden");
    loadingContainer.classList.remove("hidden");
    
    try {
        const response = await fetch("/api/recommend", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ query })
        });
        
        const data = await response.json();
        
        if (data.success && data.recommendations && data.recommendations.length > 0) {
            recommendationList = data.recommendations;
            
            // Render grid
            renderRecommendationsGrid(data.recommendations);
            
            // Set results count
            document.getElementById("results-count").textContent = `${data.recommendations.length} games suggested`;
            
            // Initialize swipe deck
            initSwipeDeck("recommendations");
            
            resultsContainer.classList.remove("hidden");
        } else {
            emptyState.classList.remove("hidden");
            alert(data.error || "No recommendations could be generated matching your search description.");
        }
    } catch (error) {
        console.error("Error recommending games:", error);
        emptyState.classList.remove("hidden");
        alert("Network error while generating recommendations.");
    } finally {
        loadingContainer.classList.add("hidden");
    }
}

/**
 * Renders Grid View for AI Recommendations.
 */
function renderRecommendationsGrid(recommendations) {
    const grid = document.getElementById("recommendations-grid");
    grid.innerHTML = "";
    
    recommendations.forEach(game => {
        const card = createGameCardElement(game, "grid");
        grid.appendChild(card);
    });
}

/**
 * Renders Grid View for Discover page.
 */
function renderDiscoverGrid(games) {
    const grid = document.getElementById("discover-grid");
    grid.innerHTML = "";
    
    games.forEach(game => {
        const card = createGameCardElement(game, "grid");
        grid.appendChild(card);
    });
}

/**
 * HTML Card Creator Helper.
 */
function createGameCardElement(game, context = "grid") {
    const card = document.createElement("div");
    card.className = "game-card";
    
    // Image wrapper
    const imgWrapper = document.createElement("div");
    imgWrapper.className = "card-image-wrapper";
    
    if (game.cover_url) {
        const img = document.createElement("img");
        img.src = game.cover_url;
        img.alt = `${game.name} cover`;
        imgWrapper.appendChild(img);
    } else {
        const fallback = document.createElement("div");
        fallback.className = "card-image-fallback";
        fallback.innerHTML = `<i class="fa-solid fa-gamepad"></i>`;
        imgWrapper.appendChild(fallback);
    }
    
    // Compatibility Rating Badge
    const rating = game.compatibility_rating ? game.compatibility_rating.toUpperCase() : "PLAYABLE";
    const badge = document.createElement("div");
    badge.className = `compatibility-badge ${rating.toLowerCase()}`;
    
    let icon = "fa-circle-question";
    if (rating === "EXCELLENT") icon = "fa-circle-check";
    else if (rating === "PLAYABLE") icon = "fa-triangle-exclamation";
    else if (rating === "UNPLAYABLE") icon = "fa-circle-xmark";
    
    badge.innerHTML = `<i class="fa-solid ${icon}"></i> ${rating}`;
    imgWrapper.appendChild(badge);
    
    // Play trailer button
    if (game.video_id) {
        const playBtn = document.createElement("button");
        playBtn.className = "play-trailer-btn";
        playBtn.innerHTML = `<i class="fa-solid fa-play"></i> Watch Trailer`;
        playBtn.onclick = (e) => {
            e.stopPropagation();
            playTrailer(game.video_id);
        };
        imgWrapper.appendChild(playBtn);
    }
    
    card.appendChild(imgWrapper);
    
    // Card Content
    const content = document.createElement("div");
    content.className = "card-content";
    
    const titleRow = document.createElement("div");
    titleRow.className = "card-title-row";
    titleRow.innerHTML = `<h3>${game.name}</h3>`;
    content.appendChild(titleRow);
    
    const desc = document.createElement("p");
    desc.className = "card-description";
    desc.textContent = game.why_love || "";
    content.appendChild(desc);
    
    // Add external Steam link for details redirect
    const steamUrl = `https://store.steampowered.com/search/?term=${encodeURIComponent(game.name)}`;
    const steamLink = document.createElement("a");
    steamLink.href = steamUrl;
    steamLink.target = "_blank";
    steamLink.className = "steam-link-details";
    steamLink.innerHTML = `<i class="fa-brands fa-steam"></i> View on Steam <i class="fa-solid fa-arrow-up-right-from-square font-small"></i>`;
    steamLink.onclick = (e) => e.stopPropagation();
    content.appendChild(steamLink);
    
    if (game.best_for) {
        const tag = document.createElement("span");
        tag.className = "card-tag";
        tag.textContent = game.best_for;
        content.appendChild(tag);
    }
    
    if (game.compatibility_reason) {
        const reason = document.createElement("div");
        reason.className = `card-compatibility-reason ${rating.toLowerCase()}`;
        
        let reasonIcon = "fa-circle-info";
        if (rating === "EXCELLENT") reasonIcon = "fa-circle-check";
        else if (rating === "PLAYABLE") reasonIcon = "fa-triangle-exclamation";
        else if (rating === "UNPLAYABLE") reasonIcon = "fa-circle-xmark";
        
        reason.innerHTML = `<i class="fa-solid ${reasonIcon}"></i> <span>${game.compatibility_reason}</span>`;
        content.appendChild(reason);
    }
    
    card.appendChild(content);
    
    // Rating footer (only for Grid view, Swipe deck has floating actions underneath)
    if (context === "grid") {
        const footer = document.createElement("div");
        footer.className = "card-actions-footer";
        const safeName = game.name.replace(/'/g, "\\'");
        footer.innerHTML = `
            <span class="rating-question">Rate this pick:</span>
            <div class="rating-buttons">
                <button class="rate-btn like" onclick="rateGame('${safeName}', 'yes', this)" title="Add to Liked & Taste Profile">
                    <i class="fa-solid fa-thumbs-up"></i>
                </button>
                <button class="rate-btn dislike" onclick="rateGame('${safeName}', 'no', this)" title="Add to Disliked">
                    <i class="fa-solid fa-thumbs-down"></i>
                </button>
            </div>
        `;
        card.appendChild(footer);
    }
    
    return card;
}

/**
 * Initializes/clones the active deck copy.
 */
function initSwipeDeck(tab) {
    const list = tab === "recommendations" ? recommendationList : discoverList;
    
    // Deep clone lists
    swipeDecks[tab] = [...list];
    renderSwipeDeck(tab);
}

/**
 * Renders stacked card layout inside swipe deck container.
 */
function renderSwipeDeck(tab) {
    const deck = document.getElementById(`${tab}-swipe-deck`);
    if (!deck) return;
    
    deck.innerHTML = "";
    const list = swipeDecks[tab];
    
    if (!list || list.length === 0) {
        deck.innerHTML = `
            <div class="empty-state" style="padding: 40px 0;">
                <i class="fa-solid fa-circle-nodes" style="font-size: 48px; color: var(--primary-color);"></i>
                <h3 style="margin-top: 15px;">No games loaded</h3>
                <p class="dim">Run a search or apply filters to build the deck.</p>
            </div>
        `;
        return;
    }
    
    // Render in reverse order so first item in list is appended last (ends up on top of stacking context)
    for (let i = list.length - 1; i >= 0; i--) {
        const game = list[i];
        const card = createGameCardElement(game, "swipe");
        card.dataset.name = game.name;
        card.dataset.index = i;
        
        // Add swipe feedback overlays
        const badgeLike = document.createElement("div");
        badgeLike.className = "swipe-badge like";
        badgeLike.textContent = "LIKE";
        card.appendChild(badgeLike);
        
        const badgeNope = document.createElement("div");
        badgeNope.className = "swipe-badge nope";
        badgeNope.textContent = "NOPE";
        card.appendChild(badgeNope);
        
        const badgeSkip = document.createElement("div");
        badgeSkip.className = "swipe-badge skip";
        badgeSkip.textContent = "SKIP";
        card.appendChild(badgeSkip);
        
        // Bind pointer event listeners if it will be the top card
        if (i === 0) {
            bindSwipeEvents(card, tab);
        }
        
        deck.appendChild(card);
    }
    updateAccessibilityStates(tab);
}

/**
 * Bind pointer gesture drag and drop swipe controllers.
 */
function bindSwipeEvents(cardEl, tab) {
    let startX = 0;
    let startY = 0;
    let currentX = 0;
    let currentY = 0;
    let isDragging = false;
    
    const badgeLike = cardEl.querySelector(".swipe-badge.like");
    const badgeNope = cardEl.querySelector(".swipe-badge.nope");
    const badgeSkip = cardEl.querySelector(".swipe-badge.skip");
    
    cardEl.addEventListener("pointerdown", (e) => {
        if (e.button !== 0) return; // Only allow left-click/primary touch
        try {
            cardEl.setPointerCapture(e.pointerId);
        } catch (err) {
            console.warn("setPointerCapture failed:", err);
        }
        isDragging = true;
        startX = e.clientX;
        startY = e.clientY;
        cardEl.classList.add("dragging");
    });
    
    cardEl.addEventListener("pointermove", (e) => {
        if (!isDragging) return;
        currentX = e.clientX - startX;
        currentY = e.clientY - startY;
        
        // Apply transform translation & rotation based on offset
        const rotate = currentX * 0.08;
        cardEl.style.transform = `translate(${currentX}px, ${currentY}px) rotate(${rotate}deg)`;
        
        // Toggle badging states
        if (currentX > 50) {
            badgeLike.style.opacity = Math.min((currentX - 50) / 100, 1);
            badgeNope.style.opacity = 0;
            badgeSkip.style.opacity = 0;
        } else if (currentX < -50) {
            badgeNope.style.opacity = Math.min((-currentX - 50) / 100, 1);
            badgeLike.style.opacity = 0;
            badgeSkip.style.opacity = 0;
        } else if (currentY < -50) {
            badgeSkip.style.opacity = Math.min((-currentY - 50) / 100, 1);
            badgeLike.style.opacity = 0;
            badgeNope.style.opacity = 0;
        } else {
            badgeLike.style.opacity = 0;
            badgeNope.style.opacity = 0;
            badgeSkip.style.opacity = 0;
        }
    });
    
    cardEl.addEventListener("pointerup", (e) => {
        if (!isDragging) return;
        isDragging = false;
        try {
            cardEl.releasePointerCapture(e.pointerId);
        } catch (err) {
            console.warn("releasePointerCapture failed:", err);
        }
        cardEl.classList.remove("dragging");
        
        // Hide badges
        badgeLike.style.opacity = 0;
        badgeNope.style.opacity = 0;
        badgeSkip.style.opacity = 0;
        
        const threshold = 120;
        if (currentX > threshold) {
            animateSwipeOut(cardEl, "right", tab);
        } else if (currentX < -threshold) {
            animateSwipeOut(cardEl, "left", tab);
        } else if (currentY < -threshold) {
            animateSwipeOut(cardEl, "up", tab);
        } else {
            // Reset to stack center
            cardEl.style.transform = "";
        }
    });
    
    cardEl.addEventListener("pointercancel", () => {
        if (!isDragging) return;
        isDragging = false;
        cardEl.classList.remove("dragging");
        badgeLike.style.opacity = 0;
        badgeNope.style.opacity = 0;
        badgeSkip.style.opacity = 0;
        cardEl.style.transform = "";
    });
}

/**
 * Animates swiping card off-screen and updates backend feedback model.
 */
function animateSwipeOut(cardEl, direction, tab) {
    const gameName = cardEl.dataset.name;
    
    if (direction === "right") {
        cardEl.classList.add("swipe-right");
        rateGame(gameName, "yes");
    } else if (direction === "left") {
        cardEl.classList.add("swipe-left");
        rateGame(gameName, "no");
    } else if (direction === "up") {
        cardEl.classList.add("swipe-up");
        rateGame(gameName, "skip");
    }
    
    setTimeout(() => {
        cardEl.remove();
        
        // Pop game from the deck array
        if (swipeDecks[tab].length > 0) {
            swipeDecks[tab].shift();
        }
        
        // Setup pointer handlers on the new top card in deck
        updateTopCardBindings(tab);
    }, 350);
}

/**
 * Triggers programmatic buttons swipe triggers (LIKE, DISLIKE, SKIP).
 */
function triggerSwipe(tab, direction) {
    const deck = document.getElementById(`${tab}-swipe-deck`);
    const cards = deck.querySelectorAll(".game-card");
    if (cards.length === 0) return;
    
    // Top card is the last child element
    const topCard = cards[cards.length - 1];
    animateSwipeOut(topCard, direction, tab);
}

/**
 * Triggers Steam Details redirect from bottom swipe action buttons.
 */
function triggerSwipeDetails(tab) {
    const list = swipeDecks[tab];
    if (!list || list.length === 0) return;
    
    const topGame = list[0];
    const steamUrl = `https://store.steampowered.com/search/?term=${encodeURIComponent(topGame.name)}`;
    window.open(steamUrl, "_blank");
}

/**
 * Refreshes listeners for top stack card.
 */
function updateTopCardBindings(tab) {
    const deck = document.getElementById(`${tab}-swipe-deck`);
    const cards = deck.querySelectorAll(".game-card");
    
    if (cards.length === 0) {
        deck.innerHTML = `
            <div class="empty-state" style="padding: 40px 0;">
                <i class="fa-solid fa-square-check" style="font-size: 48px; color: var(--primary-color);"></i>
                <h3 style="margin-top: 15px;">All cards cleared!</h3>
                <p class="dim">Run a new search or adjust filters to browse more games.</p>
            </div>
        `;
        return;
    }
    
    // The top card is now the last child in the deck DOM
    const nextTopCard = cards[cards.length - 1];
    bindSwipeEvents(nextTopCard, tab);
    updateAccessibilityStates(tab);
}

/**
 * Hides background cards in the deck from screen readers and tab focus.
 */
function updateAccessibilityStates(tab) {
    const deck = document.getElementById(`${tab}-swipe-deck`);
    if (!deck) return;
    const cards = deck.querySelectorAll(".game-card");
    
    cards.forEach((card, idx) => {
        const isTopCard = (idx === cards.length - 1);
        card.setAttribute("aria-hidden", isTopCard ? "false" : "true");
        
        const focusables = card.querySelectorAll("button, a, input, [tabindex]");
        focusables.forEach(el => {
            if (isTopCard) {
                el.removeAttribute("tabindex");
            } else {
                el.setAttribute("tabindex", "-1");
            }
        });
    });
}

/**
 * Global keyboard arrows gesture handler.
 */
function initKeyboardGlobal() {
    document.addEventListener("keydown", (e) => {
        if (viewModes[activeTab] !== "swipe") return;
        
        const deck = document.getElementById(`${activeTab}-swipe-deck`);
        if (!deck) return;
        
        const cards = deck.querySelectorAll(".game-card");
        if (cards.length === 0) return;
        
        const topCard = cards[cards.length - 1];
        
        if (e.key === "ArrowLeft") {
            e.preventDefault();
            animateSwipeOut(topCard, "left", activeTab);
        } else if (e.key === "ArrowRight") {
            e.preventDefault();
            animateSwipeOut(topCard, "right", activeTab);
        } else if (e.key === "ArrowUp") {
            e.preventDefault();
            animateSwipeOut(topCard, "up", activeTab);
        }
    });
}

/**
 * Auto-detect system specs from host machine.
 */
async function autoDetectHardware() {
    const detectBtn = document.querySelector(".auto-detect-section button");
    const originalText = detectBtn.innerHTML;
    
    try {
        detectBtn.disabled = true;
        detectBtn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> Detecting Hardware...`;
        
        const response = await fetch("/api/profile/detect_specs");
        if (!response.ok) {
            throw new Error("Failed to detect hardware specs");
        }
        const specs = await response.json();
        
        document.getElementById("input-cpu").value = specs.cpu || "";
        document.getElementById("input-gpu").value = specs.gpu || "";
        document.getElementById("input-ram").value = specs.ram || "";
        document.getElementById("input-storage").value = specs.storage || "";
        document.getElementById("input-desc").value = specs.description || "budget PC";
        
        detectBtn.innerHTML = `<i class="fa-solid fa-check"></i> Specs Detected!`;
        setTimeout(() => {
            detectBtn.disabled = false;
            detectBtn.innerHTML = originalText;
        }, 2000);
    } catch (error) {
        console.error("Error detecting specs:", error);
        detectBtn.innerHTML = `<i class="fa-solid fa-triangle-exclamation"></i> Detection Failed`;
        setTimeout(() => {
            detectBtn.disabled = false;
            detectBtn.innerHTML = originalText;
        }, 2000);
    }
}

/**
 * Save specifications to backend.
 */
async function saveHardwareSpecs() {
    const cpu = document.getElementById("input-cpu").value.trim();
    const gpu = document.getElementById("input-gpu").value.trim();
    const ram = document.getElementById("input-ram").value.trim();
    const storage = document.getElementById("input-storage").value.trim();
    const description = document.getElementById("input-desc").value.trim();
    
    try {
        const response = await fetch("/api/profile/specs", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ cpu, gpu, ram, storage, description })
        });
        
        if (response.ok) {
            closeSpecsModal();
            loadProfile();
        } else {
            const data = await response.json();
            alert("Error saving specs: " + (data.error || "Unknown error"));
        }
    } catch (error) {
        console.error("Error saving specs:", error);
        alert("Network error saving specifications");
    }
}

/**
 * Save credentials from wizard.
 */
async function saveWizardCredentials() {
    const groq_key = document.getElementById("wizard-groq-key").value.trim();
    const twitch_id = document.getElementById("wizard-twitch-id").value.trim();
    const twitch_secret = document.getElementById("wizard-twitch-secret").value.trim();
    
    if (!groq_key || !twitch_id || !twitch_secret) {
        alert("All credential fields are required.");
        return;
    }
    
    await submitCredentials({ groq_key, twitch_id, twitch_secret });
}

/**
 * Save credentials from settings modal.
 */
async function saveApiCredentials() {
    const groq_key = document.getElementById("input-groq-key").value.trim();
    const twitch_id = document.getElementById("input-twitch-id").value.trim();
    const twitch_secret = document.getElementById("input-twitch-secret").value.trim();
    
    if (!groq_key || !twitch_id || !twitch_secret) {
        alert("All credential fields are required.");
        return;
    }
    
    await submitCredentials({ groq_key, twitch_id, twitch_secret });
    closeSettingsModal();
}

/**
 * Submits credential details helper.
 */
async function submitCredentials(credentials) {
    try {
        const response = await fetch("/api/setup", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify(credentials)
        });
        
        const data = await response.json();
        if (data.success) {
            checkStatus();
        } else {
            alert("Error initializing: " + (data.error || "Unknown error"));
        }
    } catch (error) {
        console.error("Error submitting credentials:", error);
        alert("Network error initializing application");
    }
}

/**
 * Batch import liked games.
 */
async function saveBatchLikedGames() {
    const raw_names = document.getElementById("input-import-names").value.trim();
    if (!raw_names) {
        alert("Please enter at least one game name.");
        return;
    }
    
    const loadingEl = document.getElementById("import-loading");
    const saveBtn = document.getElementById("import-save-btn");
    
    loadingEl.classList.remove("hidden");
    saveBtn.disabled = true;
    
    try {
        const response = await fetch("/api/import_liked", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ raw_names })
        });
        
        const data = await response.json();
        if (data.success) {
            document.getElementById("input-import-names").value = "";
            closeImportModal();
            loadProfile();
            
            // Notify user of corrected games
            if (data.imported_list && data.imported_list.length > 0) {
                alert(`Successfully imported ${data.imported_count} games:\n- ${data.imported_list.join("\n- ")}`);
            }
        } else {
            alert("Error importing favorites: " + (data.error || "Unknown error"));
        }
    } catch (error) {
        console.error("Error importing favorites:", error);
        alert("Network error during import process");
    } finally {
        loadingEl.classList.add("hidden");
        saveBtn.disabled = false;
    }
}

/**
 * Handle game rating thumbs up/down actions.
 */
async function rateGame(gameName, feedback, btnEl = null) {
    if (btnEl) {
        const parent = btnEl.parentElement;
        const buttons = parent.querySelectorAll(".rate-btn");
        buttons.forEach(btn => btn.classList.remove("active"));
        btnEl.classList.add("active");
    }
    
    try {
        const response = await fetch("/api/rate", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ game_name: gameName, feedback: feedback })
        });
        
        const data = await response.json();
        if (data.success) {
            activeProfile = data.profile;
            document.getElementById("liked-count").textContent = activeProfile.liked ? activeProfile.liked.length : 0;
            document.getElementById("disliked-count").textContent = activeProfile.disliked ? activeProfile.disliked.length : 0;
            
            if (activeProfile.notes && activeProfile.notes.trim()) {
                document.getElementById("profile-notes").textContent = activeProfile.notes;
            }
        } else {
            console.error("Error rating game:", data.error);
        }
    } catch (error) {
        console.error("Error rating game:", error);
    }
}

/**
 * Open YouTube trailer modal and autoplay.
 */
function playTrailer(videoId) {
    const modal = document.getElementById("video-modal");
    const player = document.getElementById("youtube-player");
    
    player.src = `https://www.youtube.com/embed/${videoId}?autoplay=1`;
    modal.classList.remove("hidden");
}

/**
 * Close YouTube trailer modal and clear iframe.
 */
function closeVideoModal() {
    const modal = document.getElementById("video-modal");
    const player = document.getElementById("youtube-player");
    
    player.src = "";
    modal.classList.add("hidden");
}

/**
 * Quick Suggestion Chip Click Action.
 */
function applySuggestion(text) {
    const inputEl = document.getElementById("query-input");
    inputEl.value = text;
    getRecommendations();
}

// Modal Toggle Helpers
function openSpecsModal() {
    document.getElementById("specs-modal").classList.remove("hidden");
}

function closeSpecsModal() {
    document.getElementById("specs-modal").classList.add("hidden");
}

document.getElementById("specs-modal").addEventListener("click", (e) => {
    if (e.target.id === "specs-modal") {
        closeSpecsModal();
    }
});

function openImportModal() {
    document.getElementById("import-modal").classList.remove("hidden");
}

function closeImportModal() {
    document.getElementById("import-modal").classList.add("hidden");
}

document.getElementById("import-modal").addEventListener("click", (e) => {
    if (e.target.id === "import-modal") {
        closeImportModal();
    }
});

function openSettingsModal() {
    document.getElementById("settings-modal").classList.remove("hidden");
}

function closeSettingsModal() {
    document.getElementById("settings-modal").classList.add("hidden");
}

document.getElementById("settings-modal").addEventListener("click", (e) => {
    if (e.target.id === "settings-modal") {
        closeSettingsModal();
    }
});

// Map window actions for template bindings
window.openSpecsModal = openSpecsModal;
window.closeSpecsModal = closeSpecsModal;
window.autoDetectHardware = autoDetectHardware;
window.saveHardwareSpecs = saveHardwareSpecs;
window.openImportModal = openImportModal;
window.closeImportModal = closeImportModal;
window.saveBatchLikedGames = saveBatchLikedGames;
window.openSettingsModal = openSettingsModal;
window.closeSettingsModal = closeSettingsModal;
window.saveApiCredentials = saveApiCredentials;
window.saveWizardCredentials = saveWizardCredentials;
window.getRecommendations = getRecommendations;
window.applySuggestion = applySuggestion;
window.closeVideoModal = closeVideoModal;
window.rateGame = rateGame;
window.playTrailer = playTrailer;
window.switchTab = switchTab;
window.setViewMode = setViewMode;
window.getDiscoverGames = getDiscoverGames;
window.triggerSwipe = triggerSwipe;
window.triggerSwipeDetails = triggerSwipeDetails;
