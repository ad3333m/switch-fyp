(() => {
  "use strict";

  const feedEl = document.getElementById("feed");
  const template = document.getElementById("post-template");

  const commentSheet = document.getElementById("commentSheet");
  const shareSheet = document.getElementById("shareSheet");
  const backdrop = document.getElementById("sheetBackdrop");
  const commentList = document.getElementById("commentList");
  const commentSheetCount = document.getElementById("commentSheetCount");
  const commentForm = document.getElementById("commentForm");
  const commentInput = document.getElementById("commentInput");
  const toastEl = document.getElementById("toast");

  const STORAGE_KEY = "foryou_state_v1";

  /** @type {{liked: string[], favourited: string[], reposted: string[], followed: string[], extraComments: Record<string, {user:string, text:string}[]>}} */
  let state = { liked: [], favourited: [], reposted: [], followed: [], extraComments: {} };

  let posts = [];
  let activePostId = null;

  // ---------- Compressed persistence (gzip via CompressionStream, base64) ----------

  async function loadState() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      if (typeof DecompressionStream !== "undefined") {
        const bytes = Uint8Array.from(atob(raw), c => c.charCodeAt(0));
        const ds = new DecompressionStream("gzip");
        const stream = new Blob([bytes]).stream().pipeThrough(ds);
        const text = await new Response(stream).text();
        state = { ...state, ...JSON.parse(text) };
      } else {
        state = { ...state, ...JSON.parse(raw) };
      }
    } catch (e) {
      console.warn("Failed to load saved state", e);
    }
  }

  let saveTimer = null;
  function saveStateDebounced() {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveStateNow, 250);
  }

  async function saveStateNow() {
    const json = JSON.stringify(state);
    try {
      if (typeof CompressionStream !== "undefined") {
        const cs = new CompressionStream("gzip");
        const stream = new Blob([json]).stream().pipeThrough(cs);
        const buf = await new Response(stream).arrayBuffer();
        let binary = "";
        const bytes = new Uint8Array(buf);
        for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
        localStorage.setItem(STORAGE_KEY, btoa(binary));
      } else {
        localStorage.setItem(STORAGE_KEY, json);
      }
    } catch (e) {
      console.warn("Failed to save state", e);
    }
  }

  // ---------- Helpers ----------

  function formatCount(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
    if (n >= 1000) return (n / 1000).toFixed(1).replace(/\.0$/, "") + "K";
    return String(n);
  }

  function initials(name) {
    return name.replace(/[^a-zA-Z0-9]/g, " ").trim().split(/\s+/).slice(0, 2)
      .map(s => s[0]?.toUpperCase() || "").join("") || "?";
  }

  function showToast(msg) {
    toastEl.textContent = msg;
    toastEl.classList.add("visible");
    clearTimeout(showToast._t);
    showToast._t = setTimeout(() => toastEl.classList.remove("visible"), 1600);
  }

  function openSheet(sheetEl) {
    backdrop.classList.add("visible");
    sheetEl.classList.add("open");
  }

  function closeSheets() {
    backdrop.classList.remove("visible");
    commentSheet.classList.remove("open");
    shareSheet.classList.remove("open");
  }

  backdrop.addEventListener("click", closeSheets);
  document.getElementById("commentSheetClose").addEventListener("click", closeSheets);
  document.getElementById("shareSheetClose").addEventListener("click", closeSheets);

  // ---------- Rendering ----------

  function renderPost(post) {
    const node = template.content.firstElementChild.cloneNode(true);
    node.dataset.id = post.id;

    const video = node.querySelector(".post__video");
    video.src = post.video;

    node.querySelector("[data-username]").textContent = post.user;
    node.querySelector("[data-caption]").textContent = post.caption;
    node.querySelector("[data-sound]").textContent = post.sound;

    const avatar = node.querySelector("[data-avatar]");
    avatar.textContent = initials(post.user);
    avatar.style.background = post.avatarColor;

    const liked = state.liked.includes(post.id);
    const favourited = state.favourited.includes(post.id);
    const reposted = state.reposted.includes(post.id);
    const followed = state.followed.includes(post.id);

    const likeBtn = node.querySelector('[data-action="like"]');
    const favBtn = node.querySelector('[data-action="favourite"]');
    likeBtn.classList.toggle("active", liked);
    favBtn.classList.toggle("active", favourited);

    const extra = (state.extraComments[post.id] || []).length;
    node.querySelector("[data-like-count]").textContent = formatCount(post.likes + (liked ? 1 : 0));
    node.querySelector("[data-comment-count]").textContent = formatCount(post.comments + extra);
    node.querySelector("[data-favourite-count]").textContent = formatCount(post.favourites + (favourited ? 1 : 0));
    node.querySelector("[data-share-count]").textContent = formatCount(post.shares + (reposted ? 1 : 0));

    node.querySelector("[data-follow]").classList.toggle("followed", followed);

    // action buttons
    node.querySelectorAll(".rail__action").forEach(btn => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        handleAction(post, btn.dataset.action, node);
      });
    });

    node.querySelector("[data-follow]").addEventListener("click", (e) => {
      e.stopPropagation();
      toggleFollow(post, node);
    });

    // tap zone: single tap toggles play/pause, double tap likes
    const tapzone = node.querySelector("[data-tapzone]");
    let tapTimer = null;
    tapzone.addEventListener("click", () => {
      if (tapTimer) {
        clearTimeout(tapTimer);
        tapTimer = null;
        doubleTapLike(post, node);
      } else {
        tapTimer = setTimeout(() => {
          tapTimer = null;
          togglePlay(video);
        }, 220);
      }
    });

    // progress bar
    video.addEventListener("timeupdate", () => {
      if (!video.duration) return;
      const pct = (video.currentTime / video.duration) * 100;
      node.querySelector("[data-progress]").style.width = pct + "%";
    });

    return node;
  }

  function togglePlay(video) {
    if (video.paused) video.play().catch(() => {});
    else video.pause();
  }

  function doubleTapLike(post, node) {
    if (!state.liked.includes(post.id)) {
      setLiked(post, node, true);
    }
    const burst = node.querySelector("[data-heartburst]");
    burst.classList.remove("burst");
    void burst.offsetWidth; // restart animation
    burst.classList.add("burst");
  }

  function setLiked(post, node, liked) {
    const idx = state.liked.indexOf(post.id);
    if (liked && idx === -1) state.liked.push(post.id);
    if (!liked && idx !== -1) state.liked.splice(idx, 1);
    node.querySelector('[data-action="like"]').classList.toggle("active", liked);
    node.querySelector("[data-like-count]").textContent = formatCount(post.likes + (liked ? 1 : 0));
    saveStateDebounced();
  }

  function handleAction(post, action, node) {
    if (action === "like") {
      const liked = !state.liked.includes(post.id);
      setLiked(post, node, liked);
    } else if (action === "favourite") {
      const favourited = !state.favourited.includes(post.id);
      const idx = state.favourited.indexOf(post.id);
      if (favourited && idx === -1) state.favourited.push(post.id);
      if (!favourited && idx !== -1) state.favourited.splice(idx, 1);
      node.querySelector('[data-action="favourite"]').classList.toggle("active", favourited);
      node.querySelector("[data-favourite-count]").textContent = formatCount(post.favourites + (favourited ? 1 : 0));
      showToast(favourited ? "Added to Favourites" : "Removed from Favourites");
      saveStateDebounced();
    } else if (action === "comment") {
      openComments(post);
    } else if (action === "share") {
      openShare(post, node);
    }
  }

  function toggleFollow(post, node) {
    const followed = !state.followed.includes(post.id);
    const idx = state.followed.indexOf(post.id);
    if (followed && idx === -1) state.followed.push(post.id);
    if (!followed && idx !== -1) state.followed.splice(idx, 1);
    node.querySelector("[data-follow]").classList.toggle("followed", followed);
    showToast(followed ? `Following @${post.user}` : `Unfollowed @${post.user}`);
    saveStateDebounced();
  }

  // ---------- Comments sheet ----------

  let activeCommentPost = null;

  function openComments(post) {
    activeCommentPost = post;
    const extra = state.extraComments[post.id] || [];
    const all = [...post.commentList, ...extra];
    commentSheetCount.textContent = `${formatCount(post.comments + extra.length)} comments`;
    commentList.innerHTML = "";
    all.forEach(c => {
      const row = document.createElement("div");
      row.className = "comment-row";
      row.innerHTML = `
        <div class="comment-row__avatar">${initials(c.user)}</div>
        <div class="comment-row__body">
          <div class="comment-row__user">@${c.user}</div>
          <div class="comment-row__text"></div>
        </div>
        <div class="comment-row__heart">&#9825;<span>${Math.floor(Math.random() * 40)}</span></div>
      `;
      row.querySelector(".comment-row__text").textContent = c.text;
      commentList.appendChild(row);
    });
    openSheet(commentSheet);
  }

  commentForm.addEventListener("submit", (e) => {
    e.preventDefault();
    const text = commentInput.value.trim();
    if (!text || !activeCommentPost) return;
    const post = activeCommentPost;
    if (!state.extraComments[post.id]) state.extraComments[post.id] = [];
    state.extraComments[post.id].push({ user: "me", text });
    commentInput.value = "";
    saveStateDebounced();
    openComments(post);

    const node = feedEl.querySelector(`.post[data-id="${post.id}"]`);
    if (node) {
      const extra = state.extraComments[post.id].length;
      node.querySelector("[data-comment-count]").textContent = formatCount(post.comments + extra);
    }
  });

  // ---------- Share sheet ----------

  let activeSharePost = null;
  let activeShareNode = null;

  function openShare(post, node) {
    activeSharePost = post;
    activeShareNode = node;
    const reposted = state.reposted.includes(post.id);
    document.getElementById("repostOption").classList.toggle("active", reposted);
    document.querySelector("[data-repost-label]").textContent = reposted ? "Reposted" : "Repost";
    openSheet(shareSheet);
  }

  document.getElementById("repostOption").addEventListener("click", () => {
    if (!activeSharePost) return;
    const post = activeSharePost;
    const node = activeShareNode;
    const reposted = !state.reposted.includes(post.id);
    const idx = state.reposted.indexOf(post.id);
    if (reposted && idx === -1) state.reposted.push(post.id);
    if (!reposted && idx !== -1) state.reposted.splice(idx, 1);
    document.getElementById("repostOption").classList.toggle("active", reposted);
    document.querySelector("[data-repost-label]").textContent = reposted ? "Reposted" : "Repost";
    if (node) node.querySelector("[data-share-count]").textContent = formatCount(post.shares + (reposted ? 1 : 0));
    showToast(reposted ? "Reposted to your profile" : "Repost removed");
    saveStateDebounced();
  });

  document.getElementById("copyLinkOption").addEventListener("click", async () => {
    if (!activeSharePost) return;
    const fakeUrl = `${location.origin}${location.pathname}#${activeSharePost.id}`;
    try {
      await navigator.clipboard.writeText(fakeUrl);
    } catch (e) { /* clipboard may be unavailable in the web applet */ }
    showToast("Link copied");
    closeSheets();
  });

  document.getElementById("duetOption").addEventListener("click", () => {
    showToast("Duet is not available on this device");
    closeSheets();
  });

  // ---------- Playback: play the post in view, pause everything else ----------

  let observer = null;

  function setupObserver() {
    observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        const video = entry.target.querySelector(".post__video");
        if (!video) return;
        if (entry.isIntersecting && entry.intersectionRatio > 0.6) {
          activePostId = entry.target.dataset.id;
          video.play().catch(() => {});
        } else {
          video.pause();
        }
      });
    }, { threshold: [0, 0.6, 1] });

    feedEl.querySelectorAll(".post").forEach(p => observer.observe(p));
  }

  // ---------- Boot ----------

  async function boot() {
    await loadState();

    let data;
    try {
      const res = await fetch("feed.json", { cache: "no-store" });
      data = await res.json();
    } catch (e) {
      feedEl.innerHTML = `<div style="color:#fff;padding:40px;text-align:center">Couldn't load the feed. Check your connection and reopen the app.</div>`;
      return;
    }

    posts = data;
    const frag = document.createDocumentFragment();
    posts.forEach(post => frag.appendChild(renderPost(post)));
    feedEl.appendChild(frag);

    setupObserver();
  }

  boot();
})();
